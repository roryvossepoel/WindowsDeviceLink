function Get-WindowsDeviceLinkTenantCatalog {
    <#
    .SYNOPSIS
    Reads tenant names, IDs and effective client IDs from one Direct configuration.
    .DESCRIPTION
    Configuration accepts a local JSON file, a trusted HTTPS URL, or inline JSON.
    The same schema is validated for every source. Tenant clientId overrides the shared
    clientId; when both are omitted, the authentication method's standard client is used.
    This command reads data only and does not authenticate. Use Name or TenantId to
    select exactly one entry for a CLI operation.
    .EXAMPLE
    Get-WindowsDeviceLinkTenantCatalog -Configuration 'E:\Config\devicelink.json'
    .EXAMPLE
    Get-WindowsDeviceLinkTenantCatalog -Configuration 'E:\Config\devicelink.json' -Name 'Tenant Alpha'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Configuration,
        [ValidateNotNullOrEmpty()][string]$Name,
        [guid]$TenantId
    )

    if ($PSBoundParameters.ContainsKey('Name') -and $PSBoundParameters.ContainsKey('TenantId')) {
        throw '-Name and -TenantId cannot be combined.'
    }
    $entries = @(Read-WindowsDeviceLinkConfiguration -Configuration $Configuration)
    if ($PSBoundParameters.ContainsKey('Name')) {
        $entries = @($entries | Where-Object { $_.Name -ieq $Name.Trim() })
    }
    elseif ($PSBoundParameters.ContainsKey('TenantId')) {
        $entries = @($entries | Where-Object { $_.TenantId -eq $TenantId.ToString() })
    }
    if (($PSBoundParameters.ContainsKey('Name') -or $PSBoundParameters.ContainsKey('TenantId')) -and $entries.Count -ne 1) {
        throw 'The configuration must resolve the requested tenant to exactly one entry.'
    }
    $entries
}
