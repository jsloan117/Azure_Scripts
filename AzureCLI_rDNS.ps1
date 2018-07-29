<# sets reverse DNS in Azure
07/29/18
Jonathan Sloan <jsloan117@gmail.com>
version: 1.0
#>

# Set Shell Window Title
$Shell = $Host.UI.RawUI; $Shell.WindowTitle="Azure reverse DNS Tool"

# Login as your Azure Client
az login

# Get ResourceGroups
Clear-Host; az group list --output table

# Prompt for RG
Write-Output "`n"; $rg = Read-Host -Prompt 'Enter Resource Group Name: '

function SetrDNS () {
    Write-Output "`n"; az network public-ip list -g $rg --output table
    Write-Output "`n"; $pipname = Read-Host -Prompt 'Enter PublicIP Name: '
    Write-Output "`n"; $hname = Read-Host -Prompt 'Enter a unique name not FQDN: '
    Write-Output "`n"; $fname = Read-Host -Prompt 'Enter Reverse DNS record name: '
    Write-Output "`n"; az network public-ip list -g $rg --output table | findstr /L Static > $null; $rcode = $?

    if ($rcode = 'True') {
        $pipam = 'Static'
    } else {
        $pipam = 'Dynamic'
    }

    if ($pipam -notmatch '^Static$') { # Ensure PublicIP is assigned statically - may cause a reboot of the VM
        Write-Output "Setting Public Allocation Method to Static and proceeding with rDNS setup.`n"
        az network public-ip update -g $rg -n $pipname --dns-name $hname --allocation-method Static --reverse-fqdn "${fname}." --output table > $null
    } else {
        Write-Output "Public IP assigned statically. Proceeding with rDNS setup.`n"
        az network public-ip update -g $rg -n $pipname --dns-name $hname --reverse-fqdn "${fname}." --output table > $null
    }
}
SetrDNS
Write-Output "`n"; Read-Host -Prompt 'Press ENTER to finish and exit'
