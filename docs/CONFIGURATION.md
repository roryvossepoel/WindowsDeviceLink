# Direct configuration

One `-Configuration` parameter accepts a local JSON file, an absolute HTTPS URL, or
inline JSON text. It is data only: scriptblocks and PowerShell expressions are not executed.
The same versioned schema and validation apply to all three sources.

Without configuration, `Show-WindowsDeviceLink` still starts with the existing operator
sign-in flow. Configuration is optional and contains no credentials.

## Single tenant

```json
{
  "schemaVersion": 1,
  "mode": "Direct",
  "tenants": [
    {
      "name": "Tenant Alpha",
      "tenantId": "11111111-1111-1111-1111-111111111111"
    }
  ]
}
```

The GUI shows **Tenant Alpha** as a fixed destination, without a dropdown. The configured
name is displayed before sign-in and used wherever that tenant ID is shown. It is a local
label, not a name retrieved or verified through Graph. No additional Graph permissions
are requested. Sign-in is directed to the configured tenant and the session tenant is
checked before the GUI enables cloud actions.

## Multiple tenants and app registrations

Use the same tenants array with more than one entry. The GUI shows a dropdown and
requires selection before sign-in. Sign out before choosing another tenant and signing
in again. Direct mode does not scan all tenants or perform a cross-tenant Move.

A shared clientId specifies one public client app registration for all listed tenants:

```json
{
  "schemaVersion": 1,
  "mode": "Direct",
  "clientId": "33333333-3333-3333-3333-333333333333",
  "tenants": [
    {
      "name": "Tenant Alpha",
      "tenantId": "11111111-1111-1111-1111-111111111111"
    },
    {
      "name": "Tenant Beta",
      "tenantId": "22222222-2222-2222-2222-222222222222"
    }
  ]
}
```

Each tenant can optionally supply its own `clientId`. Resolution is:

1. Tenant entry's clientId.
2. Shared top-level clientId.
3. Authentication method's standard client when neither is supplied.

A client ID is a public identifier, not a credential. JSON does not make an application
multitenant or grant consent. Configure the app for the required delegated/public-client
flow and grant consent in each target tenant. The operator also needs rights in each
tenant. Interactive and DeviceCode both receive the effective client ID.

## Three ways to load the same configuration

```powershell
Show-WindowsDeviceLink -Configuration 'X:\Config\devicelink.json'

Show-WindowsDeviceLink -Configuration 'https://config.example.com/devicelink.json'

$config = @'
{
  "schemaVersion": 1,
  "mode": "Direct",
  "tenants": [
    {
      "name": "Tenant Alpha",
      "tenantId": "11111111-1111-1111-1111-111111111111"
    }
  ]
}
'@
Show-WindowsDeviceLink -Configuration $config -Method DeviceCode
```

The inline form is a PowerShell here-string, not `{ ... }` executable script code.
Windows defaults to Interactive; WinPE defaults to DeviceCode. An explicit `-Method`
can select the supported flow. WinPE still requires the user-supplied DeviceLink DLL
when it is not already available.

## Validation and boundaries

- schemaVersion must be integer 1 and mode must be `Direct`.
- tenants must contain at least one entry, with a non-empty GUID tenantId and a name.
- Names are trimmed, limited to 128 characters without control characters and must be
  unique ignoring case. Tenant IDs must also be unique.
- Optional clientId values must be non-empty GUID strings.
- Unknown fields are rejected. Do not put secrets, tokens, private keys or credentials
  in the configuration. The supported fields are schemaVersion, mode, clientId and
  tenants; tenant entries support name, tenantId and clientId.
- Do not combine `-Configuration` with `-TenantId`, `-ClientId`, or Backend parameters.
  There is one source for Direct tenant/client choices. Backend keeps its API-provided
  catalog and existing API-key authentication.
- HTTPS endpoints must return JSON directly with status 200. Redirects, HTTP URLs and
  embedded URL credentials are rejected. Downloads time out after 15 seconds.
  Files and JSON payloads are limited to 1 MiB. Use only trusted configuration sources:
  changing the file changes the destination tenant or application used for sign-in.

## CLI boundary

This configuration belongs to `Show-WindowsDeviceLink` and is not a second CLI
configuration route. CLI commands use explicit `TenantId`, optional `ClientId`, and
`Method` parameters. An external UI or bootstrapper may maintain its own configuration
and pass those explicit values to the module.

## Generic examples

Replace the illustrative GUIDs with your own identifiers:

- [One tenant, default client](../examples/configuration-single.example.json)
- [Multiple tenants, default client](../examples/configuration-multiple.example.json)
- [Shared multitenant app](../examples/configuration-shared-app.example.json)
- [Shared app with tenant override](../examples/configuration-tenant-apps.example.json)
