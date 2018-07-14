<# Used to install AzureRM and update a reverse DNS record. Assumes the VM IP has been configured statically.
Requires PowerShell version 5.0+
07/13/18
Jonathan Sloan <jsloan117@gmail.com>
version: 1.0
#>

# Check PS Version
if ($PSVersionTable.PSVersion.Major -ge 5) {
    Write-Output "`nWe have the correct PowerShell version proceeding.`n"
} else {
    Write-Output "`nWrong PowerShell version to install AzureRM. Please visit the following link and download 5.0 or greater.`n
    https://docs.microsoft.com/en-us/powershell/scripting/setup/installing-windows-powershell?view=powershell-6#upgrading-existing-windows-powershell`n"
    Read-Host -Prompt 'Press any key to exit.'; exit
}

# Check if AzureRM module is installed already, install only if needed
if (Get-Module -ListAvailable -Name AzureRM) {
    Write-Output "AzureRM Module already installed proceeding.`n"
} else {
    Write-Output "Installing the AzureRM Module now...`n"
    Install-Module -Name AzureRM -Force
}

# Force executionpolicy to Bypass (no prompt)
Write-Output "Forcing ExecutionPolicy to Bypass for only this session to execute commands correctly.`n"
Set-Executionpolicy -Scope Process -ExecutionPolicy ByPass -Force

# Import module
Write-Output "Importing AzureRM module to proceed.`n"
Import-Module AzureRM

# Login as your Azure Client
$creds = Get-Credential;
Connect-AzureRmAccount -Credential $creds; Clear-Variable creds

# Get ResourceGroups
Get-AzureRmResourceGroup | Select-Object ResourceGroupName

# Prompt for RG
$rg = Read-Host -Prompt 'Enter Resource Group Name'

# Get Network Interface Name and IP
Write-Output "`n";Get-AzureRmNetworkInterface -ResourceGroupName $rg | ForEach-Object { $iface = $_.Name; $IPs = $_ | `
Get-AzureRmNetworkInterfaceIpConfig | Select-Object PrivateIPAddress; Write-Host "InterfaceName: $iface"`nIP: $IPs.PrivateIPAddress }; Write-Output "`n"

# Prompt for Private IP
$rip = Read-Host -Prompt 'Enter your IP in reverse order WITHOUT the last octet! Example: 192.168.3.1 ENTER 3.168.192'; Write-Output "`n"
$ripzone = "$rip.in-addr.arpa"

# Prompt for user inputs
$hip = Read-Host -Prompt 'Enter the last octet for the host. Example: 192.168.3.1 ENTER 1'; Write-Output "`n"
$fname = Read-Host -Prompt 'Enter the FQDN of the host.'; Write-Output "`n"

# Remove FQDN from the PTR record
$RecordSet = Get-AzureRmDnsRecordSet -ZoneName $ripzone -ResourceGroupName $rg -RecordType PTR -Name $hip
Remove-AzureRmDnsRecordConfig -Ptrdname "$fname" -RecordSet $RecordSet
Set-AzureRmDnsRecordSet -RecordSet $RecordSet

$fname = Read-Host -Prompt 'Enter the FQDN of the host for the new PTR record.'; Write-Output "`n"

# Add new FQDN to the PTR record
Add-AzureRmDnsRecordConfig -Ptrdname "$fname" -RecordSet $RecordSet
Set-AzureRmDnsRecordSet -RecordSet $RecordSet -Overwrite

# Get PublicIP
Get-AzureRmPublicIpAddress -ResourceGroupName $rg | Select-Object Name,IpAddress

# Prompt for Public IP Name
$pipname = Read-Host -Prompt 'Enter PublicIP Name.'; Write-Output "`n"
$hname = Read-Host -Prompt 'Enter just the hostname not FQDN.'

# Update the Reverse DNS record with new FQDN
Write-Output "`Updating DNS with the new rDNS record.`n"
$pip = Get-AzureRmPublicIpAddress -Name $pipname -ResourceGroupName $rg
$pip.DnsSettings = New-Object -TypeName "Microsoft.Azure.Commands.Network.Models.PSPublicIpAddressDnsSettings"
$pip.DnsSettings.DomainNameLabel = "$hname"
$pip.DnsSettings.ReverseFqdn = "$fname."
Set-AzureRmPublicIpAddress -PublicIpAddress $pip

Read-Host -Prompt 'Press any key to finish and exit.'