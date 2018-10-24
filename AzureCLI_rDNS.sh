#!/bin/bash
# sets reverse DNS in Azure
# 07/29/18
# Jonathan Sloan <jsloan117@gmail.com>
# version: 1.1

# Checks if azure-cli is installed and is version 2.0.x
if [[ ! -x "$(which az)" ]]; then

  echo -e "\nIt appears Azure-CLI isn't installed. Please download & install from here: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest\n"
  exit 1
elif ! (az --version | head -n1 | grep -q "^azure-cli (2.0.*)"); then

  echo -e "\nRequires Azure-CLI 2.0.x\n"
  exit 1

fi

# set article for help
ip_kb='https://docs.microsoft.com/en-us/azure/virtual-network/virtual-network-public-ip-address#view-change-settings-for-or-delete-a-public-ip-address'

# Login as your Azure Client
az login

# Get ResourceGroups
az group list --output table

# Prompt for RG
echo ''; read -ep 'Enter Resource Group Name: ' rg

Check_Allocation_Method () {
  az network public-ip list -g $rg --output table | grep -q Static && pipam='Static' || pipam='Dynamic'

  if [[ "$pipam" = 'Dynamic' ]]; then
    clear; echo -e "\nPublic IP is Dynamically assigned. Please change within your https://portal.azure.com account, this article should help. \n\n$ip_kb\n\n"
    exit 1
  fi
}

SetrDNS () {
  echo ''; az network public-ip list -g $rg --output table | awk '{print $1}'
  echo ''; read -ep 'Enter PublicIP Name: ' pipname
  echo ''; read -ep 'Enter a unique name not FQDN: ' hname
  echo ''; read -ep 'Enter Reverse DNS record name: ' fname

  echo -e 'Setting up reverse DNS...\n'
  az network public-ip update -g $rg -n $pipname --dns-name $hname --reverse-fqdn "$fname." --output table > /dev/null
}
Check_Allocation_Method
SetrDNS
echo -e "\n\n"; read -ep 'Press ENTER to finish and exit '
