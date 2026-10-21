# WindowsDeviceLink support

WindowsDeviceLink is a community project and is not a Microsoft product. It does not come
with a production support agreement or response-time guarantee.

## Supported environments

The current stable release supports:

- physical Windows 11 devices on AMD64 and ARM64;
- compatible AMD64 Windows PE with an administrator-supplied Microsoft runtime;
- Direct mode with Interactive or DeviceCode authentication;
- Backend mode through the included Azure Function App API.

ARM64 Windows PE has not been validated and is not currently supported. Microsoft Graph
beta APIs and native DeviceLink interfaces can change independently of this project.

See [README.md](README.md#requirements) for the concise matrix and
[TESTING.md](TESTING.md) for recorded validation evidence.

## Getting help

Before opening an issue:

1. Install or reproduce with the latest stable WindowsDeviceLink release.
2. Run `Test-WindowsDeviceLinkSupport` and, where relevant,
   `Test-WindowsDeviceLinkPreflight`.
3. Check the [FAQ](docs/FAQ.md), [installation guide](docs/INSTALLATION.md) and existing
   GitHub issues.
4. Remove all secrets and replace identifying device, tenant and customer data.

Use the repository's bug-report form for reproducible defects and the feature-request form
for proposed behavior. Include the module version, architecture, environment, Direct or
Backend mode, interface, authentication route and sanitized output.

Questions about Microsoft Intune licensing, service incidents, tenant configuration outside
WindowsDeviceLink or unsupported Microsoft APIs may need to be raised with Microsoft.

## Security reports

Do not open a public issue for a suspected vulnerability. Follow the private reporting
process in [SECURITY.md](SECURITY.md).
