#! /bin/bash

update.sh

sudo yum -y install newt

export NEWT_COLORS='
    root=lightgray,black
    roottext=lightgray,black
    shadow=black,gray
    title=magenta,lightgray
    checkbox=lightgray,blue
    actcheckbox=lightgray,magenta
    emptyscale=lightgray,blue
    fullscale=lightgray,magenta
    button=lightgray,magenta
    actbutton=magenta,lightgray
    compactbutton=magenta,lightgray
    listbox=lightgray,blue
    actlistbox=lightgray,magenta
    sellistbox=lightgray,magenta
    actsellistbox=lightgray,magenta
'

readonly PENGWIN_SETUP_TITLE="Pengwin Setup"

hostname=$(whiptail --backtitle "${PENGWIN_SETUP_TITLE}" --title "Enter the desired hostname that will identify this distribution instead of IP address" --inputbox "hostname: " 8 100 "pengwinent" 3>&1 1>&2 2>&3)
if [[ -z ${hostname} ]]; then
  exit 1
fi

port=$(whiptail --backtitle "${PENGWIN_SETUP_TITLE}"  --title "Enter the desired RDP Port" --inputbox "RDP Port: " 8 50 "3396" 3>&1 1>&2 2>&3)
if [[ -z ${port} ]]; then
  exit 1
fi

listen_port=$(whiptail --backtitle "${PENGWIN_SETUP_TITLE}" --title "Enter the desired session manager Listen Port" --inputbox "Listen Port: " 8 70 "3346" 3>&1 1>&2 2>&3)
if [[ -z ${listen_port} ]]; then
  exit 1
fi

desktop_choice=$(
  whiptail --backtitle "${PENGWIN_SETUP_TITLE}"  --title "Desktop Selection" --radiolist --separate-output "Choose your desired Desktop Environment\n[SPACE to select, ENTER to confirm]:" 12 45 2 \
    "GNOME" "GNOME Desktop Environment   " on \
    "Xfce" "XFCE 4 Desktop" off 3>&1 1>&2 2>&3
)

exit_status=$?

if [[ ${exit_status} != 0 ]]; then
  exit 1
fi

[ "$(grep -c "^systemd.*" /etc/wsl.conf)" -eq 0 ] && echo -e "\n[boot]\nsystemd=true\n" | sudo tee -a /etc/wsl.conf
[ "$(grep -c "^systemd.*=.*true$" /etc/wsl.conf)" -eq 0 ] && sudo sed -i "s/^systemd.*=.*false$/systemd=true/" /etc/wsl.conf

[ "$(grep -c "^hostname.*" /etc/wsl.conf)" -eq 0 ] && sudo sed -i "/\[network\]/s/.*/&\nhostname=${hostname}/" /etc/wsl.conf

echo "${desktop_choice}"

source /etc/os-release
version_major=$(echo "${VERSION_ID}" | cut -d '.' -f 1)
sudo yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-"${version_major}".noarch.rpm
sudo yum install -y epel-release

sudo yum -y group install "${desktop_choice}"

declare -A desktop_execs

desktop_execs["GNOME"]="gnome-session"
desktop_execs["KDE"]="startplasma-x11"
desktop_execs["Xfce"]="startxfce4"
desktop_execs["LXDE"]="startlxde"

desktop_exec=${desktop_execs[${desktop_choice}]}
echo "exec $(command -v "${desktop_exec}")">"${HOME}"/.xsession
chmod +x "${HOME}"/.xsession

sudo localectl set-locale LANG="en_US.UTF-8"

sudo yum -y install xrdp avahi xorg-x11-xinit-session tigervnc-server
sudo systemctl enable xrdp
sudo systemctl enable avahi-daemon

sudo sed -i "s/port=3389/port=${port}/" /etc/xrdp/xrdp.ini
sudo sed -i "s/ListenPort=3350/ListenPort=${listen_port}/" /etc/xrdp/sesman.ini

wsl.exe --terminate "${WSL_DISTRO_NAME}"
