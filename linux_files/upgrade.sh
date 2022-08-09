#!/bin/bash

base_url="https://raw.githubusercontent.com/WhitewaterFoundry/pengwin-enterprise-rootfs-builds/master"
sudo curl -L -f "${base_url}/linux_files/upgrade.sh" -o /usr/local/bin/upgrade.sh
sudo chmod +x /usr/local/bin/upgrade.sh

# Do not change above this line to avoid update errors

if [[ ! -L /usr/local/bin/update.sh  ]]; then
  sudo ln -s /usr/local/bin/upgrade.sh /usr/local/bin/update.sh
fi

# If WSL1 and fake sudo is installed, then execute the script with su
if [[ -z "${WSL2}" && "$(sudo bash -c 'echo "$(whoami)"')" != "root" ]]; then
  su -c /usr/local/bin/upgrade.sh
  exit 0
fi

echo -n -e '\033]9;4;3;100\033\\'

sudo rm -f /var/lib/rpm/.rpm.lock

# Update mesa
source /etc/os-release
if [[ -n ${WAYLAND_DISPLAY} && ${VERSION_ID} == *"8"* && $( sudo dnf info --installed mesa-libGL | grep -c '21.3.4-wsl' ) == 0 ]]; then
  sudo yum -y install 'dnf-command(versionlock)'
  sudo yum versionlock delete mesa-dri-drivers mesa-libGL mesa-filesystem mesa-libglapi
  curl -s https://packagecloud.io/install/repositories/whitewaterfoundry/pengwin-enterprise/script.rpm.sh | sudo bash
  sudo yum -y install --allowerasing --nogpgcheck mesa-dri-drivers-21.3.4-wsl.el8 mesa-libGL-21.3.4-wsl.el8 glx-utils
  sudo yum versionlock add mesa-dri-drivers mesa-libGL mesa-filesystem mesa-libglapi
fi

sudo yum -y update
sudo rm -f /var/lib/rpm/.rpm.lock

# Update the release and main startup script files
sudo curl -L -f "${base_url}/linux_files/00-wle.sh" -o /etc/profile.d/00-wle.sh

# Add local.conf to fonts
sudo mkdir -p /etc/fonts
sudo curl -L -f "${base_url}/linux_files/local.conf" -o /etc/fonts/local.conf

# Install support for SystemD
sudo curl -L -f "${base_url}/linux_files/start-systemd.sudoers" -o /etc/sudoers.d/start-systemd
sudo curl -L -f "${base_url}/linux_files/start-systemd.sh" -o /usr/local/bin/start-systemd
sudo curl -L -f "${base_url}/linux_files/wsl2-xwayland.service" -o /etc/systemd/system/wsl2-xwayland.service
sudo curl -L -f "${base_url}/linux_files/wsl2-xwayland.socket" -o /etc/systemd/system/wsl2-xwayland.socket

sudo curl -L -f "${base_url}/linux_files/systemctl3.py" -o /usr/local/bin/wslsystemctl
sudo chmod u+x /usr/local/bin/start-systemd
sudo chmod +x /usr/local/bin/wslsystemctl

echo -n -e '\033]9;4;0;100\033\\'
