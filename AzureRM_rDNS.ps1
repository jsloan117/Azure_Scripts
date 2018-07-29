<# Used to install AzureRM. Sets reverse DNS in Azure.
Requires PowerShell version 5.0+
07/29/18
Jonathan Sloan <jsloan117@gmail.com>
version: 1.0
#>

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

$Shell = $Host.UI.RawUI; $Shell.WindowTitle="Azure reverse DNS Tool"

# Check if AzureRM module is installed already, install only if needed
if (Get-Module -ListAvailable -Name $arm) {
    Write-Output "AzureRM Module already installed proceeding.`n"
} else {
    Write-Output "Installing the AzureRM Module now...`n"
    Install-Module -Name $arm -Force
}

# Force executionpolicy to Bypass (no prompt)
Write-Output "Forcing ExecutionPolicy to Bypass for only this session to execute commands correctly.`n"
Set-Executionpolicy -Scope Process -ExecutionPolicy ByPass -Force

# Import module
Write-Output "Importing AzureRM module to proceed.`n"
Import-Module $arm

# Login as your Azure Client
$creds = Get-Credential;
Connect-AzureRmAccount -Credential $creds; Clear-Variable creds

# Get ResourceGroups
Get-AzureRmResourceGroup | Select-Object ResourceGroupName

# Prompt for RG
$rg = Read-Host -Prompt 'Enter Resource Group Name'

function SetrDNS {
    Get-AzureRmPublicIpAddress -ResourceGroupName $rg | Select-Object Name,IpAddress
    $pipname = Read-Host -Prompt 'Enter PublicIP Name'; Write-Output "`n"
    $hname = Read-Host -Prompt 'Enter a unique name not FQDN: '
    $fname = Read-Host -Prompt 'Enter Reverse DNS record name: '
    $pipam = Get-AzureRmPublicIpAddress -Name $pipname -ResourceGroupName $rg | Select-Object PublicIpAllocationMethod

    if ($pipam -notmatch 'Static') { # Ensure PublicIP is assigned statically - may cause a reboot of the VM
        $pip = Get-AzureRmPublicIpAddress -Name $pipname -ResourceGroupName $rg
        $pip.DnsSettings = New-Object -TypeName "Microsoft.Azure.Commands.Network.Models.PSPublicIpAddressDnsSettings"
        $pip.DnsSettings.DomainNameLabel = "$hname"
        $pip.PublicIpAllocationMethod = "Static"
        $pip.DnsSettings.ReverseFqdn = "$fname."
        Set-AzureRmPublicIpAddress -PublicIpAddress $pip
    } else {
        Write-Output "`nPublic IP assigned statically. Proceeding with rDNS setup.`n"
        $pip = Get-AzureRmPublicIpAddress -Name $pipname -ResourceGroupName $rg
        $pip.DnsSettings = New-Object -TypeName "Microsoft.Azure.Commands.Network.Models.PSPublicIpAddressDnsSettings"
        $pip.DnsSettings.DomainNameLabel = "$hname"
        $pip.DnsSettings.ReverseFqdn = "$fname."
        Set-AzureRmPublicIpAddress -PublicIpAddress $pip
    }
}
Write-Output "`n"; Read-Host -Prompt 'Press ENTER to finish and exit'
