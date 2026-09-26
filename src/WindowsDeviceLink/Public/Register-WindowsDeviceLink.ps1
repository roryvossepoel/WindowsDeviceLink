function Register-WindowsDeviceLink {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSTypeName('Windows.DeviceLink.Information')]
        [psobject]$InputObject,
        [ValidateSet(
            'DeviceCode',
            'Interactive',
            'Webhook'
        )]
        [string]$Method,
        [ValidateNotNullOrEmpty()]
        [string]$TenantId,
        [ValidateNotNullOrEmpty()]
        [string]$ClientId,
        [uri]$WebhookUri,
        [ValidateNotNullOrEmpty()]
        [string]$WebhookApiKey,
        [ValidateNotNullOrEmpty()]
        [string]$Environment = 'Global',
        [ValidateRange(1, 600)]
        [double]$ClientTimeout = 100
    )

    process { Register-WindowsDeviceLinkCore @PSBoundParameters }
}
