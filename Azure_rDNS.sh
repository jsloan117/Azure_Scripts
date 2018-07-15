#!/bin/bash
# Configures|updates rDNS in Azure
# 07/15/18
# Jonathan Sloan <jsloan117@gmail.com>
# version: 1.0

# Checks if azure-cli is installed and is version 2.0.x
if [[ ! -x "$(which az)" ]]; then

    echo -e "\nIt appears Azure-CLI isn't installed. Please download & install from here: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest\n" && exit 1

elif ! (az --version | head -n1 | grep -q "^azure-cli (2.0.*)"); then

    echo -e "\nRequires Azure-CLI 2.0.x\n" && exit 1

fi

# Login as your Azure Client
az login

# Set output format to table
op='-o table'

# Get ResourceGroups
clear; az group list $op

# Prompt for RG
echo ''; read -ep 'Enter Resource Group Name: ' rg

# Get VM & IPs
echo ''; az vm list-ip-addresses -g $rg $op

echo ''; read -ep 'Enter your Private IP in reverse order WITHOUT the last octet! Example: 192.168.3.1 ENTER 3.168.192: ' rip
ripzone="$rip.in-addr.arpa"

echo ''; read -ep 'Enter the last octet for the server. Example: 192.168.3.1 ENTER 1: ' hip
echo ''; read -ep 'Enter FQDN of the server: ' fname
echo ''; read -ep 'What do you need to do? Create a rDNS record or Update it? [create|update]: ' choice

zone_exists=$(az network dns zone list -g $rg $op)

[[ -z "$zone_exists" ]] && choice='create' || choice='update'; unset zone_exists

SetrDNS () {
    echo ''; az network public-ip list -g $rg $op | awk '{print $1}'
    echo ''; read -ep 'Enter PublicIP Name: ' pipname
    echo ''; read -ep 'Enter just the hostname not FQDN: ' hname
    echo ''; az network public-ip list -g $rg $op | grep -q Static && pipam='Static' || pipam='Dynamic'

    if [[ "$pipam" = 'Dynamic' ]]; then

        echo -e 'Setting Public Allocation Method to Static and proceeding with rDNS setup.\n'
        az network public-ip update -g $rg -n $pipname --dns-name $hname --allocation-method Static --reverse-fqdn "${fname}." $op

    elif [[ "$pipam" = 'Static' ]]; then

        echo -e 'Public IP assigned statically. Proceeding with rDNS setup.\n'
        az network public-ip update -g $rg -n $pipname --dns-name $hname --reverse-fqdn "${fname}." $op

    fi
}

if [[ -z "$choice" ]]; then

    echo -e 'Must enter either create or update. Bye-Bye.....\n' && sleep 5 && exit

elif [[ "$choice" = 'create' ]]; then

    # Setup DNS Zone
    echo -e '\nSetting up DNS zone.\n'
    az network dns zone create -n $ripzone -g $rg $op
    echo ''; tmpv='3600'; read -ep "Enter TTL value for the record [${tmpv}]: " rttl ; rttl=${rttl:-${tmpv}}
    # Create PTR record in newly created zone
    echo -e '\nCreating new PTR record.\n'
    az network dns record-set ptr add-record -g $rg -z $ripzone -n $hip --ptrdname $fname $op
    SetrDNS

elif [[ "$choice" = 'update' ]]; then

    # Remove PTR record
    az network dns record-set ptr remove-record -g $rg -z $ripzone -n $hip -d $fname $op
    # Get new FQDN for PTR record
    echo ''; read -ep 'Enter the FQDN of the server for the new PTR record: ' fname
    # Add new PTR record
    echo ''; az network dns record-set ptr add-record -g $rg -z $ripzone -n $hip --ptrdname $fname $op
    # Update the Reverse DNS record with new FQDN
    echo -e '\nUpdating DNS with the new rDNS record.'
    SetrDNS

else

    echo -e 'Must enter either create or update. Bye-Bye.....\n' && sleep 5 && exit

fi
echo -e "\n\n"; read -ep 'Press ENTER to finish and exit '