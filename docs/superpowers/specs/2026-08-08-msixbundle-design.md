# Windows MSIXBundle Design

## Goal

Address upstream issue #2209 by adding a repeatable Windows packaging path that
produces one `.msixbundle` containing native x64 and ARM64 FlClash packages.
The path must also make the packaging result visible in CI instead of relying
on a filename-only check.

## Scope and acceptance criteria

- `dart setup.dart windows --targets msix` produces one architecture-specific
  `.msix` on the current Windows host.
- The packaging command derives the MSIX processor architecture from the host
  architecture and never silently labels an ARM64 build as x64.
- Pull Request CI builds x64 on `windows-2022` and ARM64 on the GitHub-hosted
  `windows-11-arm` runner.
- A Windows SDK `MakeAppx.exe bundle` step creates a real `.msixbundle` from
  those two `.msix` files.
- Each architecture-specific `.msix` is independently inspected before
  bundling, including its manifest architecture and required package files.
- A package verifier extracts the bundle and checks the nested package count,
  processor architectures, shared identity/version/publisher fields, and the
  bundle manifest's `Architecture`, `FileName`, and version references.
- The CI artifact is intentionally unsigned because a production certificate
  must not be stored in a public repository or exposed in Pull Request logs.
  The verifier must state this boundary; it must not claim that the CI artifact
  is ready for end-user installation.
- The existing EXE/ZIP packaging path and all non-Windows targets remain
  unchanged.

## Current constraints

The pinned Flutter Distributor integration can make a single `.msix`, but it
does not make a `.msixbundle` and its MSIX configuration is static. The project
therefore uses the project-owned setup CLI for the architecture-specific MSIX
step and the Windows SDK directly for bundling. Microsoft documents that
`MakeAppx.exe` requires matching identity, publisher, and version while allowing
different processor architectures, and that the resulting bundle must be
signed before distribution.

The hosted Flutter action currently provides the Windows SDK as x64. The
ARM64 job therefore installs that SDK as a bootstrap tool, removes its cached
x64 Dart stamp and x64 Flutter tool snapshot, downloads the native ARM64 Dart
SDK, lets Flutter rebuild its tool snapshot for that VM, precaches the ARM64
Windows engine, and fails before building if either native component is absent.

## Approaches considered

### A. Use Flutter Distributor only

This keeps the current packaging command unchanged, but it stops at individual
`.msix` files and cannot express the two-architecture bundle. It also makes the
architecture selection depend on a static third-party config file.

### B. Build one architecture and rename it `.msixbundle`

This is small but invalid: a renamed MSIX is not a bundle and Windows will not
find both processor architectures. It would pass a superficial filename check
while failing the requested feature.

### C. Use the setup CLI for native MSIX builds and MakeAppx for bundling

This is the selected approach. It keeps the app build and environment setup in
the repository-owned CLI, uses native hosted runners for each architecture, and
uses Microsoft's bundle tool for the format-specific final step. The downside
is a few extra CI jobs and the need to sign the final artifact in a release
workflow, but those costs are visible and appropriate for a cross-platform
installer.

## Architecture

### CLI layer

`setup.dart` recognizes the `msix` target as a Windows-only special path. It
still prepares the Go core checksum and `env.json`, then runs a release Windows
build and invokes the `msix` package with explicit metadata, architecture,
output directory, and `sign_msix=false`. The explicit publisher value keeps the
manifest deterministic even though Pull Request artifacts are unsigned.

The normal `exe` and `zip` targets continue to go through Flutter Distributor.
The `msix` target is deliberately kept separate so it cannot accidentally
change existing package outputs.

### CI layer

Two independent jobs run in parallel:

1. `windows-msix-x64` on `windows-2022`.
2. `windows-msix-arm64` on `windows-11-arm`.

Each job uploads exactly one architecture-specific `.msix`. A third
`windows-msixbundle` job downloads both artifacts, places only those packages
in a clean directory, calls `MakeAppx.exe bundle`, and runs the PowerShell
bundle verifier. The final `.msixbundle` is uploaded as a short-retention PR
artifact and is a prerequisite of the existing platform build rollup. A final
`ci-complete` job runs even when an upstream job fails and becomes the single
stable status check that can be required by branch protection.

### Verification layer

- Dart unit tests cover architecture mapping and the exact unsigned MSIX
  command contract.
- A Ruby static verifier checks that the workflow has both native architecture
  jobs, the bundle job, the expected artifact handoff, and the structural
  verifier command.
- The Windows PowerShell verifier opens the generated bundle as a ZIP package,
  reads `AppxBundleManifest.xml` plus the nested `AppxManifest.xml` files, and
  fails unless it finds exactly one `x64` and one `arm64` application package,
  with matching identity, version, publisher, architecture, and file
  references.
- The same Windows job verifies each individual `.msix` before it is uploaded,
  including `AppxManifest.xml`, `AppxBlockMap.xml`, `resources.pri`, an
  application executable, and the executable's PE machine type (`0x8664` for
  x64 or `0xAA64` for ARM64). This prevents a package from passing only because
  its manifest was labeled with the requested architecture.
- The CI layout verifier requires the new job dependencies and static verifier
  entry plus the final `ci-complete` gate, preventing the checks from
  disappearing during later workflow edits.

## Failure handling

- Unsupported host platforms or a non-Windows request for `msix` exits before
  changing the existing package flow.
- A missing `msix` artifact, missing Windows SDK `MakeAppx.exe`, failed bundle
  command, malformed bundle, duplicate architecture, or mismatched identity
  fails the job immediately.
- The verifier reports unsigned status as an explicit packaging boundary. It
  does not attempt to install an unsigned artifact.

## Out of scope

- Publishing to Microsoft Store.
- Storing or creating a trusted production certificate in Pull Request CI.
- Replacing the existing EXE installer.
- Testing Windows UI behavior on the user's Mac. The Windows-hosted jobs cover
  the build and package structure; physical end-user installation with a
  trusted certificate remains a release-stage check.

## References

- Microsoft, “Bundle MSIX packages”: https://learn.microsoft.com/en-us/windows/msix/packaging-tool/bundle-msix-packages
- Microsoft, “Create an app package with the MakeAppx.exe tool”: https://learn.microsoft.com/en-us/windows/msix/package/create-app-package-with-makeappx-tool
- Upstream issue #2209: https://github.com/chen08209/FlClash/issues/2209
