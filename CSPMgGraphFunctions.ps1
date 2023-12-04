Write-Host "Setting Global Variables to be used for API calls.." -ForegroundColor Yellow
Write-Host
	
$global:AppId = "YOUR-CSP-APPID"
$global:AppSecret = "YOUR-CSP-APPSECRET"
$global:PartnerTenantid = 'YOUR-CSP-TENANTID'
$global:consentscope = 'https://api.partnercenter.microsoft.com/user_impersonation'
# This is the display name of the App Registration you created on the CSP tenant's Azure AD. Change it to whatever you call it.
$global:AppDisplayName = 'MgGraphMultiTenant'

Write-Host "The following global variables have been set:"
Write-Host "CSP MgGraph Enterprise App ID:" -ForegroundColor Yellow
Write-Host $global:AppId -ForegroundColor DarkGreen
Write-Host "CSP MgGraph Enterprise App Secret:" -ForegroundColor Yellow
Write-Host $global:AppSecret -ForegroundColor DarkGreen
Write-Host "CSP Partner Tenant ID:" -ForegroundColor Yellow
Write-Host $global:PartnerTenantid -ForegroundColor DarkGreen
Write-Host "Consent Scope:" -ForegroundColor Yellow
Write-Host $global:consentscope -ForegroundColor DarkGreen
write-host

function Init-CSPMgGraphModules {
<#
.SYNOPSIS
    This function checks if a specified module is installed, installs it if it is not, removes older versions if there are any, checks for updates, and imports the module.

.DESCRIPTION
    This function checks if a specified module is installed, installs it if it is not, removes older versions if there are any, checks for updates, and imports the module. It also provides feedback on the status of each step.

.PARAMETER None
    This function does not accept any parameters.

.EXAMPLE
    Init-CSPMgGraphModules

.NOTES
    Author: Marcus Tedde
    Last Edit: 08/11/2023
#>
    Process {
        Write-Ghost -Text "`nChecking that $_ module is installed..." -Type info
        try {
            $modInstalled = Get-InstalledModule -Name $_

            if (!($modInstalled)) {
                Write-Ghost -Text "$_ module is not installed. Installing now..." -ForegroundColor DarkRed
                if (-not (Get-PackageProvider -Name NuGet)) {
                    Install-PackageProvider NuGet -Force
                }
                Set-PSRepository PSGallery -InstallationPolicy Trusted
                Install-Module -Name $_ -Scope CurrentUser -ErrorAction Stop
                Write-Ghost -Text "$_ module installed" -Type success
            }
            else {
                Write-Ghost -Text "$_ module is already installed." -Type success
                Write-Ghost -Text "Checking for duplicate versions of $_ module..." -Type info
                $modVersions = Get-InstalledModule -Name $_ -AllVersions
                if ($modVersions.Count -gt 1) {
                    Write-Ghost -Text "There are $($modVersions.Count) versions of $_ module installed. Removing older versions..." -Type info
                    $modVersions | Sort-Object -Property Version -Descending | Select-Object -Skip 1 | Uninstall-Module -Force
                    Write-Ghost -Text "Older versions of $_ module removed." -Type success
                }
                else {
                    Write-Ghost -Text "There is only one version of $_ module installed." -Type success
                }
                Write-Ghost -Text "Checking for updates to $_ module..." -Type info
                $modUpdates = Find-Module -Name $_ -AllVersions | Where-Object { $_.Version -gt $modInstalled.Version }
                if ($modUpdates) {
                    Write-Ghost -Text "There are $($modUpdates.Count) updates to $_ module available. Updating now..." -Type info
                    $modUpdates | Install-Module -Force
                    Write-Ghost -Text "$_ module updated." -Type success
                }
                else {
                    Write-Ghost -Text "There are no updates to $_ module available." -Type success
                }
            }
            
            Write-Ghost -Text "Importing $_ module now..." -Type info
            
            if (!(Get-Module -Name $_)) {
                Import-Module $_
                Write-Ghost -Text "$_ module has been successfully imported!" -Type success
            }
            else {
                Write-Ghost -Text "$_ module is already imported!" -Type success
            }
        }
        catch {
            Write-Warning "$_ module could not be processed: $_.Exception.Message"
        }
    }
}

Function CSPConsent4Customer {
<#
.SYNOPSIS
    Grants consent to the specified customer tenant for the specified CSP application.

.DESCRIPTION
    This function grants consent to the specified customer tenant for the specified CSP application by creating application grants for Microsoft Graph and Azure Resource Manager (ARM) APIs.

.PARAMETER AccessToken
    The access token to connect to Partner Center.

.PARAMETER CustomerTenantId
    The ID of the customer tenant to grant consent to.

.PARAMETER CSPApplicationId
    The ID of the CSP application to grant consent for.

.PARAMETER CSPApplicationDisplayName
    The display name of the CSP application to grant consent for.

.EXAMPLE
    CSPConsent4Customer -AccessToken $AccessToken -CustomerTenantId $CustomerTenantId -CSPApplicationId $CSPApplicationId -CSPApplicationDisplayName $CSPApplicationDisplayName

    Grants consent to the specified customer tenant for the specified CSP application.

.NOTES
    Author: Marcus Tedde
    Last Edit: 08/11/2023
#>
    Param
    (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$AccessToken,
        [Parameter(Mandatory = $true, Position = 1)]
        [string]$CustomerTenantId,
        [Parameter(Mandatory = $true, Position = 2)]
        [string]$CSPApplicationId,
        [Parameter(Mandatory = $true, Position = 3)]
        [string]$CSPApplicationDisplayName
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

function Select-Customer {
<#
.SYNOPSIS
    This function allows the user to select a customer and connect to their M365 tenant and Azure AD.
.DESCRIPTION
    This function retrieves a list of customers and their corresponding Tenant IDs, prompts the user to select a customer, and then connects to the selected customer's M365 tenant and Azure AD. It also retrieves an access token for the selected customer's tenant and sets the authentication headers for the Microsoft Graph API.
.PARAMETER None
    This function does not accept any parameters.
.EXAMPLE
    PS C:\> Select-Customer
    This example shows how to use the Select-Customer function to select a customer and connect to their M365 tenant and Azure AD.
.INPUTS
    None. You cannot pipe objects to Select-Customer.
.OUTPUTS
    Returns an access token for the selected customer's tenant.
.NOTES
    Author: Marcus Tedde
    Last Edit: 08/11/2023
#>
    try {
        if (Get-MgContext) {
            Disconnect-MgGraph
        }
        Connect-MgGraph -Scopes "Directory.Read.All"

        $Customers = Get-MgBetaContract -All
        $CustomerArray, $CustomerNameArray = @(), @()

        $Customers | ForEach-Object -Begin { $count = 0 } -Process {
            $CustomerArray += $_.CustomerId
            $CustomerNameArray += $_.DisplayName
            Write-Ghost -Text "`n$count : $($_.DisplayName)" -Type info
            $count++
        }

        $CustomerSelect = Read-Host "`nPlease type the number of the customer you want to connect to"
        $script:CustomerTenantID = $CustomerArray[$CustomerSelect]
        $script:CustomerName = $CustomerNameArray[$CustomerSelect]

        Write-Ghost -Text "You have selected $($script:CustomerName) as the customer of choice." -Type success
        Write-Ghost -Text "Selected customer has the following Tenant ID:" -Type info
        Write-Ghost -Text $script:CustomerTenantID -Type success
        Try {
            # Getting access token for the customer tenant
            Write-Ghost -Text "`nRetrieving access token for $($script:CustomerName)'s tenant..." -Type info

            $AccessToken = Get-AuthenticationTokens -TokenType Customer -CSPAppId $script:AppId -CSPAppSecret $script:AppSecret -PartnerTenantid $script:PartnerTenantid -CustomerTenantId $script:CustomerTenantID
            $script:secureAccessToken = ConvertTo-SecureString -String $AccessToken.AccessToken -AsPlainText -Force
            Write-Ghost -Text "Successfully retrieved access token for $($script:CustomerName)'s tenant." -Type success
            
            Write-Ghost -Text "`nSetting Auth Headers for $($script:CustomerName)'s tenant..." -Type info
            Set-AuthHeaders -AccessToken $AccessToken.AccessToken -ExpiresOn $AccessToken.ExpiresOn
            Write-Ghost -Text "Successfully set Auth Headers for $($script:CustomerName)'s tenant." -Type success

            # Connecting to the customer tenant using the access token retrieved in the previous step
            Write-Ghost -Text "`nConnecting to $($script:CustomerName)'s M365 tenant through Microsoft Graph API..." -Type info

            Connect-MgGraph -AccessToken $script:secureAccessToken | Out-Null

            Write-Ghost -Text "Successfully connected to $($script:CustomerName)'s M365 tenant through Microsoft Graph API." -Type success
            Write-Ghost -Text "Connectection details:" -Type info

            Get-MgContext | Format-List -Property *

            Write-Ghost -Text "`nConnecting to $($script:CustomerName)'s Azure AD..." -Type info
            Write-Ghost -Text "Please use your CSP credentials. e.g firstname.lastname@contoso.com" -Type info
            try {
                Connect-AzureAD -TenantId $script:CustomerTenantID -ErrorAction Stop
                Write-Ghost -Text "Successfully connected to $($script:CustomerName)'s Azure AD." -Type success
            }
            catch {
                Write-Ghost -Text "`nError connecting to $($script:CustomerName)'s Azure AD: " -Type error
                Write-Ghost -Text "Exiting script..." -Type error
                exit
            }

            return $AccessToken
        }
        catch {
            Write-Warning "`nError: Could not connect to customer tenant"
            Write-Warning "The application has not been consented to on customer tenant.`nAttempting to consent the Azure AD App on $($script:CustomerName)'s tenant."
            try {
                Write-Ghost -Text "`nConsenting Azure AD App on $($script:CustomerName)'s tenant..." -Type info

                Consent-PartnerApplication

                Write-Ghost -Text "Successfully consented Azure AD App on $($script:CustomerName)'s tenant." -Type success
                Write-Ghost -Text "`nAttempting to connect to $($script:CustomerName)'s tenant again..." -Type info
                
                Write-Ghost -Text "Retrieving access token for $($script:CustomerName)'s tenant..."
                $AccessToken = Get-AuthenticationTokens -TokenType Customer -CSPAppId $script:AppId -CSPAppSecret $script:AppSecret -PartnerTenantid $script:PartnerTenantid -CustomerTenantId $script:CustomerTenantID
                $script:secureAccessToken = ConvertTo-SecureString -String $AccessToken.AccessToken -AsPlainText -Force
                Write-Ghost -Text "Successfully retrieved access token for $($script:CustomerName)'s tenant." -Type success

                Write-Ghost -Text "`nSetting Auth Headers for $($script:CustomerName)'s tenant..." -Type info
                Set-AuthHeaders -AccessToken $AccessToken.AccessToken -ExpiresOn $AccessToken.ExpiresOn
                Write-Ghost -Text "Successfully set Auth Headers for $($script:CustomerName)'s tenant." -Type success

                Connect-MgGraph -AccessToken $script:secureAccessToken | Out-Null

                Write-Ghost -Text "Successfully connected to $($script:CustomerName)'s M365 tenant through Microsoft Graph API." -Type success
                Write-Ghost -Text "Connectection details:" -Type info
    
                Get-MgContext | Format-List -Property *
                try {
                    Connect-AzureAD -TenantId $script:CustomerTenantID -ErrorAction Stop
                    Write-Ghost -Text "Successfully connected to $($script:CustomerName)'s Azure AD." -Type success
                }
                catch {
                    Write-Ghost -Text "`nError connecting to $($script:CustomerName)'s Azure AD: " -Type error
                    Write-Ghost -Text "Exiting script..." -Type error
                    exit
                }
                return $AccessToken
            }
            catch {
                Throw "An error occurred: $_.Exception.Message"
            }
        }
    }
    catch {
        Throw "An error occurred: $_.Exception.Message"
    }
}

function Get-AuthenticationTokens {
<#
.SYNOPSIS
    This function retrieves authentication tokens for Partner Center API and Microsoft Graph API.

.DESCRIPTION
    This function retrieves authentication tokens for Partner Center API and Microsoft Graph API based on the provided parameters.
    It uses the New-PartnerAccessToken cmdlet to retrieve the access tokens.

.PARAMETER TokenType
    Specifies the type of token to retrieve. Valid values are "Partner" and "Customer".

.PARAMETER CSPAppId
    Specifies the Application ID of the CSP app.

.PARAMETER CSPAppSecret
    Specifies the Application Secret of the CSP app.

.PARAMETER PartnerTenantid
    Specifies the Tenant ID of the Partner Center account.

.PARAMETER CustomerTenantId
    Specifies the Tenant ID of the customer account. This parameter is required only if TokenType is "Customer".

.EXAMPLE
    PS C:\> Get-AuthenticationTokens -TokenType Partner -CSPAppId "12345678-1234-1234-1234-123456789012" -CSPAppSecret "MyAppSecret" -PartnerTenantid "12345678-1234-1234-1234-123456789012"
    Retrieves Partner Access Token for the specified CSP app.

.EXAMPLE
    PS C:\> Get-AuthenticationTokens -TokenType Customer -CSPAppId "12345678-1234-1234-1234-123456789012" -CSPAppSecret "MyAppSecret" -PartnerTenantid "12345678-1234-1234-1234-123456789012" -CustomerTenantId "87654321-4321-4321-4321-210987654321"
    Retrieves Customer Access Token for the specified CSP app and customer account.

.NOTES
    Author: Marcus Tedde
    Last Edit: 08/11/2023
#>
    param (
        [string]$TokenType,
        [string]$CSPAppId,
        [string]$CSPAppSecret,
        [string]$PartnerTenantid,
        [string]$CustomerTenantId
    )
    
    try {
        $consentscope = 'https://api.partnercenter.microsoft.com/user_impersonation'
        $AppCredential = New-Object System.Management.Automation.PSCredential ($CSPAppId, (ConvertTo-SecureString $CSPAppSecret -AsPlainText -Force))
        
        Write-Ghost -Text "`nRetrieving Partner Access Token..." -Type info
        $PartnerAccessToken = New-PartnerAccessToken -serviceprincipal -ApplicationId $CSPAppId -Credential $AppCredential -Scopes $consentscope -tenant $PartnerTenantid -useauthorizationcode
        Write-Ghost -Text "Partner Access Token has been successfully retrieved." -Type success
        
        if ($TokenType -eq "Customer") {
            Write-Ghost -Text "`nRetrieving Customer Access Token..." -Type info
            $customerToken = New-PartnerAccessToken -ApplicationId $CSPAppId -Credential $AppCredential -Scopes 'https://graph.microsoft.com/.default' -ServicePrincipal -Tenant $CustomerTenantId -RefreshToken $PartnerAccessToken.RefreshToken
            Write-Ghost -Text "Customer Access Token has been successfully retrieved." -Type success
            #return $customerToken.AccessToken
            return $customerToken
        }
        
        #return $PartnerAccessToken.AccessToken
        return $PartnerAccessToken
    }
    catch {
        Write-Warning "`nAn error occurred while retrieving the access tokens:`n $_.Exception.Message"
    }
}

Function Consent-PartnerApplication {
<#
.SYNOPSIS
    Grants consent for a partner application to access customer resources.
.DESCRIPTION
    This function grants consent for a partner application to access customer resources. It first retrieves the partner access token using the Get-AuthenticationTokens function, and then calls the CSPConsent4Customer function to grant consent for the specified CSP application.
.PARAMETER AppDisplayName
    The display name of the CSP application for which consent is being granted.
.EXAMPLE
    Consent-PartnerApplication
    This example grants consent for the MgGraphMultiTenant CSP application to access customer resources.
.NOTES
    Author: Marcus Tedde
    Last Edit: 08/11/2023
#>
    $AppDisplayName = 'MgGraphMultiTenant'
    $PartnerAccessToken = Get-AuthenticationTokens -TokenType Partner -CSPAppId $script:AppId -CSPAppSecret $script:AppSecret -PartnerTenantid $script:PartnerTenantid -CustomerTenantId $script:CustomerTenantId
    CSPConsent4Customer -AccessToken $PartnerAccessToken.AccessToken -CustomerTenantId $script:customertenantid -CSPApplicationId $script:AppId -CSPApplicationDisplayName $AppDisplayName
}

function Set-AuthHeaders {
<#
.SYNOPSIS
Sets the authentication headers for a REST API request.

.DESCRIPTION
This function sets the authentication headers for a REST API request. It takes an access token and an expiration date as parameters and creates a hashtable with the necessary headers.

.PARAMETER AccessToken
The access token to be used for authentication.

.PARAMETER ExpiresOn
The expiration date of the access token.

.EXAMPLE
Set-AuthHeaders -AccessToken $AccessToken.AccessToken -ExpiresOn $AccessToken.ExpiresOn

.NOTES
Author: Marcus Tedde
Last Edit: 08/11/2023
#>
    Param (
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,
        [Parameter(Mandatory = $true)]
        [string]$ExpiresOn
    )
    $script:authHeader = @{
        'Content-Type'  = 'application/json'
        'Authorization' = "Bearer " + $AccessToken
        'ExpiresOn'     = $ExpiresOn
    }
}

function write-ghost {
<#
.SYNOPSIS
Writes text to the console with a colored background and foreground.

.DESCRIPTION
The Write-Ghost function writes text to the console with a colored background and foreground. The function takes two parameters: Text (mandatory) and Type (optional). The Type parameter specifies the color of the background and foreground. If the Type parameter is not specified, the function writes the text with the default console colors.

.PARAMETER Text
Specifies the text to write to the console.

.PARAMETER Type
Specifies the color of the background and foreground. The valid values are "info", "warning", "error", and "success". If the Type parameter is not specified, the function writes the text with the default console colors.

.EXAMPLE
Write-Ghost -Text "This is an informational message." -Type "info"

This example writes the text "This is an informational message." to the console with a cyan background and black foreground.

.NOTES
Author: Marcus Tedde
Date: 08/11/2023
#>
    param (
        [Parameter(Mandatory = $true)]
        [string]$Text,
        [Parameter(Mandatory = $false)]
        [ValidateSet("info", "warning", "error", "success")]
        [string]$Type
    )
    # Check if the current BG and FG Colour variables are not set and call the function if needed
    if ($script:OriginalFGColour -isnot [System.Management.Automation.PSCustomObject] -or $script:OriginalBGColour -isnot [System.Management.Automation.PSCustomObject]) {
    Get-TerminalColour
    }

    # switch statement to set the background and foreground colors based on the Type parameter
    switch ($Type) {
        "info" {
            Set-TerminalColour -Colour Cyan -Type Background
            Set-TerminalColour -Colour Black -Type Foreground
            Write-Host $Text
            Set-TerminalColour -DefaultColours
        }
        "warning" {
            Set-TerminalColour -Colour Yellow -Type Background
            Set-TerminalColour -Colour Black -Type Foreground
            Write-Host $Text
            Set-TerminalColour -DefaultColours
        }
        "error" {
            Set-TerminalColour -Colour Red -Type Background
            Set-TerminalColour -Colour Black -Type Foreground
            Write-Host $Text
            Set-TerminalColour -DefaultColours
        }
        "success" {
            Set-TerminalColour -Colour Green -Type Background
            Set-TerminalColour -Colour Black -Type Foreground
            Write-Host $Text
            Set-TerminalColour -DefaultColours
        }
        default {
            Set-TerminalColour -DefaultColours
            Write-Host $Text
        }
    }
}

function Get-TerminalColour {
<#
.SYNOPSIS
    Gets the current foreground and background colors of the PowerShell terminal.
.DESCRIPTION
    This function retrieves the current foreground and background colors of the PowerShell terminal and stores them in the script-scoped variables $OriginalFGColour and $OriginalBGColour.
.EXAMPLE
    PS C:\> Get-TerminalColour
    This command retrieves the current foreground and background colors of the PowerShell terminal and stores them in the script-scoped variables $OriginalFGColour and $OriginalBGColour.
.NOTES
    Author: Marcus Tedde
    Last Edit: 08/11/2023
#>
    $script:OriginalFGColour = $Host.UI.RawUI.ForegroundColor
    $script:OriginalBGColour = $Host.UI.RawUI.BackgroundColor
}

function Set-TerminalColour {
<#
.SYNOPSIS
Sets the foreground or background color of the PowerShell console.

.DESCRIPTION
The Set-TerminalColour function sets the foreground or background color of the PowerShell console. It can be used to change the color of the text or the background of the console window.

.PARAMETER Colour
Specifies the color to set. The value must be one of the following: Black, DarkBlue, DarkGreen, DarkCyan, DarkRed, DarkMagenta, DarkYellow, Gray, DarkGray, Blue, Green, Cyan, Red, Magenta, Yellow, White.

.PARAMETER Type
Specifies whether to set the foreground or background color. The value must be one of the following: Foreground, Background.

.PARAMETER DefaultColours
Resets the console colors to their default values.

.EXAMPLE
Set-TerminalColour -Colour Green -Type Foreground
Sets the foreground color of the console to green.

.EXAMPLE
Set-TerminalColour -Colour Yellow -Type Background
Sets the background color of the console to yellow.

.EXAMPLE
Set-TerminalColour -DefaultColours
Resets the console colors to their default values.

.NOTES
Author: Marcus Tedde
Date: 08/11/2023
#>
    param (
        [Parameter(Mandatory = $false)]
        [ValidateSet("Black", "DarkBlue", "DarkGreen", "DarkCyan", "DarkRed", "DarkMagenta", "DarkYellow", "Gray", "DarkGray", "Blue", "Green", "Cyan", "Red", "Magenta", "Yellow", "White")]
        [string]$Colour,
        [Parameter(Mandatory = $false)]
        [ValidateSet("Foreground", "Background")]
        [string]$Type,
        [Parameter(Mandatory = $false)]
        [switch]$DefaultColours
    )
    if ($DefaultColours) {
        $Host.UI.RawUI.ForegroundColor = $script:OriginalFGColour
        $Host.UI.RawUI.BackgroundColor = $script:OriginalBGColour
        return
    }
    if ($Type -eq "Background") {
        $Host.UI.RawUI.BackgroundColor = $Colour
    }
    if ($Type -eq "Foreground") {
        $Host.UI.RawUI.ForegroundColor = $Colour
    }   
}

$ModulesArray = @('PartnerCenter', 'AzureAD', 'Microsoft.Graph.Authentication', 'Microsoft.Graph.Intune')
$ModulesArray | Init-CSPMgGraphModules
Select-Customer
