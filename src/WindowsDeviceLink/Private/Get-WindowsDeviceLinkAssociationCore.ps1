function Get-WindowsDeviceLinkAssociationCore {
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()][string]$AssociationId,
        [ValidateNotNullOrEmpty()][string]$SerialNumber,
        [Parameter(Mandatory)]
        [ValidateSet('DeviceCode','Interactive','AccessToken')]
        [string]$Method,
        [ValidateNotNullOrEmpty()][string]$TenantId,
        [ValidateNotNullOrEmpty()][string]$ClientId,
        [securestring]$AccessToken,
        [ValidateNotNullOrEmpty()][string]$Environment = 'Global',
        [ValidateRange(1, 600)][double]$ClientTimeout = 100
    )

    if ([string]::IsNullOrWhiteSpace($AssociationId) -eq [string]::IsNullOrWhiteSpace($SerialNumber)) { throw 'Specify exactly one of -AssociationId or -SerialNumber.' }

    $allowedByMethod = @{
        DeviceCode=@('TenantId','ClientId'); Interactive=@('TenantId','ClientId');
        AccessToken=@('TenantId','AccessToken');

    }
    $methodSpecificParameters = @('TenantId','ClientId','AccessToken')
    $invalidParameters = $methodSpecificParameters | Where-Object { $PSBoundParameters.ContainsKey($_) -and $_ -notin $allowedByMethod[$Method] }
    if ($invalidParameters) { throw "The following parameters are not valid with -Method $Method`: $($invalidParameters -join ', ')." }

    switch ($Method) {
        'AccessToken' { if (-not $PSBoundParameters.ContainsKey('AccessToken')) { throw '-AccessToken is required for -Method AccessToken.' } }

    }

    $baseUri='https://graph.microsoft.com/beta'; $nativeAccessToken=$null; $sdkMode=$false
    if($Method -in @('DeviceCode','AccessToken')){
        if($Environment -ne 'Global'){throw 'Native Device Association lookup currently supports the Global Microsoft cloud only.'}
        switch($Method){
            'DeviceCode'{$tokenParameters=@{};if($TenantId){$tokenParameters.TenantId=$TenantId};if($ClientId){$tokenParameters.ClientId=$ClientId};Write-Information -InformationAction Continue -MessageData 'Using native OAuth device-code authentication for Device Association lookup.';$token=Get-WindowsDeviceLinkDeviceCodeToken @tokenParameters;$nativeAccessToken=$token.AccessToken;$TenantId=$token.TenantId}

            'AccessToken'{$credential=New-Object System.Management.Automation.PSCredential('token',$AccessToken);$nativeAccessToken=$credential.GetNetworkCredential().Password;if(-not $TenantId){$TenantId=Resolve-WindowsDeviceLinkAccessTokenTenantId -AccessToken $nativeAccessToken};$credential=$null}
        }
    } else {
        $connectParams=@{Environment=$Environment;ClientTimeout=$ClientTimeout}
        switch($Method){
            'Interactive'{if($TenantId){$connectParams.TenantId=$TenantId};if($ClientId){$connectParams.ClientId=$ClientId}}

        }
        Connect-WindowsDeviceLink @connectParams|Out-Null;$sdkMode=$true;$context=Get-MgContext;if($context -and $context.TenantId){$TenantId=$context.TenantId}
    }

    try {
        $graphReadParameters=@{};if($sdkMode){$graphReadParameters.SdkMode=$true}else{$graphReadParameters.AccessToken=$nativeAccessToken}

        if($AssociationId){
            $uri="$baseUri/deviceManagement/tenantAssociatedDevices/$AssociationId"
            $record=Invoke-WindowsDeviceLinkGraphGet -Uri $uri @graphReadParameters
            return ConvertTo-WindowsDeviceLinkAssociationResult -Record $record -TenantId $TenantId -ExpectedAssociationId $AssociationId
        }

        $escapedSerial=$SerialNumber.Replace("'","''")
        $filter=[uri]::EscapeDataString("serialNumber eq '$escapedSerial'")
        $uri="$baseUri/deviceManagement/tenantAssociatedDevices?`$filter=$filter"
        $filteredRecords=@(Get-WindowsDeviceLinkGraphCollection -Uri $uri @graphReadParameters)
        $records=@(Resolve-WindowsDeviceLinkSerialAssociationRecords -Records $filteredRecords -SerialNumber $SerialNumber)

        if($records.Count -eq 0){
            Write-Information -InformationAction Continue -MessageData 'Filtered serial-number lookup returned no exact match; retrying with client-side matching.'
            $allRecords=@(Get-WindowsDeviceLinkGraphCollection -Uri "$baseUri/deviceManagement/tenantAssociatedDevices" @graphReadParameters)
            $records=@(Resolve-WindowsDeviceLinkSerialAssociationRecords -Records $allRecords -SerialNumber $SerialNumber -RequireCompleteSerialCoverage)
        }

        if($records.Count -eq 0){Write-Information -InformationAction Continue -MessageData 'No Device Association record was found.';return}

        ConvertTo-WindowsDeviceLinkAssociationResult -Record $records[0] -TenantId $TenantId -ExpectedSerialNumber $SerialNumber
    } catch {
        $statusCode=$null;try{$statusCode=[int]$_.Exception.Response.StatusCode}catch{}
        if($null -eq $statusCode -and $_.Exception.Message -match '(?<!\d)404(?!\d)'){$statusCode=404}
        if($AssociationId -and $statusCode -eq 404){Write-Information -InformationAction Continue -MessageData 'No Device Association record was found.';return}
        throw
    } finally {$nativeAccessToken=$null}
}
