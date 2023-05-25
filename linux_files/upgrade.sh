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

declare -a mesa_version=('22.3.0-wsl2' '22.3.0-wsl2')
declare -a target_version=('8' '9')
declare -i length=${#mesa_version[@]}

for (( i = 0; i < length; i++ )); do

  if [[ ${VERSION_ID} == ${target_version[i]}* && $(sudo dnf info --installed mesa-libGL | grep -c "${mesa_version[i]}") == 0 ]]; then
    sudo dnf -y install 'dnf-command(versionlock)'
    sudo dnf versionlock delete mesa-dri-drivers mesa-libGL mesa-filesystem mesa-libglapi mesa-vdpau-drivers mesa-libEGL mesa-libgbm mesa-libxatracker mesa-vulkan-drivers
    curl -s https://packagecloud.io/install/repositories/whitewaterfoundry/pengwin-enterprise/script.rpm.sh | sudo bash
    sudo dnf -y install --allowerasing --nogpgcheck mesa-dri-drivers-"${mesa_version[i]}".el"${target_version[i]}" mesa-libGL-"${mesa_version[i]}".el"${target_version[i]}" mesa-vdpau-drivers-"${mesa_version[i]}".el"${target_version[i]}" mesa-libEGL-"${mesa_version[i]}".el"${target_version[i]}" mesa-libgbm-"${mesa_version[i]}".el"${target_version[i]}" mesa-libxatracker-"${mesa_version[i]}".el"${target_version[i]}" mesa-vulkan-drivers-"${mesa_version[i]}".el"${target_version[i]}" glx-utils
    sudo dnf -y install --allowerasing --nogpgcheck libva-utils
    sudo dnf versionlock add mesa-dri-drivers mesa-libGL mesa-filesystem mesa-libglapi mesa-vdpau-drivers mesa-libEGL mesa-libgbm mesa-libxatracker mesa-vulkan-drivers
  fi
done

if [[ $(id | grep -c video) == 0 ]]; then
  sudo /usr/sbin/groupadd -g 44 wsl-video
  sudo /usr/sbin/usermod -aG wsl-video "$(whoami)"
  sudo /usr/sbin/usermod -aG video "$(whoami)"
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

if [[ ${VERSION_ID} == "7"* ]]; then
  sudo curl -L -f "${base_url}/linux_files/systemctl.py" -o /usr/bin/wslsystemctl
  sudo chmod +x /usr/bin/wslsystemctl
else
  sudo curl -L -f "${base_url}/linux_files/systemctl3.py" -o /usr/bin/wslsystemctl
  sudo curl -L -f "${base_url}/linux_files/journalctl3.py" -o /usr/bin/wsljournalctl

  sudo chmod +x /usr/bin/wslsystemctl
  sudo chmod +x /usr/bin/wsljournalctl
fi

sudo chmod u+x /usr/local/bin/start-systemd

echo -n -e '\033]9;4;0;100\033\\'
