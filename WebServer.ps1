Add-Type -AssemblyName System.Web

function ResetPassword($query)
{
    $pName = GetFieldFromQuery $query 'pName'
    $id = GetIdFromQuery $query 
    Set-MsolUserPassword -UserPrincipalName $pName -TenantId $id -NewPassword 'Pa$$word123'
    return '{}'
}

function SetLicense($query)
{
    $id = GetIdFromQuery $query 
    $pName = GetFieldFromQuery $query 'pName'
    $sku = GetFieldFromQuery $query 'sku'
    $op = GetFieldFromQuery $query 'op'
   
    if ($op -eq "0") 
    {
        Set-MsolUserLicense -UserPrincipalName $pName  -TenantID $id  -RemoveLicenses $sku
    }
    else
    { 
        Set-MsolUserLicense -UserPrincipalName $pName  -TenantID $id  -AddLicenses $sku
    }
    return '{}'
}

function GetUserLicenses($query) 
{
    $id = GetIdFromQuery $query 
    $pName = GetFieldFromQuery $query 'pName'
             
    $json = Get-MsolUser -UserPrincipalName $pName -TenantID $id | ConvertTo-Json
   	return  $json
}

function GetUsers($query)
{
    $id = GetIdFromQuery $query
    $json = Get-MsolUser -TenantID $id |  ConvertTo-Json
   	return $json
}

function GetAccountSku( $query)
{
    $id = GetIdFromQuery $query
    $json = Get-MsolAccountSku -TenantID $id | ConvertTo-Json
    return $json
}

function GetTenants()
{
    $json =  Get-MsolPartnerContract -All | ConvertTo-Json   
	return $json
}

function StartHttpServer 
{
	$url = 'http://localhost:8080/'
	$listener = New-Object System.Net.HttpListener
	$listener.Prefixes.Add($url)
	$listener.Start()

	Write-Host "Listening at $url..."

	while ($listener.IsListening)
	{
		$context = $listener.GetContext()
		$requestUrl = $context.Request.Url

		$response = $context.Response

		Write-Host ''
		Write-Host "> $requestUrl"


		$localPath = $requestUrl.LocalPath
	    Write-Host ''
		Write-Host "> $localPath"

		
		if ($localPath -eq '/kill')
		{
			$response.Close()
			$listener.Stop()
			break
		}

        $val = '';

        $Error.Clear();
        
        if ($localPath -eq '/tenants')
        {
            $val = GetTenants $response 
        }
        elseif ($localPath -eq '/users') 
        {
            $val =  GetUsers $requestUrl.Query   
        }
        elseif ($localPath -eq '/userLicenses')
        {
            $val = GetUserLicenses $requestUrl.Query
        }
        elseif ($localPath -eq '/skus') 
        {
            $val =  GetAccountSku $requestUrl.Query   
        }
        elseif ($localPath -eq '/setLicense')
        {
            $val = SetLicense  $requestUrl.Query   
        }
        elseif ($localPath -eq '/resetPassword')
        {
            $val = ResetPassword  $requestUrl.Query   
        }
        else 
        {
            $response.StatusCode = 404
        }

        if ($Error.Count -gt 0)
        {
            $val = '{"error": "' +$Error[0]  + '"}'
        }

        $buffer = [System.Text.Encoding]::UTF8.GetBytes($val)
        
        $response.Headers.Add('Access-Control-Allow-Origin', '*');
        $response.ContentLength64 = $buffer.Length
	    $response.OutputStream.Write($buffer, 0, $buffer.Length)
        $response.Close()
		
        $responseStatus = $response.StatusCode
		Write-Host "< $responseStatus"
	}
}


function GetIdFromQuery($query)
{
    return GetFieldFromQuery $query 'id'
}

function GetFieldFromQuery($query, $field)
{
    $fields = [System.Web.HttpUtility]::ParseQueryString($query)
    Write-Host "query=$query"
    Write-host "field=$field"
    $val = $fields.Get($field);
    Write-Host "val=$val"
    return $val;
}


function ConnectMsol()
{
    $username = "jack@hartogjacobs.com"
    $password = Get-Content 'C:\Users\JackChen\source\repos\PSWebserver\mysecurestring.txt' | ConvertTo-SecureString

    $cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $username, $password
    Connect-MsolService -Credential $cred

}

ConnectMsol
StartHttpServer