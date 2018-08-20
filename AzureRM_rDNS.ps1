<# Used to install AzureRM. Sets reverse DNS in Azure.
Requires PowerShell version 5.0+
07/29/18
Jonathan Sloan <jsloan117@gmail.com>
version: 1.1
NO 2FA: https://docs.microsoft.com/en-us/powershell/module/azurerm.profile/add-azurermaccount?view=azurermps-4.4.1#description
#>

# Force executionpolicy to Bypass (no prompt)
Write-Output "Forcing ExecutionPolicy to Bypass for only this session to execute commands correctly.`n"
Set-Executionpolicy -Scope Process -ExecutionPolicy ByPass -Force

# Check PS Version
if ($PSVersionTable.PSVersion.Major -ge 5 -and $PSVersionTable.PSVersion.Major -lt 6) {
  Write-Output "`nWe have the correct PowerShell version proceeding.`n"; $arm = 'AzureRM'
} elseif ($PSVersionTable.PSVersion.Major -ge 6) {
  Write-Output "`nWe have the correct PowerShell version proceeding.`n"; $arm = 'AzureRM.NetCore'
} else {
  Write-Output "`n    Wrong PowerShell version to install AzureRM or AzureRM.NetCore (Powershell >=6). Please visit the following link and download 5.0 or greater.`n
  https://docs.microsoft.com/en-us/powershell/scripting/setup/installing-windows-powershell?view=powershell-6#upgrading-existing-windows-powershell`n`n    or`n
  https://aka.ms/getps6-windows (Powershell >=6.0)."
  Read-Host -Prompt 'Press ENTER to exit'; exit
}

$Shell = $Host.UI.RawUI; $Shell.WindowTitle="AzureRM reverse DNS Tool"

# Check if AzureRM module is installed already, install only if needed
if (Get-Module -ListAvailable -Name $arm) {
  Write-Output "AzureRM Module already installed proceeding.`n"
} else {
  Write-Output "Installing the AzureRM Module now...`n"
  Install-Module -Name $arm -Force
}

# Import module
Write-Output "Importing AzureRM module to proceed.`n"
Import-Module $arm

# set article for help
$ip_kb = 'https://docs.microsoft.com/en-us/azure/virtual-network/virtual-network-public-ip-address#view-change-settings-for-or-delete-a-public-ip-address'

# Login as your Azure Client
$creds = Get-Credential;
Connect-AzureRmAccount -Credential $creds; Clear-Variable creds; Write-Output "`nMay need to press enter to continue.`n"

# Get ResourceGroups
Get-AzureRmResourceGroup | Select-Object ResourceGroupName

# Prompt for RG
$rg = Read-Host -Prompt 'Enter Resource Group Name'

function Check_Allocation_Method () {
  Get-AzureRmPublicIpAddress -ResourceGroupName $rg | Select-Object Name,IpAddress
  $Global:pipname = Read-Host -Prompt 'Enter PublicIP Name'; Write-Output "`n"
  $pipam = Get-AzureRmPublicIpAddress -Name $pipname -ResourceGroupName $rg | Select-Object PublicIpAllocationMethod

  if ($pipam -match 'Dynamic') {
    Clear-Host; Write-Output "`n";
    Write-Output "Public IP is Dynamically assigned. Please change within your https://poral.azure.com account, this article should help. `n`n$ip_kb`n`n"
    Read-Host -Prompt 'Press ENTER to exit. '
    exit 1
  }
}

function SetrDNS {
  $hname = Read-Host -Prompt 'Enter a unique name not FQDN: '; Write-Output "`n"
  $fname = Read-Host -Prompt 'Enter Reverse DNS record name: '; Write-Output "`n"

  Write-Output "Setting up reverse DNS.`n"
  $pip = Get-AzureRmPublicIpAddress -Name $pipname -ResourceGroupName $rg
  $pip.DnsSettings = New-Object -TypeName "Microsoft.Azure.Commands.Network.Models.PSPublicIpAddressDnsSettings"
  $pip.DnsSettings.DomainNameLabel = "$hname"
  $pip.DnsSettings.ReverseFqdn = "$fname."
  Set-AzureRmPublicIpAddress -PublicIpAddress $pip
}
Check_Allocation_Method
SetrDNS
Write-Output "`n"; Read-Host -Prompt 'Press ENTER to finish and exit '
