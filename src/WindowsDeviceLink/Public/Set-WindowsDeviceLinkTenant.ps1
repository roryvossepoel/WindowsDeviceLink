function Set-WindowsDeviceLinkTenant {
    <#
    .SYNOPSIS
    Ensures that the local device is pre-associated using Direct or Backend mode.
    .DESCRIPTION
    Direct mode uses one Microsoft Graph authentication context and can perform New or
    no-op in that tenant. TenantId is optional for interactive and device-code sign-in;
    when omitted, the authenticated tenant context is authoritative.

    Backend mode uses the Function tenant catalog and authoritative multitenant lookup
    to choose New, None, or Move. The backend never chooses the target tenant.

    A Move is a deliberate physical-device transfer: after confirmation, this cmdlet
    clears the local DeviceLink UEFI identity, creates a new TPM-backed identity, and
    asks the backend to delete the proven source record and pre-associate the new
    identity with the target. Cloud state is then read back across all configured
    tenants. No mutation is blindly retried.

    Run this operation from Windows PE or from the intended OOBE servicing context.
    Clearing DeviceLink firmware doesn't unenroll Windows or remove Entra/Intune
    device records belonging to the previous deployment.
    #>
    [CmdletBinding(DefaultParameterSetName='Direct',SupportsShouldProcess,ConfirmImpact='High')]
    param(
        [Parameter(Mandatory,ParameterSetName='Direct')]
        [ValidateSet('DeviceCode','Interactive')]
        [string]$Method,
        [Parameter(ParameterSetName='Direct')][ValidateNotNullOrEmpty()][string]$TenantId,
        [Parameter(ParameterSetName='Direct')][ValidateNotNullOrEmpty()][string]$ClientId,
        [Parameter(ParameterSetName='Direct')][ValidateNotNullOrEmpty()][string]$Environment = 'Global',
        [Parameter(ParameterSetName='Direct')][ValidateRange(1,600)][double]$ClientTimeout = 100,
        [Parameter(Mandatory,ParameterSetName='BackendById')]
        [Parameter(Mandatory,ParameterSetName='BackendByName')]
        [ValidateNotNull()][uri]$BackendUri,
        [Parameter(Mandatory,ParameterSetName='BackendById')]
        [Parameter(Mandatory,ParameterSetName='BackendByName')]
        [ValidateNotNull()][securestring]$BackendApiKey,
        [Parameter(Mandatory,ParameterSetName='BackendById')][guid]$TargetTenantId,
        [Parameter(Mandatory,ParameterSetName='BackendByName')][ValidateNotNullOrEmpty()][string]$TargetTenantName,
        [Parameter(ParameterSetName='BackendById')]
        [Parameter(ParameterSetName='BackendByName')]
        [switch]$RepairExistingAssociation,
        [ValidateNotNullOrEmpty()][string]$WindowsManagementServicePath,
        [ValidateRange(5,600)][int]$TimeoutSeconds = 120
    )

    Set-WindowsDeviceLinkTenantCore @PSBoundParameters
}
