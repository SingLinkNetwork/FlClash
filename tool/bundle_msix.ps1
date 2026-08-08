[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string] $X64Package,

  [Parameter(Mandatory = $true)]
  [string] $Arm64Package,

  [Parameter(Mandatory = $true)]
  [string] $OutputPath
)

$ErrorActionPreference = 'Stop'

function Resolve-MakeAppx {
  $pathCommand = Get-Command makeappx.exe -ErrorAction SilentlyContinue
  if ($null -ne $pathCommand) {
    return $pathCommand.Source
  }

  $programFilesX86 = ${env:ProgramFiles(x86)}
  if ([string]::IsNullOrWhiteSpace($programFilesX86)) {
    throw 'Program Files (x86) is not available; cannot locate the Windows SDK.'
  }

  $kitsDirectory = Join-Path $programFilesX86 'Windows Kits\10\bin'
  if (-not (Test-Path -LiteralPath $kitsDirectory -PathType Container)) {
    throw "Windows SDK directory not found: $kitsDirectory"
  }

  $candidate = Get-ChildItem -LiteralPath $kitsDirectory -Filter 'makeappx.exe' -File -Recurse |
    Sort-Object FullName -Descending |
    Select-Object -First 1
  if ($null -eq $candidate) {
    throw "MakeAppx.exe not found below $kitsDirectory"
  }

  return $candidate.FullName
}

function Read-MsixVersion {
  param(
    [Parameter(Mandatory = $true)]
    [string] $PackagePath
  )

  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $archive = [System.IO.Compression.ZipFile]::OpenRead($PackagePath)
  try {
    $manifestEntry = $archive.Entries |
      Where-Object { $_.FullName -eq 'AppxManifest.xml' } |
      Select-Object -First 1
    if ($null -eq $manifestEntry) {
      throw "MSIX package has no AppxManifest.xml: $PackagePath"
    }

    $stream = $manifestEntry.Open()
    $reader = New-Object System.IO.StreamReader($stream)
    try {
      $xml = New-Object System.Xml.XmlDocument
      $xml.LoadXml($reader.ReadToEnd())
    }
    finally {
      $reader.Dispose()
      $stream.Dispose()
    }

    $identity = $xml.SelectSingleNode("/*[local-name()='Package']/*[local-name()='Identity']")
    if ($null -eq $identity -or [string]::IsNullOrWhiteSpace($identity.GetAttribute('Version'))) {
      throw "MSIX package has no valid Identity.Version: $PackagePath"
    }
    return $identity.GetAttribute('Version')
  }
  finally {
    $archive.Dispose()
  }
}

foreach ($package in @($X64Package, $Arm64Package)) {
  if (-not (Test-Path -LiteralPath $package -PathType Leaf)) {
    throw "MSIX package not found: $package"
  }
  if ([IO.Path]::GetExtension($package).ToLowerInvariant() -ne '.msix') {
    throw "Expected an .msix input package: $package"
  }
}

$resolvedOutput = [IO.Path]::GetFullPath($OutputPath)
if ([IO.Path]::GetExtension($resolvedOutput).ToLowerInvariant() -ne '.msixbundle') {
  throw "Output must use the .msixbundle extension: $resolvedOutput"
}

$outputDirectory = Split-Path -Parent $resolvedOutput
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null

$stageDirectory = Join-Path ([IO.Path]::GetTempPath()) "flclash-msixbundle-$([Guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Force -Path $stageDirectory | Out-Null

try {
  $x64Version = Read-MsixVersion -PackagePath $X64Package
  $arm64Version = Read-MsixVersion -PackagePath $Arm64Package
  if ($x64Version -ne $arm64Version) {
    throw "MSIX package versions do not match: x64=$x64Version, arm64=$arm64Version"
  }
  if ($x64Version -notmatch '^\d+\.\d+\.\d+\.\d+$') {
    throw "MSIX package version is not a four-part Windows version: $x64Version"
  }

  Copy-Item -LiteralPath $X64Package -Destination (Join-Path $stageDirectory 'FlClash-x64.msix')
  Copy-Item -LiteralPath $Arm64Package -Destination (Join-Path $stageDirectory 'FlClash-arm64.msix')

  $makeAppx = Resolve-MakeAppx
  & $makeAppx bundle /v /bv $x64Version /d $stageDirectory /p $resolvedOutput
  if ($LASTEXITCODE -ne 0) {
    throw "MakeAppx bundle failed with exit code $LASTEXITCODE"
  }
  if (-not (Test-Path -LiteralPath $resolvedOutput -PathType Leaf)) {
    throw "MakeAppx did not create the bundle: $resolvedOutput"
  }

  Write-Host "Created unsigned MSIXBundle: $resolvedOutput"
}
finally {
  if (Test-Path -LiteralPath $stageDirectory) {
    Remove-Item -LiteralPath $stageDirectory -Recurse -Force
  }
}
