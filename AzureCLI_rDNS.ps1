<# sets reverse DNS in Azure
07/29/18
Jonathan Sloan <jsloan117@gmail.com>
version: 1.1
#>

# Force executionpolicy to Bypass (no prompt)
Write-Output "Forcing ExecutionPolicy to Bypass for only this session to execute commands correctly.`n"
Set-Executionpolicy -Scope Process -ExecutionPolicy ByPass -Force

# Set Shell Window Title
$Shell = $Host.UI.RawUI; $Shell.WindowTitle="AzureCLI reverse DNS Tool"

# set article for help
$ip_kb = 'https://docs.microsoft.com/en-us/azure/virtual-network/virtual-network-public-ip-address#view-change-settings-for-or-delete-a-public-ip-address'

# Login as your Azure Client
az login; Write-Output "`nMay need to press enter to continue`n"

# Get ResourceGroups
az group list --output table

# Prompt for RG
Write-Output "`n"; $rg = Read-Host -Prompt 'Enter Resource Group Name: '

function Check_Allocation_Method () {
  Write-Output "`n"; az network public-ip list -g $rg --output table | findstr /L Dynamic > $null; $rcode = $?

  if ($rcode -match 'True') {
    Clear-Host; Write-Output "`n";
    Write-Output "Public IP is Dynamically assigned. Please change within your https://poral.azure.com account, this article should help. `n`n$ip_kb`n`n"
    Read-Host -Prompt 'Press ENTER to exit '
    exit 1
  }
}

function SetrDNS () {
  az network public-ip list -g $rg --output table
  Write-Output "`n"; $pipname = Read-Host -Prompt 'Enter PublicIP Name: '
  Write-Output "`n"; $hname = Read-Host -Prompt 'Enter a unique name not FQDN: '
  Write-Output "`n"; $fname = Read-Host -Prompt 'Enter Reverse DNS record name: '

  Write-Output "Setting up reverse DNS...`n"
  az network public-ip update -g $rg -n $pipname --dns-name $hname --reverse-fqdn "$fname." --output table > $null
}
Check_Allocation_Method
SetrDNS
Write-Output "`n"; Read-Host -Prompt 'Press ENTER to finish and exit '
