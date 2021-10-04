#!/bin/bash

# If WSL1 and fake sudo is installed, then execute the script with su
if [[ -z "${WSL2}" && "$(sudo bash -c 'echo "$(whoami)"')" != "root" ]]; then
  su -c /usr/local/bin/upgrade.sh
  exit 0
fi

base_url="https://raw.githubusercontent.com/WhitewaterFoundry/pengwin-enterprise-rootfs-builds/master"
sha256sum /usr/local/bin/upgrade.sh >/tmp/sum.txt
sudo curl -L -f "${base_url}/linux_files/upgrade.sh" -o /usr/local/bin/upgrade.sh
sudo chmod +x /usr/local/bin/upgrade.sh
sha256sum -c /tmp/sum.txt

changed=$?
rm -r /tmp/sum.txt

# the script has changed? run the newer one
if [ ${changed} -eq 1 ]; then
  echo Running the updated script
  bash /usr/local/bin/upgrade.sh
  exit 0
fi

echo -n -e '\033]9;4;3;100\033\\'

sudo yum -y update

# Update the release and main startup script files
sudo curl -L -f "${base_url}/linux_files/00-wle.sh" -o /etc/profile.d/00-wle.sh

# Add local.conf to fonts
sudo mkdir -p /etc/fonts
sudo curl -L -f "${base_url}/linux_files/local.conf" -o /etc/fonts/local.conf

echo -n -e '\033]9;4;0;100\033\\'
