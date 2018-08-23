<# Used to install AzureRM/PartnerCenterModule. Sets reverse DNS in Azure.
Requires PowerShell version 5.0 or 5.1
08/22/18
Jonathan Sloan <jsloan117@gmail.com>
version: 1.0
NO 2FA: https://docs.microsoft.com/en-us/powershell/module/azurerm.profile/add-azurermaccount?view=azurermps-4.4.1#description
#>

# Force executionpolicy to Bypass (no prompt)
Write-Output "Forcing ExecutionPolicy to Bypass for only this session to execute commands correctly.`n"
Set-Executionpolicy -Scope Process -ExecutionPolicy ByPass -Force

# Check PS Version
if ($PSVersionTable.PSVersion.Major -ge 5 -and $PSVersionTable.PSVersion.Major -lt 6) {
  Write-Output "`nWe have the correct PowerShell version proceeding.`n"
} elseif ($PSVersionTable.PSVersion.Major -ge 6) {
  Write-Output "`nPowershell 6+ is not supported, use 5.1`n"
  Read-Host -Prompt 'Press ENTER to exit'; exit 1
} else {
  Write-Output "`n    Wrong PowerShell version to install AzureRM and PartnerCenterModule (Powershell <6 >=5). Please visit the following link and download 5.1.`n
  https://docs.microsoft.com/en-us/powershell/scripting/setup/installing-windows-powershell?view=powershell-6#upgrading-existing-windows-powershell`n`n"
  Read-Host -Prompt 'Press ENTER to exit '; exit 1
}

$Shell = $Host.UI.RawUI; $Shell.WindowTitle="AzureRM Partner Center reverse DNS Tool"

# Check if AzureRM module is installed already, install only if needed
if (Get-Module -ListAvailable -Name AzureRM) {
  Write-Output "AzureRM already installed proceeding.`n"
} else {
  Write-Output "Installing the AzureRM Module now...`n"
  Install-Module -Name AzureRM -Force
}

# Check if PartnerCenterModule module is installed already, install only if needed
if (Get-Module -ListAvailable -Name PartnerCenterModule) {
  Write-Output "PartnerCenterModule already installed proceeding.`n"
} else {
  Write-Output "Installing the PartnerCenterModule now...`n"
  Install-Module -Name PartnerCenterModule -Force
}

# Import modules
Write-Output "Importing AzureRM/PartnerCenterModule module to proceed.`n"
Import-Module AzureRM,PartnerCenterModule

# Set Variables -- Change below to your environment
$nativeAppIdGuid = "FILL THIS IN WITH YOUR INFORMATION"
$cspPartnerDomain = "example.onmicrosoft.com"

# Get username to login with
$user = Read-Host -Prompt 'Enter your username before the @. '
$userName = "$user@$cspPartnerDomain"

# Get password username set above
$credentials = Get-Credential $userName

# Login to Partner Center
Add-PCAuthentication -cspappID $nativeAppIdGuid -cspDomain $cspPartnerDomain -credential $credentials

# Get companyname that will be used to search for
Write-Output "`nThis info may be obtainable from your Billing Software), else you'd need to find it in Azure Partner Center.`n"
$companyName = Read-Host -Prompt 'Enter clients company name: '

# Set Tenant ID # Ideal solution would be to prompt for the actual Tenant ID and Subscript to prevent checking for dupes
$tid = (Get-PCCustomer -StartsWith $companyName | Select-Object -ExpandProperty companyProfile | Where-Object companyName -EQ $companyName).tenantId
# Count how may TenantID's we got back
$t = ($tid | Measure-Object).Count
# Set Subscription ID
$sid = (Get-PCSubscription -TenantId $tid).id
# Count how many Subscriptions we got back
$s = ($sid | Measure-Object).Count

# Ensure we only have one Tenant ID else, prompt for one to be entered. If we fall back to prompting ensure to check PartnerCenter.
if ($t -gt 1 ) {
  Write-Output "`nPlease go to the Partner Center and locate the Customer and enter their Tentant ID below.`n"
  (Get-PCCustomer -StartsWith $companyName).id ; Write-Output "`n"
  $tid = Read-Host -Prompt "Enter the client's Tenant ID: "
} elseif ($t -eq 0) {
  Write-Output "`nPlease go to the Partner Center and locate the Customer and enter their Tentant ID below.`n"
  $tid = Read-Host -Prompt "Enter the client's Tenant ID: "
}

# Ensure we only have one Subscription ID else, prompt for one to be entered. If we fall back to prompting ensure to check PartnerCenter.
if ($s -gt 1 ) {
  Write-Output "`nPlease go to the Partner Center and locate the Customer and enter their Subscription ID below.`n"
  (Get-PCSubscription -TenantId $tid).id ; Write-Output "`n"
  $sid = Read-Host -Prompt 'Enter the clients Subscription ID: '
} elseif ($s -eq 0) {
  Write-Output "`nPlease go to the Partner Center and locate the Customer and enter their Subscription ID below.`n"
  $sid = Read-Host -Prompt 'Enter the clients Subscription ID: '
}

# Login with our creds and the tid/sid provided
Connect-AzureRmAccount -Credential $credentials -TenantId $tid -Subscription $sid

# Check VirtualMachines in Client's Portal
# Get-AzureRmVM -Status

# set article for help
$ip_kb = 'https://docs.microsoft.com/en-us/azure/virtual-network/virtual-network-public-ip-address#view-change-settings-for-or-delete-a-public-ip-address'

# Get ResourceGroups
(Get-AzureRmResourceGroup).ResourceGroupName

# Prompt for RG
Write-Output "`n";$rg = Read-Host -Prompt 'Enter Resource Group Name: '

function Check_Allocation_Method () {
  Get-AzureRmPublicIpAddress -ResourceGroupName $rg | Select-Object Name,IpAddress
  $Script:pipname = Read-Host -Prompt 'Enter PublicIP Name: '; Write-Output "`n"
  $pipam = (Get-AzureRmPublicIpAddress -Name $pipname -ResourceGroupName $rg).PublicIpAllocationMethod

  if ($pipam -match 'Dynamic') {
    Clear-Host; Write-Output "`n";
    Write-Output "Public IP is Dynamically assigned. Please change within your https://poral.azure.com account, this article should help. `n`n$ip_kb`n`n"
    Read-Host -Prompt 'Press ENTER to exit '
    exit 1
  }
}

function SetrDNS {
  $hname = Read-Host -Prompt 'Enter a unique name not FQDN: '; Write-Output "`n"
  $fname = Read-Host -Prompt 'Enter Reverse DNS record name: '; Write-Output "`n"

  Write-Output "Setting up reverse DNS...`n"
  $pip = Get-AzureRmPublicIpAddress -Name $pipname -ResourceGroupName $rg
  $pip.DnsSettings = New-Object -TypeName 'Microsoft.Azure.Commands.Network.Models.PSPublicIpAddressDnsSettings'
  $pip.DnsSettings.DomainNameLabel = "$hname"
  $pip.DnsSettings.ReverseFqdn = "$fname."
  Set-AzureRmPublicIpAddress -PublicIpAddress $pip
}
Check_Allocation_Method
SetrDNS
Write-Output "`n"; Read-Host -Prompt 'Press ENTER to finish and exit '
