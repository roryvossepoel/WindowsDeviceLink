function Initialize-WindowsDeviceLink {
    <#
    .SYNOPSIS
    Safely ensures that the local DeviceLink has a tenant-side preassociation and can optionally complete device-side association.

    .DESCRIPTION
    Orchestrates existing WindowsDeviceLink operations without performing destructive repair.
    The cmdlet obtains the local DeviceLink, checks the tenant-side Device Association, classifies
    health, and creates a preassociation only when the validated state is LocalOnly.

    By default, existing preassociated or associated records are left unchanged. Specify
    -Associate to opt in to association after the state has been verified as
    Preassociated.

    Direct mode uses the selected Microsoft Graph authentication method. Backend mode uses
    the WindowsDeviceLink Azure Function App for authoritative multitenant cloud lookup and
    pre-association, while native association still runs locally on the device.

    Backend mode never performs an implicit tenant move. If the current association is found
    in a different tenant than -TargetTenantId, initialization is blocked and an explicit
    tenant-move workflow is required. Completion uses the guarded Complete-WindowsDeviceLinkAssociation cmdlet and
    therefore performs at most one ConfigureDeviceLinkAsync call, with no retry, reset, cleanup,
    cloud deletion, or reboot.

    Unexpected, incomplete, unsupported, or unknown states are blocked rather than repaired
    automatically.

    For DeviceCode authentication, one token is acquired at the start and reused for lookup,
    registration, and verification so one initialization run requires only one device-code sign-in.

    This cmdlet never resets firmware state, removes an association, or reboots the device.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Direct', SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Direct')]
        [ValidateSet('DeviceCode','Interactive')]
        [string]$Method,
        [Parameter(ParameterSetName = 'Direct')][ValidateNotNullOrEmpty()][string]$TenantId,
        [Parameter(ParameterSetName = 'Direct')][ValidateNotNullOrEmpty()][string]$ClientId,
        [Parameter(Mandatory, ParameterSetName = 'Backend')]
        [ValidateNotNull()]
        [uri]$BackendUri,
        [Parameter(Mandatory, ParameterSetName = 'Backend')]
        [ValidateNotNullOrEmpty()]
        [string]$BackendApiKey,
        [Parameter(Mandatory, ParameterSetName = 'Backend')]
        [guid]$TargetTenantId,
        [Parameter(ParameterSetName = 'Direct')][ValidateNotNullOrEmpty()][string]$Environment = 'Global',
        [Parameter(ParameterSetName = 'Direct')][ValidateRange(1, 600)][double]$ClientTimeout = 100,
        [ValidateNotNullOrEmpty()][string]$WindowsManagementServicePath,
        [ValidateRange(5, 600)][int]$TimeoutSeconds = 120,
        [switch]$Associate
    )

    Initialize-WindowsDeviceLinkCore @PSBoundParameters
}
