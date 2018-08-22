# Azure_Scripts

![License](https://img.shields.io/badge/License-GPLv3-blue.svg)

**Using one of these on an Operating System not shown next to them may result in failure.**

How to change your IP from Dynamic to Static: <https://docs.microsoft.com/en-us/azure/virtual-network/virtual-network-public-ip-address#view-change-settings-for-or-delete-a-public-ip-address>

If you have 2FA (Two-Factor auauthentication) enabled on your Azure account do **_NOT_** use the AzureRM. <https://docs.microsoft.com/en-us/powershell/module/azurerm.profile/add-azurermaccount?view=azurermps-4.4.1#description>

- `AzureRM_rDNS.ps1` -- Set reverse DNS using AzureRM Powershell module. (Windows)

- `AzureCLI_rDNS.ps1` -- Set reverse DNS using Azure-CLI 2.0 (Windows)

- `AzureCLI_rDNS.sh` -- Set reverse DNS using Azure-CLI 2.0 (Linux/Mac)

- `AzureRM_PC_rDNS.ps1` -- Login to client's account using Partner Center and set rDNS for them. Be sure to change the below variables.
  - $nativeAppIdGuid = "FILL THIS IN WITH YOUR INFORMATION"
  - $cspPartnerDomain = "example.onmicrosoft.com"
