Write-Host "Setting Global Variables to be used for API calls.." -ForegroundColor Yellow
Write-Host
	
$global:AppId = "YOUR-CSP-APPID"
$global:AppSecret = "YOUR-CSP-APPSECRET"
$global:PartnerTenantid = 'YOUR-CSP-TENANTID'
$global:consentscope = 'https://api.partnercenter.microsoft.com/user_impersonation'
# This is the display name of the App Registration you created on the CSP tenant's Azure AD. Change it to whatever you call it.
$global:AppDisplayName = 'MgGraphMultiTenant'

Write-Host "The following global variables have been set:"
Write-Host "Clarity MgGraph Enterprise App ID:" -ForegroundColor Yellow
Write-Host $global:AppId -ForegroundColor DarkGreen
Write-Host "Clarity MgGraph Enterprise App Secret:" -ForegroundColor Yellow
Write-Host $global:AppSecret -ForegroundColor DarkGreen
Write-Host "Clarity Partner Tenant ID:" -ForegroundColor Yellow
Write-Host $global:PartnerTenantid -ForegroundColor DarkGreen
Write-Host "Consent Scope:" -ForegroundColor Yellow
Write-Host $global:consentscope -ForegroundColor DarkGreen
write-host

function Init-CSPMgGraphModules
{
	Process {
		Write-Host "Checking that $_ module is installed..." -ForegroundColor Yellow
		
		$modInstalled = Get-InstalledModule -Name $_
		
		if (!($modInstalled))
		{
			Write-Host "$_ module not installed. Installing now..." -ForegroundColor Yellow
			Install-Module -Name $_ -Scope CurrentUser -Confirm
			Write-Host "$_ module installed" -ForegroundColor DarkGreen
			Write-Host
		}
		
		Write-Host "Importing $_ module now..." -ForegroundColor Yellow
		Write-Host
		#Importing Modules
		
		if (Get-Module -Name $_)
		{
			Write-Host "$_ module is already imported!" -ForegroundColor DarkGreen
		}
		else
		{
			Try
			{
				Import-Module $_ -ErrorAction Stop
			}
			Catch
			{
				$message = $_
				Write-Warning "$_ could not be imported: $message"
			}
		}
	}
}
Function CSPConsent4Customer
{
     Param
    (
         [Parameter(Mandatory=$true, Position=0)]
         [string] $AccessToken,
		 [Parameter(Mandatory=$true, Position=1)]
         [string] $CustomerTenantId,
         [Parameter(Mandatory=$true, Position=2)]
         [string] $CSPApplicationId,
		 [Parameter(Mandatory=$true, Position=3)]
         [string] $CSPApplicationDisplayName
    )
	# Connect using PartnerAccessToken token
	$PartnerCenter = Connect-PartnerCenter -AccessToken $AccessToken

	$GraphEnterpriseApplicationId = '00000003-0000-0000-c000-000000000000' #list of application Ids is on https://learn.microsoft.com/en-us/troubleshoot/azure/active-directory/verify-first-party-apps-sign-in
	$GraphScopes = "Directory.Read.All,Directory.AccessAsUser.All,User.Read,Application.ReadWrite.All,AppRoleAssignment.ReadWrite.All,AuthenticationContext.ReadWrite.All,BillingConfiguration.ReadWrite.All,BitlockerKey.ReadBasic.All,CrossTenantInformation.ReadBasic.All,DelegatedAdminRelationship.ReadWrite.All,Device.ReadWrite.All,DeviceManagementApps.ReadWrite.All,DeviceManagementConfiguration.ReadWrite.All,DeviceManagementManagedDevices.ReadWrite.All,DeviceManagementRBAC.ReadWrite.All,DeviceManagementServiceConfig.ReadWrite.All,Directory.ReadWrite.All,Domain.ReadWrite.All,Group.ReadWrite.All,GroupMember.ReadWrite.All,MailboxSettings.ReadWrite,ManagedTenants.ReadWrite.All,Organization.ReadWrite.All,Policy.ReadWrite.ApplicationConfiguration,Policy.ReadWrite.ConsentRequest,Policy.ReadWrite.CrossTenantAccess,Policy.ReadWrite.DeviceConfiguration,Policy.ReadWrite.PermissionGrant,Policy.ReadWrite.SecurityDefaults,ProgramControl.ReadWrite.All,ServicePrincipalEndpoint.ReadWrite.All,User.ReadWrite.All"
	
	#Grants needed
	$MSGraphgrant = New-Object -TypeName Microsoft.Store.PartnerCenter.Models.ApplicationConsents.ApplicationGrant
	$MSgraphgrant.EnterpriseApplicationId = $GraphEnterpriseApplicationId
	$MSGraphgrant.Scope = $GraphScopes
	
	$ARMEnterpriseApplicationId = '797f4846-ba00-4fd7-ba43-dac1f8f63013' #list of application Ids is on https://learn.microsoft.com/en-us/troubleshoot/azure/active-directory/verify-first-party-apps-sign-in
	$ARMScopes = "user_impersonation"
	$ARMgrant = New-Object -TypeName Microsoft.Store.PartnerCenter.Models.ApplicationConsents.ApplicationGrant
	$ARMgrant.EnterpriseApplicationId = $ARMEnterpriseApplicationId
	$ARMgrant.Scope = $ARMScopes
	
	New-PartnerCustomerApplicationConsent -ApplicationGrants @($ARMgrant, $MSGraphgrant) -CustomerId $CustomerTenantId -ApplicationId $CSPApplicationId -DisplayName $CSPApplicationDisplayName
}

Function Select-Customer {
    if (Get-MgContext) {
        Disconnect-MgGraph 
    }
    Connect-MgGraph -Scopes "Directory.Read.All"

    #Get list of all customer tenants. Their tenant ID is the column named CustomerId
    $Customers = Get-MgContract -All
    $arrayCount = 0
    $CustomerArray = @()
    $CustomerNameArray = @()

    #Loop through array to show a list of all Customers with a number preceding them.
    foreach ($Customer in $Customers) {
        $CustomerArray += $Customer.CustomerId
        $CustomerNameArray += $Customer.DisplayName
        Write-Host $arrayCount ": " $Customer.DisplayName -ForegroundColor Yellow
        $arrayCount++
    }
    Write-Host ""
    $CustomerSelect = Read-Host "Please type the number of the customer you want to connect to"
    Write-Host ""
    Write-Host "You  have selected $($CustomerNameArray[$CustomerSelect]) as the customer of choice." -ForegroundColor Green
    Write-Host
    $CustomerTenantID = $CustomerArray[$CustomerSelect]
    Write-Host "Selected customer has the following Tenant ID:" -ForegroundColor Yellow
    Write-Host
    Write-Host $CustomerTenantID -ForegroundColor Green
    Write-Host
    Write-Host "The following only applies to brand new tenants..." -ForegroundColor Yellow
    $ConsentSelect = Read-Host "Do you need to grant the Microsoft Graph application consent to a new Customer Tenant? Y/N (If No then the script will connect to Graph to the customer tenant using your CSP credentials)"
    switch ($ConsentSelect){
        "Y" {
            
            Consent-PartnerApplication -CustomerTenantId $CustomerTenantID
        }
        "N" {
            $CustomerAccessToken = Get-AuthenticationTokens -TokenType Customer -customertenantid $CustomerTenantID
            Write-Host "Customer Access Token Acquired. Connecting to MgGraph using CSP credentials on the tenant $($CustomerNameArray[$CustomerSelect])"
            Connect-MgGraph -AccessToken $CustomerAccessToken 
        }
    }
}
Function Get-AuthenticationTokens {
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$TokenType,
        [string]$customertenantid
        )

    
        $AppCredential = (New-Object System.Management.Automation.PSCredential ($global:AppId, (ConvertTo-SecureString $global:AppSecret -AsPlainText -Force)))

        switch ($TokenType) {
            "Partner" {
     
                # Get PartnerAccessToken token – this is common for all customers
            
                $PartnerAccessToken = New-PartnerAccessToken -serviceprincipal -ApplicationId $global:AppId -Credential $global:AppCredential -Scopes $global:consentscope -tenant $global:PartnerTenantid -useauthorizationcode
                return $PartnerAccessToken.AccessToken
            
            }
            "Customer" {
                $PartnerAccessToken = New-PartnerAccessToken -serviceprincipal -ApplicationId $global:AppId -Credential $AppCredential -Scopes $global:consentscope -tenant $global:PartnerTenantid -useauthorizationcode
                $customerToken = New-PartnerAccessToken -ApplicationId $global:AppId -Credential AppCredential  -Scopes 'https://graph.microsoft.com/.default' -ServicePrincipal -Tenant $customertenantid -RefreshToken $PartnerAccessToken.RefreshToken
                return $customerToken.AccessToken

            }
        }

}

Function Consent-PartnerApplication {
    param(
    [Parameter(Mandatory=$true, Position=0)]
    [string] $CustomerTenantId)
    $PartnerAccessToken = Get-AuthenticationTokens -TokenType Partner
    CSPConsent4Customer -AccessToken $PartnerAccessToken -CustomerTenantId $customertenantid -CSPApplicationId $global:AppId -CSPApplicationDisplayName $global:AppDisplayName
}
  
$ModulesArray = @('PartnerCenter', 'AzureAD', 'Microsoft.Graph', 'Microsoft.Graph.Intune')
$ModulesArray | Init-CSPMgGraphModules
Select-Customer
