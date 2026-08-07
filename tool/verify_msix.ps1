[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string] $PackagePath,

  [Parameter(Mandatory = $true)]
  [ValidateSet('x64', 'arm64')]
  [string] $ExpectedArchitecture
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

$resolvedPackage = [IO.Path]::GetFullPath($PackagePath)
if (-not (Test-Path -LiteralPath $resolvedPackage -PathType Leaf)) {
  throw "MSIX package not found: $resolvedPackage"
}
if ([IO.Path]::GetExtension($resolvedPackage).ToLowerInvariant() -ne '.msix') {
  throw "Expected an .msix file: $resolvedPackage"
}

$archive = [System.IO.Compression.ZipFile]::OpenRead($resolvedPackage)
try {
  $requiredEntries = @('AppxManifest.xml', 'AppxBlockMap.xml', 'resources.pri')
  foreach ($required in $requiredEntries) {
    if (-not ($archive.Entries | Where-Object { $_.FullName -eq $required })) {
      throw "MSIX package is missing $required"
    }
  }
  if (-not ($archive.Entries | Where-Object { $_.FullName -match '\.exe$' })) {
    throw 'MSIX package contains no Windows executable'
  }

  $manifestEntry = $archive.Entries | Where-Object { $_.FullName -eq 'AppxManifest.xml' }
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
  if ($null -eq $identity) {
    throw 'MSIX AppxManifest.xml has no Identity element'
  }
  $actualArchitecture = $identity.GetAttribute('ProcessorArchitecture')
  if ($actualArchitecture -ne $ExpectedArchitecture) {
    throw "MSIX architecture mismatch: expected $ExpectedArchitecture, found $actualArchitecture"
  }
  foreach ($attribute in @('Name', 'Version', 'Publisher')) {
    if ([string]::IsNullOrWhiteSpace($identity.GetAttribute($attribute))) {
      throw "MSIX Identity.$attribute is empty"
    }
  }

  Write-Host "MSIX package verified: architecture=$actualArchitecture, identity=$($identity.GetAttribute('Name')), version=$($identity.GetAttribute('Version'))"
  Write-Host 'The package is intentionally unsigned; production signing is required before distribution or installation.'
}
finally {
  $archive.Dispose()
}
