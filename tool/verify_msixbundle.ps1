[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string] $BundlePath
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

$expectedIdentityName = 'com.singlinknetwork.flclash'
$expectedPublisher = 'CN=SingLinkNetwork'

function Read-ZipEntryText {
  param(
    [Parameter(Mandatory = $true)]
    [System.IO.Compression.ZipArchiveEntry] $Entry
  )

  $stream = $Entry.Open()
  $reader = New-Object System.IO.StreamReader($stream)
  try {
    return $reader.ReadToEnd()
  }
  finally {
    $reader.Dispose()
    $stream.Dispose()
  }
}

function Open-NestedZip {
  param(
    [Parameter(Mandatory = $true)]
    [System.IO.Compression.ZipArchiveEntry] $Entry,

    [Parameter(Mandatory = $true)]
    [System.Collections.Generic.List[System.IO.MemoryStream]] $Streams
  )

  $memory = New-Object System.IO.MemoryStream
  $source = $Entry.Open()
  try {
    $source.CopyTo($memory)
  }
  finally {
    $source.Dispose()
  }
  $memory.Position = 0
  $Streams.Add($memory)
  return [System.IO.Compression.ZipArchive]::new(
    $memory,
    [System.IO.Compression.ZipArchiveMode]::Read,
    $false
  )
}

function Read-PackageIdentity {
  param(
    [Parameter(Mandatory = $true)]
    [System.IO.Compression.ZipArchive] $Package,

    [Parameter(Mandatory = $true)]
    [string] $PackageName
  )

  $manifestEntry = $Package.Entries |
    Where-Object { $_.FullName -match '(^|/)AppxManifest\.xml$' } |
    Select-Object -First 1
  if ($null -eq $manifestEntry) {
    throw "Nested package has no AppxManifest.xml: $PackageName"
  }

  $xml = New-Object System.Xml.XmlDocument
  $xml.LoadXml((Read-ZipEntryText $manifestEntry))
  $identity = $xml.SelectSingleNode("/*[local-name()='Package']/*[local-name()='Identity']")
  if ($null -eq $identity) {
    throw "AppxManifest.xml has no Identity element: $PackageName"
  }

  $values = @{
    Name = $identity.GetAttribute('Name')
    Version = $identity.GetAttribute('Version')
    Publisher = $identity.GetAttribute('Publisher')
    ProcessorArchitecture = $identity.GetAttribute('ProcessorArchitecture')
  }
  foreach ($key in $values.Keys) {
    if ([string]::IsNullOrWhiteSpace($values[$key])) {
      throw "AppxManifest Identity.$key is empty: $PackageName"
    }
  }
  return [pscustomobject] $values
}

$resolvedBundle = [IO.Path]::GetFullPath($BundlePath)
if (-not (Test-Path -LiteralPath $resolvedBundle -PathType Leaf)) {
  throw "MSIXBundle not found: $resolvedBundle"
}
if ([IO.Path]::GetExtension($resolvedBundle).ToLowerInvariant() -ne '.msixbundle') {
  throw "Expected an .msixbundle file: $resolvedBundle"
}

$archive = [System.IO.Compression.ZipFile]::OpenRead($resolvedBundle)
$memoryStreams = New-Object 'System.Collections.Generic.List[System.IO.MemoryStream]'
$nestedArchives = New-Object 'System.Collections.Generic.List[System.IO.Compression.ZipArchive]'
try {
  $bundleManifest = $archive.Entries |
    Where-Object { $_.FullName -match '(^|/)AppxBundleManifest\.xml$' } |
    Select-Object -First 1
  if ($null -eq $bundleManifest) {
    throw 'MSIXBundle has no AppxBundleManifest.xml'
  }
  $bundleXml = New-Object System.Xml.XmlDocument
  $bundleXml.LoadXml((Read-ZipEntryText $bundleManifest))
  $bundleIdentity = $bundleXml.SelectSingleNode("/*[local-name()='Bundle']/*[local-name()='Identity']")
  if ($null -eq $bundleIdentity) {
    throw 'AppxBundleManifest.xml has no Identity element'
  }
  foreach ($attribute in @('Name', 'Version', 'Publisher')) {
    if ([string]::IsNullOrWhiteSpace($bundleIdentity.GetAttribute($attribute))) {
      throw "AppxBundle Identity.$attribute is empty"
    }
  }
  if ($bundleIdentity.GetAttribute('Name') -ne $expectedIdentityName) {
    throw "MSIXBundle identity mismatch: expected $expectedIdentityName, found $($bundleIdentity.GetAttribute('Name'))"
  }
  if ($bundleIdentity.GetAttribute('Publisher') -ne $expectedPublisher) {
    throw "MSIXBundle publisher mismatch: expected $expectedPublisher, found $($bundleIdentity.GetAttribute('Publisher'))"
  }

  $packages = @($archive.Entries | Where-Object { $_.FullName -match '\.msix$' })
  if ($packages.Count -ne 2) {
    throw "MSIXBundle must contain exactly two nested .msix packages; found $($packages.Count)"
  }

  $identityByEntry = @{}
  foreach ($packageEntry in $packages) {
    $nested = Open-NestedZip -Entry $packageEntry -Streams $memoryStreams
    $nestedArchives.Add($nested)
    $identityByEntry[$packageEntry.FullName] = Read-PackageIdentity -Package $nested -PackageName $packageEntry.FullName
  }
  $identities = @($identityByEntry.GetEnumerator() | ForEach-Object { $_.Value })

  $architectures = @($identities | ForEach-Object { $_.ProcessorArchitecture })
  if (@($architectures | Where-Object { $_ -eq 'x64' }).Count -ne 1) {
    throw 'MSIXBundle must contain exactly one x64 package'
  }
  if (@($architectures | Where-Object { $_ -eq 'arm64' }).Count -ne 1) {
    throw 'MSIXBundle must contain exactly one arm64 package'
  }

  $reference = $identities[0]
  foreach ($identity in $identities | Select-Object -Skip 1) {
    foreach ($field in @('Name', 'Version', 'Publisher')) {
      if ($identity.$field -ne $reference.$field) {
        throw "MSIX package $field does not match across architectures"
      }
    }
  }
  foreach ($field in @('Name', 'Version', 'Publisher')) {
    if ($reference.$field -ne $bundleIdentity.GetAttribute($field)) {
      throw "MSIXBundle $field does not match its nested packages"
    }
  }

  $bundlePackages = @(
    $bundleXml.SelectNodes("/*[local-name()='Bundle']/*[local-name()='Packages']/*[local-name()='Package']")
  )
  if ($bundlePackages.Count -ne 2) {
    throw "AppxBundleManifest.xml must describe exactly two packages; found $($bundlePackages.Count)"
  }
  $bundleArchitectures = @()
  foreach ($bundlePackage in $bundlePackages) {
    foreach ($attribute in @('Type', 'Version', 'Architecture', 'FileName', 'Offset', 'Size')) {
      if ([string]::IsNullOrWhiteSpace($bundlePackage.GetAttribute($attribute))) {
        throw "AppxBundle Package.$attribute is empty"
      }
    }
    if ($bundlePackage.GetAttribute('Type') -ne 'application') {
      throw "AppxBundle Package.Type must be application, found $($bundlePackage.GetAttribute('Type'))"
    }

    $bundleArchitecture = $bundlePackage.GetAttribute('Architecture')
    $bundleFileName = $bundlePackage.GetAttribute('FileName')
    $nestedEntry = $packages |
      Where-Object { $_.FullName -eq $bundleFileName -or $_.Name -eq $bundleFileName } |
      Select-Object -First 1
    if ($null -eq $nestedEntry) {
      throw "AppxBundle Package.FileName does not reference a nested MSIX: $bundleFileName"
    }
    $nestedIdentity = $identityByEntry[$nestedEntry.FullName]
    if ($bundlePackage.GetAttribute('Version') -ne $nestedIdentity.Version) {
      throw "AppxBundle package version does not match its nested package: $bundleFileName"
    }
    if ($bundleArchitecture -ne $nestedIdentity.ProcessorArchitecture) {
      throw "AppxBundle package architecture does not match its nested package: $bundleFileName"
    }
    $bundleArchitectures += $bundleArchitecture
  }
  if (@($bundleArchitectures | Where-Object { $_ -eq 'x64' }).Count -ne 1) {
    throw 'AppxBundleManifest.xml must describe exactly one x64 package'
  }
  if (@($bundleArchitectures | Where-Object { $_ -eq 'arm64' }).Count -ne 1) {
    throw 'AppxBundleManifest.xml must describe exactly one arm64 package'
  }

  Write-Host "MSIXBundle structure verified: x64 + arm64, identity=$($reference.Name), version=$($reference.Version)"
  Write-Host 'The CI artifact is unsigned; production signing is required before distribution or installation.'
}
finally {
  foreach ($nested in $nestedArchives) {
    $nested.Dispose()
  }
  foreach ($memory in $memoryStreams) {
    $memory.Dispose()
  }
  $archive.Dispose()
}
