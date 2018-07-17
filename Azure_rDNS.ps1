<# Used to install AzureRM. Configures/updates a reverse DNS record. Assumes the VM IP has been configured statically.
Requires PowerShell version 5.0+
07/13/18
Jonathan Sloan <jsloan117@gmail.com>
version: 1.0
#>

# Check PS Version
if ($PSVersionTable.PSVersion.Major -ge 5 -and $PSVersionTable.PSVersion.Major -lt 6) {
    Write-Output "`nWe have the correct PowerShell version proceeding.`n"
} else {
    Write-Output "`nWrong PowerShell version to install AzureRM. Please visit the following link and download 5.0 or greater.`n
    https://docs.microsoft.com/en-us/powershell/scripting/setup/installing-windows-powershell?view=powershell-6#upgrading-existing-windows-powershell`n"
    Read-Host -Prompt 'Press ENTER to exit'; exit
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

# Prompt for hostIP and FQDN
$hip = Read-Host -Prompt 'Enter the last octet for the server. Example: 192.168.3.1 ENTER 1'; Write-Output "`n"
$fname = Read-Host -Prompt 'Enter the FQDN of the server'; Write-Output "`n"
$choice = Read-Host -Prompt 'What do you need to do? Create a rDNS record or Update it? [create|update]'

# Check if the zone exists or use create NOT update
$zone_exists = Get-AzureRmDnsZone -Name $ripzone -ResourceGroupName $rg
if ([string]::IsNullOrWhiteSpace($zone_exists)) {
    Clear-Variable zone_exists; $choice = 'create'; Write-Output "Looks like the zone $ripzone doesnt exist. Proceeding to create it now.`n"
}

function SetrDNS {
    Get-AzureRmPublicIpAddress -ResourceGroupName $rg | Select-Object Name,IpAddress
    $pipname = Read-Host -Prompt 'Enter PublicIP Name'; Write-Output "`n"
    $hname = Read-Host -Prompt 'Enter just the hostname not FQDN'
    $pipam = Get-AzureRmPublicIpAddress -Name $pipname -ResourceGroupName $rg | Select-Object PublicIpAllocationMethod

    if ($pipam -notmatch "Static") { # Ensure PublicIP is assigned statically - may cause a reboot of the VM
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

if ([string]::IsNullOrWhiteSpace($choice)) {
    Write-Output "`nMust enter either create or update. Bye-Bye.....`n"; Start-Sleep -s 5; exit
} elseif ($choice -match '^create$') {
    # Setup DNS Zone
    Write-Output "`nSetting up DNS zone.`n"
    New-AzureRmDnsZone -Name $ripzone -ResourceGroupName $rg
    $rttl = Read-Host -Prompt 'Enter TTL value for record [3600]'; if ([string]::IsNullOrWhiteSpace($rttl)) { $rttl = '3600' }
    # Create PTR record in newly created zone
    Write-Output "`nCreating new PTR record.`n"
    New-AzureRmDnsRecordSet -Name $hip -RecordType PTR -ZoneName $ripzone -ResourceGroupName $rg -Ttl $rttl -DnsRecords (New-AzureRmDnsRecordConfig -Ptrdname "$fname")
    # Get DNS Zone Records
    Write-Output "You should see your new PTR record below.`n"
    Get-AzureRmDnsRecordSet -ZoneName $ripzone -ResourceGroupName $rg -RecordType PTR
    SetrDNS
} elseif ($choice -match '^update$') {
    # Remove FQDN from the PTR record
    $RecordSet = Get-AzureRmDnsRecordSet -ZoneName $ripzone -ResourceGroupName $rg -RecordType PTR -Name $hip
    Remove-AzureRmDnsRecordConfig -Ptrdname "$fname" -RecordSet $RecordSet
    Set-AzureRmDnsRecordSet -RecordSet $RecordSet
    $fname = Read-Host -Prompt 'Enter the FQDN of the server for the new PTR record'; Write-Output "`n"
    # Add new FQDN to the PTR record
    Add-AzureRmDnsRecordConfig -Ptrdname "$fname" -RecordSet $RecordSet
    Set-AzureRmDnsRecordSet -RecordSet $RecordSet -Overwrite
    # Update the Reverse DNS record with new FQDN
    Write-Output "`Updating DNS with the new rDNS record.`n"
    SetrDNS
} else {
    Write-Output "`nMust enter either create or update. Bye-Bye.....`n"; Start-Sleep -s 5; exit
}
Read-Host -Prompt 'Press ENTER to finish and exit'