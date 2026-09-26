function Remove-WindowsDeviceLinkAssociation {
    <#
    .SYNOPSIS
    Removes a cloud association through Direct operator sign-in or the Backend API.
    .DESCRIPTION
    Backend mode resolves the source tenant server-side using the serial number.
    Without a serial number, the local device serial is used. Local firmware is not reset.
    #>
    [CmdletBinding(DefaultParameterSetName='Direct', SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(ParameterSetName='Direct')][ValidateNotNullOrEmpty()][string]$AssociationId,
        [ValidateNotNullOrEmpty()][string]$SerialNumber,
        [Parameter(Mandatory,ParameterSetName='Direct')][ValidateSet('DeviceCode','Interactive')][string]$Method,
        [Parameter(ParameterSetName='Direct')][ValidateNotNullOrEmpty()][string]$TenantId,
        [Parameter(ParameterSetName='Direct')][ValidateNotNullOrEmpty()][string]$ClientId,
        [Parameter(ParameterSetName='Direct')][ValidateNotNullOrEmpty()][string]$Environment = 'Global',
        [Parameter(ParameterSetName='Direct')][ValidateRange(1,600)][double]$ClientTimeout = 100,
        [Parameter(Mandatory,ParameterSetName='Backend')][ValidateNotNull()][uri]$BackendUri,
        [Parameter(Mandatory,ParameterSetName='Backend')][ValidateNotNull()][securestring]$BackendApiKey,
        [Parameter(ParameterSetName='Backend')][ValidateRange(5,600)][int]$TimeoutSeconds = 120
    )

    if ($PSCmdlet.ParameterSetName -eq 'Direct') {
        return Remove-WindowsDeviceLinkAssociationCore @PSBoundParameters
    }

    if (-not $SerialNumber) {
        $SerialNumber = ([string](Get-CimInstance -ClassName Win32_BIOS -ErrorAction Stop).SerialNumber).Trim()
        if (-not $SerialNumber) { throw 'The local device serial number is unavailable.' }
    }
    if ($PSCmdlet.ShouldProcess($SerialNumber, 'Remove the cloud Device Association through the backend')) {
        $credential = New-Object System.Management.Automation.PSCredential('api-key', $BackendApiKey)
        $plainKey = $null
        try {
            $plainKey = $credential.GetNetworkCredential().Password
            Invoke-WindowsDeviceLinkBackendOffboard -BackendUri $BackendUri -BackendApiKey $plainKey -SerialNumber $SerialNumber -TimeoutSeconds $TimeoutSeconds
        }
        finally { $plainKey = $null; $credential = $null }
    }
}
