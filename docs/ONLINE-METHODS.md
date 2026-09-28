# Choosing an online method

Starting with `0.4.4-preview1`, WindowsDeviceLink separates local DeviceLink identity from tenant-side Device Association operations.

```text
Get-WindowsDeviceLink
    Local DeviceLink identity only

Get-WindowsDeviceLinkFirmwareState
    Local UEFI / firmware state only

Get-WindowsDeviceLinkAssociation
    Read the tenant-side Intune Device Association

Register-WindowsDeviceLink
    Create the tenant-side Intune pre-association

Remove-WindowsDeviceLinkAssociation
    Remove the tenant-side Intune Device Association

Get-WindowsDeviceLinkStatus -Online
    Combine local diagnostics with tenant-side state

Initialize-WindowsDeviceLink
    Safely ensure a validated LocalOnly device is preassociated
```

`Get-WindowsDeviceLink -Online` has been removed. This is an intentional breaking preview change: local identity retrieval no longer changes meaning when a switch is supplied.

## Authentication routes

Both UI and CLI support the same decision:

| Route | Intended use | Authentication |
|---|---|---|
| Direct | Operator present on the target device | Interactive/WAM on Windows, or DeviceCode subject to tenant policy |
| Backend | Operator or unattended provisioning on the target device | Backend API key supplied at runtime |

Direct cmdlets accept `-Method Interactive` or `-Method DeviceCode`. The low-level
`Register-WindowsDeviceLink -Method Webhook` remains an API transport, not an additional
Direct authentication method. Prefer the Backend workflow for verified assignment.

Direct app-only credentials and caller-supplied access tokens are no longer accepted.
See [security guidance](AUTHENTICATION-SECURITY.md).

## Tenant selection

`-TenantId` is optional for Direct operator authentication. Without it, the sign-in
context determines the tenant. Specify it to intentionally target a tenant. Operators
must authenticate in each target tenant; a tenant catalog does not grant permission.
Native DeviceCode uses the `organizations` authority by default and reads token tenant
metadata for result correlation.

## DeviceCode client ID

When `-Method DeviceCode` is used without an explicit `-ClientId`, WindowsDeviceLink uses this well-known Microsoft public client ID:

```text
14d82eec-204b-4c2f-b7e8-296a70dab67e
```

This is the Microsoft Graph PowerShell / Graph Command Line Tools public client ID. It is not a customer-specific application registration, tenant identifier, client secret, certificate, or confidential credential. Public client IDs are identifiers, not secrets.

You can override it with your own public client application ID.

## Manual pre-association

First obtain the local identity, then explicitly register it:

```powershell
$deviceLink = Get-WindowsDeviceLink

$deviceLink | Register-WindowsDeviceLink `
    -Method DeviceCode `
    -TenantId '<tenant-id>'
```

This makes the state-changing cloud operation visible in the command name and pipeline.

## Query the tenant-side association

By serial number:

```powershell
Get-WindowsDeviceLinkAssociation `
    -SerialNumber '<serial-number>' `
    -Method DeviceCode `
    -TenantId '<tenant-id>'
```

Or by the exact association ID:

```powershell
Get-WindowsDeviceLinkAssociation `
    -AssociationId '<association-id>' `
    -Method DeviceCode `
    -TenantId '<tenant-id>'
```

The returned object uses the type name `Windows.DeviceLink.Association` and contains the association state, managed-device linkage, timestamps and Device Preparation policy information returned by Microsoft Graph.

### Serial-number lookup note

Live validation showed that the Graph beta endpoint can accept a `serialNumber` filter yet return no match for a record that is present. The module therefore retains a paged client-side matching fallback. This produced correct results for both existing and absent associations, but may be inefficient with large Device Association populations. The behavior is tracked in GitHub issue #1 and should be retested as the beta API evolves.

## Combined online status

`Get-WindowsDeviceLinkStatus` is local by default. Add `-Online` only when tenant correlation is required:

```powershell
Get-WindowsDeviceLinkStatus `
    -Online `
    -Method DeviceCode `
    -TenantId '<tenant-id>'
```

A confirmed lookup with no record returns `CloudChecked=True`, `AssociationPresent=False`, and `AssociationState=NotAssociated`. Authentication/Graph failures instead return `AssociationState=Unknown` plus `AssociationError`; they are not treated as proof that no association exists.

## Safe initialization

For the common workflow “preassociate this device if it is locally healthy and not already known to the tenant”:

```powershell
Initialize-WindowsDeviceLink `
    -Method DeviceCode `
    -TenantId '<tenant-id>'
```

The initializer obtains combined status, classifies it, and only registers from the validated `LocalOnly` state. It then verifies the result using the read path. `Preassociated` and `Associated` return `Action=None`; unexpected or incomplete states are blocked. It never resets firmware, removes associations, or reboots.

With `-Method DeviceCode`, one access token is obtained at the start and reused for lookup, registration, and verification. The token is kept in memory only for the run and is not included in the result object.

`-WhatIf` still performs the required read-only cloud lookup so it can determine whether registration would be needed, but it suppresses the registration write.

## Unattended endpoint or WinPE

Use Backend mode for unattended tenant lookup, assignment and verification. Supply
the API key as a SecureString through your protected runtime configuration:

```powershell
Set-WindowsDeviceLinkTenant `
    -BackendUri 'https://backend.example.com/api/devicelink' `
    -BackendApiKey $apiKey `
    -TargetTenantId '<target-tenant-id>'
```

The backend keeps Graph credentials in Azure and checks all configured tenants.
See [tenant assignment modes](TENANT-ASSIGNMENT-MODES.md) for New, no-op and Move behavior.
Direct DeviceCode in WinPE still requires an operator to complete sign-in.

The low-level Webhook transport remains available for explicit pre-association:

```powershell
$deviceLink = Get-WindowsDeviceLink

$deviceLink | Register-WindowsDeviceLink `
    -Method Webhook `
    -WebhookUri '<webhook-url>' `
    -WebhookApiKey $env:WINDOWSDEVICELINK_WEBHOOK_API_KEY `
    -TenantId '<target-tenant-id>'
```

The Azure Function backend owns tenant routing and Graph authentication.

`Initialize-WindowsDeviceLink` also supports Direct and Backend parameter sets, but
blocks an association found in a different tenant. Use `Set-WindowsDeviceLinkTenant`
for the guarded Backend tenant-assignment workflow, including verified moves.

## Existing Graph SDK session

`Register-WindowsDeviceLink` retains the advanced connected-session pattern. If `Connect-WindowsDeviceLink` has already established a Microsoft Graph session, `-Method` can be omitted:

```powershell
Connect-WindowsDeviceLink -TenantId '<tenant-id>'
Get-WindowsDeviceLink | Register-WindowsDeviceLink
```

## Parameter validation

WindowsDeviceLink rejects missing required method inputs and parameters that do not belong to the selected authentication method. `Get-WindowsDeviceLinkAssociation` also requires exactly one of `-SerialNumber` or `-AssociationId`.

## Backend CLI status

```powershell
# $apiKey is a SecureString supplied by protected runtime configuration.
Get-WindowsDeviceLinkStatus `
    -BackendUri 'https://backend.example.com/api/devicelink' `
    -BackendApiKey $apiKey
```

Backend parameters select the API route; do not combine them with `-Online` or
`-Method`. Without Backend parameters, `-Online -Method Interactive` or
`-Online -Method DeviceCode` selects Direct cloud lookup.
