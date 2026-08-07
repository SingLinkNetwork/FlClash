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

$expectedIdentityName = 'com.singlinknetwork.flclash'
$expectedPublisher = 'CN=SingLinkNetwork'

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
  $executableEntries = @($archive.Entries | Where-Object { $_.FullName -match '\.exe$' })
  if ($executableEntries.Count -eq 0) {
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
  if ($identity.GetAttribute('Name') -ne $expectedIdentityName) {
    throw "MSIX identity mismatch: expected $expectedIdentityName, found $($identity.GetAttribute('Name'))"
  }
  if ($identity.GetAttribute('Publisher') -ne $expectedPublisher) {
    throw "MSIX publisher mismatch: expected $expectedPublisher, found $($identity.GetAttribute('Publisher'))"
  }

  $application = $xml.SelectSingleNode("/*[local-name()='Package']/*[local-name()='Applications']/*[local-name()='Application']")
  $executableName = if ($null -ne $application) { $application.GetAttribute('Executable') } else { '' }
  $executableEntry = if (-not [string]::IsNullOrWhiteSpace($executableName)) {
    $archive.Entries | Where-Object { $_.FullName -ieq $executableName } | Select-Object -First 1
  }
  if ($null -eq $executableEntry) {
    $executableEntry = $executableEntries[0]
  }

  $executableStream = $executableEntry.Open()
  $executableBytes = New-Object System.IO.MemoryStream
  try {
    $executableStream.CopyTo($executableBytes)
    $peBytes = $executableBytes.ToArray()
  }
  finally {
    $executableBytes.Dispose()
    $executableStream.Dispose()
  }

  if ($peBytes.Length -lt 0x40) {
    throw "MSIX executable is too small to contain a PE header: $($executableEntry.FullName)"
  }
  $peOffset = [BitConverter]::ToInt32($peBytes, 0x3c)
  if ($peOffset -lt 0 -or $peOffset + 6 -gt $peBytes.Length) {
    throw "MSIX executable has an invalid PE header offset: $($executableEntry.FullName)"
  }
  $peSignature = [Text.Encoding]::ASCII.GetString($peBytes, $peOffset, 4)
  if ($peSignature -ne "PE`0`0") {
    throw "MSIX executable has no valid PE signature: $($executableEntry.FullName)"
  }
  $machine = [BitConverter]::ToUInt16($peBytes, $peOffset + 4)
  $expectedMachine = if ($ExpectedArchitecture -eq 'x64') { [uint16]0x8664 } else { [uint16]0xaa64 }
  if ($machine -ne $expectedMachine) {
    $actualMachine = ('0x{0:X4}' -f $machine)
    $expectedMachineName = if ($ExpectedArchitecture -eq 'x64') { 'x64' } else { 'ARM64' }
    throw "MSIX executable CPU mismatch: expected $expectedMachineName ($('0x{0:X4}' -f $expectedMachine)), found $actualMachine"
  }

  Write-Host "MSIX package verified: architecture=$actualArchitecture, executable=$($executableEntry.FullName), identity=$($identity.GetAttribute('Name')), version=$($identity.GetAttribute('Version'))"
  Write-Host 'The package is intentionally unsigned; production signing is required before distribution or installation.'
}
finally {
  $archive.Dispose()
}
