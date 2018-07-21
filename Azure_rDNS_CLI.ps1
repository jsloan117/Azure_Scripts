<# Configures|updates rDNS in Azure
07/20/18
Jonathan Sloan <jsloan117@gmail.com>
version: 0.1
#>

$Shell = $Host.UI.RawUI; $Shell.WindowTitle="Azure reverse DNS Tool"

# Login as your Azure Client
az login

# Get ResourceGroups
Clear-Host; az group list --output table

# Prompt for RG
Write-Output "`n"; $rg = Read-Host -Prompt 'Enter Resource Group Name: '

# Get VM & IPs
Write-Output "`n"; az vm list-ip-addresses -g $rg --output table

Write-Output "`n"; $rip = Read-Host -Prompt 'Enter your Private IP in reverse order WITHOUT the last octet! Example: 192.168.3.1 ENTER 3.168.192: '
$ripzone="$rip.in-addr.arpa"

Write-Output "`n"; $hip = Read-Host -Prompt 'Enter the last octet for the server. Example: 192.168.3.1 ENTER 1: '
Write-Output "`n"; $fname = Read-Host -Prompt 'Enter FQDN of the server: '
Write-Output "`n"; $choice = Read-Host -Prompt 'What do you need to do? Create a rDNS record or Update it? [create|update]: '

$zone_exists = $(az network dns zone list -g $rg --output table)

if (([string]::IsNullOrWhiteSpace($zone_exists)) -and ($choice = 'update')) {
    $choice = 'create'; Clear-Variable zone_exists
} else {
    $choice = 'update'; Clear-Variable zone_exists
}

function SetrDNS () {
    Write-Output "`n"; az network public-ip list -g $rg --output table
    Write-Output "`n"; $pipname = Read-Host -Prompt 'Enter PublicIP Name: '
    Write-Output "`n"; $hname = Read-Host -Prompt 'Enter just the hostname not FQDN: '
    Write-Output "`n"; az network public-ip list -g $rg --output table | findstr /L Static > $null; $x = $?

    if ($x = 'True') {
        $pipam = 'Static'
    } else {
        $pipname = 'Dynamic'
    }

    if ($pipam -notmatch "Static") { # Ensure PublicIP is assigned statically - may cause a reboot of the VM
        Write-Output "Setting Public Allocation Method to Static and proceeding with rDNS setup.`n"
        az network public-ip update -g $rg -n $pipname --dns-name $hname --allocation-method Static --reverse-fqdn "${fname}." --output table
    } else {
        Write-Output "Public IP assigned statically. Proceeding with rDNS setup.`n"
        az network public-ip update -g $rg -n $pipname --dns-name $hname --reverse-fqdn "${fname}." --output table #> $null
    }

}

if ([string]::IsNullOrWhiteSpace($choice)) {
    Write-Output "`nMust enter either create or update. Bye-Bye.....`n"; Start-Sleep -s 5; exit
} elseif ($choice -match '^create$') {
    # Setup DNS Zone
    Write-Output "`nSetting up DNS zone.`n"
    az network dns zone create -n $ripzone -g $rg --output table
    Write-Output "`n"; $rttl = Read-Host -Prompt 'Enter TTL value for record [3600]'; if ([string]::IsNullOrWhiteSpace($rttl)) { $rttl = '3600' }
    # Create PTR record in newly created zone
    Write-Output "`nCreating new PTR record.`n"
    az network dns record-set ptr add-record -g $rg -z $ripzone -n $hip --ptrdname $fname --output table
    SetrDNS
} elseif ($choice -match '^update$') {
    # Remove PTR record
    az network dns record-set ptr remove-record -g $rg -z $ripzone -n $hip -d $fname --output table
    # Get new FQDN for PTR record
    Write-Output "`n"; $fname = Read-Host -Prompt 'Enter the FQDN of the server for the new PTR record: '
    # Add new PTR record
    Write-Output "`n"; az network dns record-set ptr add-record -g $rg -z $ripzone -n $hip --ptrdname $fname --output table #> $null
    # Update the Reverse DNS record with new FQDN
    Write-Output "`nUpdating DNS with the new rDNS record."
    SetrDNS
} else {
    Write-Output "`nMust enter either create or update. Bye-Bye.....`n"; Start-Sleep -s 5; exit
}
Read-Host -Prompt 'Press ENTER to finish and exit'