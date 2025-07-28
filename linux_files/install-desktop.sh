#!/bin/bash
#
# install-desktop.sh - Pengwin Enterprise Desktop Setup Script
#
# This script provides an interactive setup for configuring a desktop environment
# in Pengwin Enterprise WSL distribution. It handles user input for hostname,
# RDP port, listen port, and desktop environment selection.
#
# Globals:
#   PENGWIN_SETUP_TITLE - Title for whiptail dialogs
#   NEWT_COLORS - Color scheme for newt/whiptail dialogs
# Arguments:
#   None
# Returns:
#   0 on success, 1 on error or user cancellation

set -euo pipefail

# Constants
readonly PENGWIN_SETUP_TITLE="Pengwin Setup"
readonly DEFAULT_HOSTNAME="pengwinent"
readonly DEFAULT_RDP_PORT="3396"
readonly DEFAULT_LISTEN_PORT="3346"
readonly DEFAULT_LOCALE="en_US.UTF-8"

# Color scheme for whiptail dialogs
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

# Run update script
function run_update_script() {
  if command -v update.sh >/dev/null 2>&1; then
    echo "Running update script..."
    if ! update.sh; then
      echo "Warning: Update script failed, continuing..." >&2
    fi
  else
    echo "Update script not found, skipping..."
  fi
}

# Install required packages for the user interface
function install_ui_dependencies() {
  if ! sudo yum -y install newt ncurses dialog; then
    echo "Error: Failed to install UI dependencies" >&2
    return 1
  fi
}

# Get hostname from user input
function get_hostname_input() {
  local hostname
  if ! hostname=$(whiptail --backtitle "${PENGWIN_SETUP_TITLE}" \
    --title "Enter the desired hostname that will identify this distribution instead of IP address" \
    --inputbox "hostname: " 8 100 "${DEFAULT_HOSTNAME}" 3>&1 1>&2 2>&3); then
    echo "Error: Hostname input cancelled" >&2
    return 1
  fi

  if [[ -z "${hostname}" ]]; then
    echo "Error: Hostname cannot be empty" >&2
    return 1
  fi

  echo "${hostname}"
}

# Get RDP port from user input
function get_rdp_port_input() {
  local port
  if ! port=$(whiptail --backtitle "${PENGWIN_SETUP_TITLE}" \
    --title "Enter the desired RDP Port" \
    --inputbox "RDP Port: " 8 50 "${DEFAULT_RDP_PORT}" 3>&1 1>&2 2>&3); then
    echo "Error: RDP port input cancelled" >&2
    return 1
  fi

  if [[ -z "${port}" ]]; then
    echo "Error: RDP port cannot be empty" >&2
    return 1
  fi

  echo "${port}"
}

# Get listen port from user input
function get_listen_port_input() {
  local listen_port
  if ! listen_port=$(whiptail --backtitle "${PENGWIN_SETUP_TITLE}" \
    --title "Enter the desired session manager Listen Port" \
    --inputbox "Listen Port: " 8 70 "${DEFAULT_LISTEN_PORT}" 3>&1 1>&2 2>&3); then
    echo "Error: Listen port input cancelled" >&2
    return 1
  fi

  if [[ -z "${listen_port}" ]]; then
    echo "Error: Listen port cannot be empty" >&2
    return 1
  fi

  echo "${listen_port}"
}

# Get desktop environment selection from user
function get_desktop_choice() {
  local desktop_choice
  if ! desktop_choice=$(whiptail --backtitle "${PENGWIN_SETUP_TITLE}" \
    --title "Desktop Selection" --radiolist --separate-output \
    "Choose your desired Desktop Environment\n[SPACE to select, ENTER to confirm]:" \
    12 45 2 \
    "GNOME" "GNOME Desktop Environment   " on \
    "Xfce" "XFCE 4 Desktop" off 3>&1 1>&2 2>&3); then
    echo "Error: Desktop selection cancelled" >&2
    return 1
  fi

  if [[ -z "${desktop_choice}" ]]; then
    echo "Error: No desktop environment selected" >&2
    return 1
  fi

  echo "${desktop_choice}"
}

# Source OS release information
function source_os_release() {
  if ! source /etc/os-release; then
    echo "Error: Failed to source /etc/os-release" >&2
    return 1
  fi
}

# Install EPEL repository
function install_epel_repository() {
  local version_major
  version_major=$(echo "${VERSION_ID}" | cut -d '.' -f 1)

  if ! sudo yum install -y "https://dl.fedoraproject.org/pub/epel/epel-release-latest-${version_major}.noarch.rpm"; then
    echo "Error: Failed to install EPEL repository" >&2
    return 1
  fi

  if ! sudo yum install -y epel-release; then
    echo "Error: Failed to install epel-release" >&2
    return 1
  fi
}

# Install required tools
function install_required_tools() {
  if ! sudo yum -y install libva-utils crudini; then
    echo "Error: Failed to install required tools" >&2
    return 1
  fi
}

# Configure WSL settings
function configure_wsl_settings() {
  local hostname="${1}"

  if [[ -z "${hostname}" ]]; then
    echo "Error: hostname parameter is required" >&2
    return 1
  fi

  # Set systemd=true in [boot] section
  if ! sudo crudini --set /etc/wsl.conf boot systemd true; then
    echo "Error: Failed to configure systemd in /etc/wsl.conf" >&2
    return 1
  fi

  # Set hostname in [network] section
  if ! sudo crudini --set /etc/wsl.conf network hostname "${hostname}"; then
    echo "Error: Failed to configure hostname in /etc/wsl.conf" >&2
    return 1
  fi
}

# Install desktop environment
function install_desktop_environment() {
  local desktop_choice="${1}"

  if [[ -z "${desktop_choice}" ]]; then
    echo "Error: desktop_choice parameter is required" >&2
    return 1
  fi

  echo "Installing ${desktop_choice} desktop environment..."

  if ! sudo yum -y group install "${desktop_choice}"; then
    echo "Error: Failed to install ${desktop_choice} desktop environment" >&2
    return 1
  fi
}

# Configure X session
function configure_x_session() {
  local desktop_choice="${1}"

  if [[ -z "${desktop_choice}" ]]; then
    echo "Error: desktop_choice parameter is required" >&2
    return 1
  fi

  # Desktop environment executable mappings
  declare -A desktop_execs
  desktop_execs["GNOME"]="gnome-session"
  desktop_execs["KDE"]="startplasma-x11"
  desktop_execs["Xfce"]="startxfce4"
  desktop_execs["LXDE"]="startlxde"

  local desktop_exec="${desktop_execs[${desktop_choice}]:-}"

  if [[ -z "${desktop_exec}" ]]; then
    echo "Error: Unknown desktop environment: ${desktop_choice}" >&2
    return 1
  fi

  local desktop_exec_path
  if ! desktop_exec_path=$(command -v "${desktop_exec}"); then
    echo "Error: Desktop executable not found: ${desktop_exec}" >&2
    return 1
  fi

  # Create .xsession file
  if ! echo "exec ${desktop_exec_path}" > "${HOME}/.xsession"; then
    echo "Error: Failed to create .xsession file" >&2
    return 1
  fi

  if ! chmod +x "${HOME}/.xsession"; then
    echo "Error: Failed to make .xsession executable" >&2
    return 1
  fi
}

# Configure system locale
function configure_system_locale() {
  if ! sudo localectl set-locale "LANG=${DEFAULT_LOCALE}"; then
    return
  fi
}

# Install and configure RDP services
function install_rdp_services() {
  if ! sudo yum -y install xrdp avahi xorg-x11-xinit-session tigervnc-server; then
    echo "Error: Failed to install RDP services" >&2
    return 1
  fi

  if ! sudo systemctl enable xrdp; then
    echo "Error: Failed to enable xrdp service" >&2
    return 1
  fi

  if ! sudo systemctl enable avahi-daemon; then
    echo "Error: Failed to enable avahi-daemon service" >&2
    return 1
  fi
}

# Configure RDP settings
function configure_rdp_settings() {
  local rdp_port="${1}"
  local listen_port="${2}"

  if [[ -z "${rdp_port}" || -z "${listen_port}" ]]; then
    echo "Error: Both rdp_port and listen_port parameters are required" >&2
    return 1
  fi

  # Configure RDP port
  if ! sudo sed -i "s/port=3389/port=${rdp_port}/" /etc/xrdp/xrdp.ini; then
    echo "Error: Failed to configure RDP port" >&2
    return 1
  fi

  # Configure session manager listen port
  if ! sudo sed -i "s/ListenPort=3350/ListenPort=${listen_port}/" /etc/xrdp/sesman.ini; then
    echo "Error: Failed to configure session manager listen port" >&2
    return 1
  fi
}

# Terminate WSL distribution
function terminate_wsl_distribution() {
  if [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
    wsl.exe --terminate "${WSL_DISTRO_NAME}"
  else
    echo "Warning: WSL_DISTRO_NAME not set, skipping WSL termination" >&2
  fi
}

# Main setup function
function main() {
  echo "Starting Pengwin Enterprise Desktop Setup..."

  # Run update script if available
  run_update_script

  # Install UI dependencies
  install_ui_dependencies || return 1

  # Source OS release information (needed for EPEL installation)
  source_os_release || return 1

  # Get user inputs
  local hostname rdp_port listen_port desktop_choice
  hostname=$(get_hostname_input) || return 1
  rdp_port=$(get_rdp_port_input) || return 1
  listen_port=$(get_listen_port_input) || return 1
  desktop_choice=$(get_desktop_choice) || return 1

  echo "Configuration:"
  echo "  Hostname: ${hostname}"
  echo "  RDP Port: ${rdp_port}"
  echo "  Listen Port: ${listen_port}"
  echo "  Desktop: ${desktop_choice}"

  # Install and configure components
  install_epel_repository || return 1
  install_required_tools || return 1
  configure_wsl_settings "${hostname}" || return 1
  install_desktop_environment "${desktop_choice}" || return 1
  configure_x_session "${desktop_choice}" || return 1
  configure_system_locale
  install_rdp_services || return 1
  configure_rdp_settings "${rdp_port}" "${listen_port}" || return 1

  echo "Setup completed successfully!"
  echo "Terminating WSL distribution to apply changes..."
  terminate_wsl_distribution
}

main "$@"
