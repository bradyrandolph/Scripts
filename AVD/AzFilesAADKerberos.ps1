# Create Azure Storage Account
# Set Variables
$resourceGroupName = "AZFilesKerberos"
$storageAccountName = "safilesaddkerberos"
$region = "eastus2"
$shareName = "fslogix"

Connect-AzAccount
New-AzResourceGroup -Name $resourceGroupName -Location $region
$storAcct = New-AzStorageAccount `
    -ResourceGroupName $resourceGroupName `
    -Name $storageAccountName `
    -SkuName Premium_LRS `
    -Location $region `
    -Kind FileStorage

    Set-AzStorageAccount `
    -ResourceGroupName $resourceGroupName `
    -Name $storageAccountName `
    -EnableLargeFileShare

New-AzRmStorageShare `
    -ResourceGroupName $resourceGroupName `
    -StorageAccountName $storageAccountName `
    -Name $shareName `
    -QuotaGiB 1024 | `
Out-Null

Install-Module -Name Az.Storage
Install-Module -Name AzureAD
Install-Module -Name Az.Accounts


$Subscription =  $(Get-AzContext).Subscription.Id;
$ApiVersion = '2021-04-01'

$Uri = ('https://management.azure.com/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Storage/storageAccounts/{2}?api-version={3}' -f $Subscription, $ResourceGroupName, $StorageAccountName, $ApiVersion);

$json = 
   @{properties=@{azureFilesIdentityBasedAuthentication=@{directoryServiceOptions="AADKERB"}}};
$json = $json | ConvertTo-Json -Depth 99

$token = $(Get-AzAccessToken).Token
$headers = @{ Authorization="Bearer $token" }

try {
    Invoke-RestMethod -Uri $Uri -ContentType 'application/json' -Method PATCH -Headers $Headers -Body $json;
} catch {
    Write-Host $_.Exception.ToString()
    Write-Error -Message "Caught exception setting Storage Account directoryServiceOptions=AADKERB: $_" -ErrorAction Stop
}

New-AzStorageAccountKey -ResourceGroupName $resourceGroupName -Name $storageAccountName -KeyName kerb1 -ErrorAction Stop

$kerbKey1 = Get-AzStorageAccountKey -ResourceGroupName $resourceGroupName -Name $storageAccountName -ListKerbKey | Where-Object { $_.KeyName -like "kerb1" }
$aadPasswordBuffer = [System.Linq.Enumerable]::Take([System.Convert]::FromBase64String($kerbKey1.Value), 32);
$password = "kk:" + [System.Convert]::ToBase64String($aadPasswordBuffer);

Connect-AzureAD
$azureAdTenantDetail = Get-AzureADTenantDetail;
$azureAdTenantId = $azureAdTenantDetail.ObjectId
$azureAdPrimaryDomain = ($azureAdTenantDetail.VerifiedDomains | Where-Object {$_._Default -eq $true}).Name

$servicePrincipalNames = New-Object string[] 3
$servicePrincipalNames[0] = 'HTTP/{0}.file.core.windows.net' -f $storageAccountName
$servicePrincipalNames[1] = 'CIFS/{0}.file.core.windows.net' -f $storageAccountName
$servicePrincipalNames[2] = 'HOST/{0}.file.core.windows.net' -f $storageAccountName

$application = New-AzureADApplication -DisplayName $storageAccountName -IdentifierUris $servicePrincipalNames -GroupMembershipClaims "All";

$servicePrincipal = New-AzureADServicePrincipal -AccountEnabled $true -AppId $application.AppId -ServicePrincipalType "Application";

$Token = ([Microsoft.Open.Azure.AD.CommonLibrary.AzureSession]::AccessTokens['AccessToken']).AccessToken
$apiVersion = '1.6'
$Uri = ('https://graph.windows.net/{0}/{1}/{2}?api-version={3}' -f $azureAdPrimaryDomain, 'servicePrincipals', $servicePrincipal.ObjectId, $apiVersion)
$json = @'
{
  "passwordCredentials": [
  {
    "customKeyIdentifier": null,
    "endDate": "<STORAGEACCOUNTENDDATE>",
    "value": "<STORAGEACCOUNTPASSWORD>",
    "startDate": "<STORAGEACCOUNTSTARTDATE>"
  }]
}
'@
$now = [DateTime]::UtcNow
$json = $json -replace "<STORAGEACCOUNTSTARTDATE>", $now.AddDays(-1).ToString("s")
  $json = $json -replace "<STORAGEACCOUNTENDDATE>", $now.AddMonths(12).ToString("s")
$json = $json -replace "<STORAGEACCOUNTPASSWORD>", $password
$Headers = @{'authorization' = "Bearer $($Token)"}
try {
  Invoke-RestMethod -Uri $Uri -ContentType 'application/json' -Method Patch -Headers $Headers -Body $json 
  Write-Host "Success: Password is set for $storageAccountName"
} catch {
  Write-Host $_.Exception.ToString()
  Write-Host "StatusCode: " $_.Exception.Response.StatusCode.value
  Write-Host "StatusDescription: " $_.Exception.Response.StatusDescription
}

# I had to run the prior from Azure CLI because get-azaccesstoken wasn't working
# Here is how you apply ACL's to Azure Files w/o Active Directory integration.

function Set-StorageAccountAadKerberosADProperties {
  [CmdletBinding()]
  param(
      [Parameter(Mandatory=$true, Position=0)]
      [string]$ResourceGroupName,

      [Parameter(Mandatory=$true, Position=1)]
      [string]$StorageAccountName,

      [Parameter(Mandatory=$false, Position=2)]
      [string]$Domain
  )  

  $AzContext = Get-AzContext;
  if ($null -eq $AzContext) {
      Write-Error "No Azure context found.  Please run Connect-AzAccount and then retry." -ErrorAction Stop;
  }

  $AdModule = Get-Module ActiveDirectory;
   if ($null -eq $AdModule) {
      Write-Error "Please install and/or import the ActiveDirectory PowerShell module." -ErrorAction Stop;
  }	

  if ([System.String]::IsNullOrEmpty($Domain)) {
      $domainInformation = Get-ADDomain
      $Domain = $domainInformation.DnsRoot
  } else {
      $domainInformation = Get-ADDomain -Server $Domain
  }

  $domainGuid = $domainInformation.ObjectGUID.ToString()
  $domainName = $domainInformation.DnsRoot
  $domainSid = $domainInformation.DomainSID.Value
  $forestName = $domainInformation.Forest
  $netBiosDomainName = $domainInformation.DnsRoot
  $azureStorageSid = $domainSid + "-123454321";

  Write-Verbose "Setting AD properties on $StorageAccountName in $ResourceGroupName : `
      EnableActiveDirectoryDomainServicesForFile=$true, ActiveDirectoryDomainName=$domainName, `
      ActiveDirectoryNetBiosDomainName=$netBiosDomainName, ActiveDirectoryForestName=$($domainInformation.Forest) `
      ActiveDirectoryDomainGuid=$domainGuid, ActiveDirectoryDomainSid=$domainSid, `
      ActiveDirectoryAzureStorageSid=$azureStorageSid"

  $Subscription =  $AzContext.Subscription.Id;
  $ApiVersion = '2021-04-01'

  $Uri = ('https://management.azure.com/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Storage/storageAccounts/{2}?api-version={3}' `
      -f $Subscription, $ResourceGroupName, $StorageAccountName, $ApiVersion);

  $json=
      @{
          properties=
              @{azureFilesIdentityBasedAuthentication=
                  @{directoryServiceOptions="AADKERB";
                      activeDirectoryProperties=@{domainName="$($domainName)";
                                                  netBiosDomainName="$($netBiosDomainName)";
                                                  forestName="$($forestName)";
                                                  domainGuid="$($domainGuid)";
                                                  domainSid="$($domainSid)";
                                                  azureStorageSid="$($azureStorageSid)"}
                                                  }
                  }
      };  

  $json = $json | ConvertTo-Json -Depth 99

  $token = $(Get-AzAccessToken).Token
  $headers = @{ Authorization="Bearer $token" }

  try {
      Invoke-RestMethod -Uri $Uri -ContentType 'application/json' -Method PATCH -Headers $Headers -Body $json
  } catch {
      Write-Host $_.Exception.ToString()
      Write-Host "Error setting Storage Account AD properties.  StatusCode:" $_.Exception.Response.StatusCode.value__ 
      Write-Host "Error setting Storage Account AD properties.  StatusDescription:" $_.Exception.Response.StatusDescription
      Write-Error -Message "Caught exception setting Storage Account AD properties: $_" -ErrorAction Stop
  }
}

# Import ActiveDirectory Module import-module ActiveDirectory
Set-StorageAccountAadKerberosADProperties -ResourceGroupName $resourceGroupName -StorageAccountName $storageAccountName

# Run this command on each AVD Host for roaming profiles.
reg add HKLM\Software\Policies\Microsoft\AzureADAccount /v LoadCredKeyFromProfile /t REG_DWORD /d 1

#map drive to test
net use * \\safilesaddkerberos.file.core.windows.net\fslogix