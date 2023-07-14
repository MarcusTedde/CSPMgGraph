# CSPMgGraph
Functions for connecting to customers using CSP credentials through Microsoft Graph.

You will need to create an app registration on your CSP Tenant for Microsoft Graph, with the API permissions on the App for whatever you need. 
Change line 76 of the script to reflect the Graph API permissions you have set (Variable $GraphScopes. 
Once you’ve created the CSP App, you will need to set the global variables on lines 4-6 and line 9 with your App ID, App Secret, your CSP Partner Tenant ID where you’ve created the App, and the display name of the app.

The script includes the function for consenting the application for your customers per customer. To consent for all customers then perform something similar to the following after loading the functions and global variables in to your PowerShell session:

Get-MgContract -All | foreach {consent-PartnerApplication -CustomerTenantId $_.CustomerId}

# Important Notes

*sometimes you'll get an error regarding MFA. to combat this, first log in to your CSP portal.azure.com, login using your MFA. This will clear the error.*