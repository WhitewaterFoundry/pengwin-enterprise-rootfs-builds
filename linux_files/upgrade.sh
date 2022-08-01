#!/bin/bash

base_url="https://raw.githubusercontent.com/WhitewaterFoundry/pengwin-enterprise-rootfs-builds/master"
sudo curl -L -f "${base_url}/linux_files/upgrade.sh" -o /usr/local/bin/upgrade.sh
sudo chmod +x /usr/local/bin/upgrade.sh

# If WSL1 and fake sudo is installed, then execute the script with su
if [[ -z "${WSL2}" && "$(sudo bash -c 'echo "$(whoami)"')" != "root" ]]; then
  su -c /usr/local/bin/upgrade.sh
  exit 0
fi

echo -n -e '\033]9;4;3;100\033\\'

sudo rm -f /var/lib/rpm/.rpm.lock
sudo yum -y update
sudo rm -f /var/lib/rpm/.rpm.lock

# Update the release and main startup script files
sudo curl -L -f "${base_url}/linux_files/00-wle.sh" -o /etc/profile.d/00-wle.sh

# Add local.conf to fonts
sudo mkdir -p /etc/fonts
sudo curl -L -f "${base_url}/linux_files/local.conf" -o /etc/fonts/local.conf

# Install mesa
source /etc/os-release
if [[ -n ${WAYLAND_DISPLAY} && ${VERSION_ID} == '8.5' && $( sudo dnf info --installed mesa-libGL | grep -c '21.1.5-wsl' ) == 0 ]]; then
  sudo yum -y install 'dnf-command(versionlock)'
  sudo yum versionlock delete mesa-dri-drivers mesa-libGL mesa-filesystem mesa-libglapi
  curl -s https://packagecloud.io/install/repositories/whitewaterfoundry/pengwin-enterprise/script.rpm.sh | sudo bash
  sudo yum -y install --allowerasing --nogpgcheck mesa-dri-drivers-21.1.5-wsl.el8 mesa-libGL-21.1.5-wsl.el8 glx-utils
  sudo yum versionlock add mesa-dri-drivers mesa-libGL mesa-filesystem mesa-libglapi
fi

# Install support for SystemD

# if machinectl is not installed then install it
if (! command -v machinectl >/dev/null 2>&1); then
  sudo yum -y install systemd-container
fi

echo -n -e '\033]9;4;0;100\033\\'
