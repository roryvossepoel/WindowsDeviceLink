function Get-WindowsDeviceLinkStatus {
    <#
    .SYNOPSIS
    Returns a combined local DeviceLink diagnostic status with optional Intune Device Association state.

    .DESCRIPTION
    Combines runtime support, local DeviceLink identity metadata, and safe local firmware-state metadata in one object.
    By default the cmdlet performs no Microsoft Graph authentication or tenant lookup.

    Use -Online with an explicit authentication method to add the tenant-side Intune Device Association state.
    An online lookup that successfully finds no association is reported as AssociationPresent = False and AssociationState = NotAssociated;
    this is a normal status result, not an error. A failed or indeterminate lookup is reported as AssociationPresent = $null,
    AssociationState = Unknown, with AssociationError populated; it must not be interpreted as confirmed absence.

    PayloadCreationTimeUtc is the timestamp contained in the newly generated DeviceLink payload. Live validation showed
    that this value changes between payload generations while LinkId remains stable; it must not be interpreted as the
    persistent local identity creation time.

    FirmwareCreationTimeUtc is decoded from the local DeviceLinkCreationTimeUtc UEFI variable. Live validation showed
    this firmware timestamp remained stable across repeated DeviceLink payload generations. The exact Windows lifecycle
    event represented by this persistent timestamp is not claimed beyond the firmware variable's own name.
    #>
    [CmdletBinding(DefaultParameterSetName='Direct')]
    param(
        [ValidateNotNullOrEmpty()][string]$WindowsManagementServicePath,
        [ValidateRange(5, 600)][int]$TimeoutSeconds = 120,
        [Parameter(ParameterSetName='Direct')][switch]$Online,
        [Parameter(ParameterSetName='Direct')][ValidateSet('DeviceCode','Interactive')][string]$Method,
        [Parameter(ParameterSetName='Direct')][ValidateNotNullOrEmpty()][string]$TenantId,
        [Parameter(ParameterSetName='Direct')][ValidateNotNullOrEmpty()][string]$ClientId,
        [Parameter(ParameterSetName='Direct')][ValidateNotNullOrEmpty()][string]$Environment = 'Global',
        [Parameter(ParameterSetName='Direct')][ValidateRange(1, 600)][double]$ClientTimeout = 100,
        [Parameter(Mandatory,ParameterSetName='Backend')][ValidateNotNull()][uri]$BackendUri,
        [Parameter(Mandatory,ParameterSetName='Backend')][ValidateNotNull()][securestring]$BackendApiKey
    )

    if ($PSCmdlet.ParameterSetName -eq 'Backend') {
        $credential = New-Object System.Management.Automation.PSCredential('api-key', $BackendApiKey)
        $plainKey = $null
        try {
            $plainKey = $credential.GetNetworkCredential().Password
            $parameters = @{ BackendUri=$BackendUri; BackendApiKey=$plainKey; TimeoutSeconds=$TimeoutSeconds }
            if ($PSBoundParameters.ContainsKey('WindowsManagementServicePath')) {
                $parameters.WindowsManagementServicePath = $WindowsManagementServicePath
            }
            return Get-WindowsDeviceLinkBackendStatus @parameters
        }
        finally { $plainKey = $null; $credential = $null }
    }
    Get-WindowsDeviceLinkStatusCore @PSBoundParameters
}
