# Contributing to WindowsDeviceLink

Thank you for helping improve WindowsDeviceLink. Contributions can include bug reports,
documentation corrections, test coverage and focused code changes.

## Before you start

- Search the existing issues and pull requests before opening a new one.
- Use the bug or feature issue form so the environment and execution path are clear.
- Keep a pull request focused on one problem or closely related set of changes.
- Discuss large behavioral, API or lifecycle changes in an issue before implementing them.

## Protect secrets and device data

WindowsDeviceLink handles security-sensitive device and tenant information. Never commit
or paste live:

- API keys, access or refresh tokens, client secrets, certificates or private keys;
- tenant IDs, app IDs, serial numbers, SMBIOS UUIDs, Link IDs or association IDs;
- DeviceLink payloads, association JWTs or unredacted diagnostic exports;
- production Function App URLs, configuration files or logs containing customer data.

Use clearly fictitious replacement values in examples and reports. If a secret has been
exposed, revoke or rotate it before doing anything else. Report security vulnerabilities
privately as described in [SECURITY.md](SECURITY.md).

## Development environment

The module targets native 64-bit Windows PowerShell 5.1. Source is under
`src/WindowsDeviceLink`; tests are under `tests`. The CI workflow in
`.github/workflows/ci.yml` is the authoritative validation list.

For module or command changes, build the same staged package used by CI:

```powershell
$outputRoot = Join-Path $env:TEMP 'WindowsDeviceLink-Package'
.\tools\New-GalleryPackage.ps1 -OutputRoot $outputRoot

$packageRoot = Join-Path $outputRoot 'WindowsDeviceLink'
$modulePath = Join-Path $packageRoot 'WindowsDeviceLink.psd1'

.\tests\Public-Contract-Validation.ps1 `
    -ModulePath $modulePath `
    -PackageRoot $packageRoot

.\tests\Documentation-Examples-Validation.ps1 -ModulePath $modulePath
```

Run the tests relevant to the changed component. For documentation changes, run:

```text
python3 tests/Documentation-Links-Tests.py
python3 tests/Documentation-Links-Validation.py
```

All pull requests must pass the complete GitHub Actions workflow.

## Project boundaries

- Preserve `SupportsShouldProcess`, confirmation and post-state verification around
  destructive or tenant-changing operations.
- Do not weaken secret redaction, tenant-boundary checks or Backend authorization.
- Do not redistribute `Windows.Management.Service.dll` or other Microsoft binaries.
- Treat Microsoft Graph beta behavior and the native DeviceLink runtime as changeable;
  include regression coverage for assumptions encoded in the module.
- Keep Windows PE limitations and architecture-specific behavior explicit.

## Pull requests

Describe the problem, the chosen behavior and how it was tested. Include sanitized output
when it materially helps review. Documentation and examples must match the public command
contract. A live device test is welcome for hardware-dependent changes, but it does not
replace automated regression coverage where that coverage is practical.

By contributing, you agree that your contribution is licensed under the repository's
[MIT License](LICENSE).
