# WindowsDeviceLink command reference

Windows PowerShell can show the current syntax and parameter help directly:

```powershell
Get-Command -Module WindowsDeviceLink
Get-Help Show-WindowsDeviceLink -Full
```

| Command | Purpose |
|---|---|
| `Complete-WindowsDeviceLinkAssociation` | Guardedly complete a preassociated DeviceLink on the local device and verify the resulting firmware/JWT state. |
| `Connect-WindowsDeviceLink` | Delegated Microsoft Graph sign-in using Interactive or DeviceCode authentication. |
| `Export-WindowsDeviceLinkCsv` | Export an existing DeviceLink object using the Windows CSV API. |
| `Get-WindowsDeviceLink` | Obtain the local DeviceLink identity and optionally export it. |
| `Get-WindowsDeviceLinkAssociation` | Query a tenant-side Intune Device Association by serial number or association ID. |
| `Get-WindowsDeviceLinkBackendTenant` | Read the authenticated Function backend tenant catalog. |
| `Get-WindowsDeviceLinkFirmwareState` | Read safe firmware metadata and the validated timestamp. |
| `Get-WindowsDeviceLinkLocalAssociation` | Correlate the local identity with registry and Association JWT tenant hints without cloud access. |
| `Get-WindowsDeviceLinkRepairPlan` | Return a non-destructive repair recommendation for the observed lifecycle state. |
| `Get-WindowsDeviceLinkStatus` | Combine runtime, identity, firmware and optional tenant-side diagnostics. |
| `Initialize-WindowsDeviceLink` | Safely initialize pre-association and optionally complete association with explicit `-Associate`. |
| `Register-WindowsDeviceLink` | Explicitly create a tenant-side pre-association directly or through a webhook. |
| `Remove-WindowsDeviceLinkAssociation` | Remove a tenant-side Device Association record. |
| `Reset-WindowsDeviceLinkFirmwareState` | Reset and immediately verify local DeviceLink UEFI identity state. |
| `Set-WindowsDeviceLinkTenant` | Apply New/no-op in Direct mode or New/no-op/verified Move in Backend mode. |
| `Show-WindowsDeviceLink` | Open the Windows 11 or WinPE operator GUI. Native completion remains disabled in WinPE. |
| `Test-WindowsDeviceLinkAssociationJwt` | Validate local association JWT structure, time and identity correlation without exposing the raw JWT. |
| `Test-WindowsDeviceLinkDiscovery` | Perform read-only native DeviceLink association discovery. |
| `Test-WindowsDeviceLinkHealth` | Non-destructively classify status into machine-readable lifecycle and health states. |
| `Test-WindowsDeviceLinkPreflight` | Assess runtime, firmware, TPM, Secure Boot and DeviceLink prerequisites. |
| `Test-WindowsDeviceLinkRuntime` | Validate an administrator-supplied runtime DLL without changing state. |
| `Test-WindowsDeviceLinkSupport` | Validate runtime, architecture and DeviceLink activation. |

See the [FAQ](FAQ.md) for task-oriented examples and safe lifecycle guidance.
