#!/bin/bash

# Clean up any cached files from previous runs
rm -f /tmp/pyrodactyl-lib.sh /tmp/pyrodactyl-*.sh 2>/dev/null || true

set -e

######################################################################################
#                                                                                    #
# Pyrodactyl Installer                                                               #
#                                                                                    #
# One-command installer for Pyrodactyl Panel and Elytra Daemon                       #
#                                                                                    #
# Copyright (C) 2025, Muspelheim Hosting                                             #
#                                                                                    #
# https://github.com/Muspelheim-Hosting/pyrodactyl-installer                         #
#                                                                                    #
######################################################################################

export GITHUB_SOURCE="${GITHUB_SOURCE:-main}"
export SCRIPT_RELEASE="${SCRIPT_RELEASE:-v1.2.0}"
export GITHUB_BASE_URL="${GITHUB_BASE_URL:-https://raw.githubusercontent.com/Muspelheim-Hosting/pyrodactyl-installer}"

LOG_PATH="/var/log/pyrodactyl-installer.log"

# ------------------ Utility Functions ----------------- #

# Color definitions - Orange gradient for flame effect
export COLOR_DARK_ORANGE='\033[38;5;208m'
export COLOR_ORANGE='\033[38;5;214m'
export COLOR_LIGHT_ORANGE='\033[38;5;220m'
export COLOR_YELLOW='\033[1;33m'
export COLOR_GREEN='\033[0;32m'
export COLOR_RED='\033[0;31m'
export COLOR_BLUE='\033[0;34m'
export COLOR_CYAN='\033[0;36m'
export COLOR_NC='\033[0m'

# Enhanced color palette
export COLOR_FIRE_RED='\033[38;5;196m'
export COLOR_FIRE_ORANGE='\033[38;5;202m'
export COLOR_GOLD='\033[38;5;220m'
export COLOR_LIGHT_GOLD='\033[38;5;228m'
export COLOR_WHITE='\033[1;37m'
export COLOR_GRAY='\033[90m'
export COLOR_LIGHT_GRAY='\033[37m'
export COLOR_PURPLE='\033[38;5;141m'
export COLOR_PINK='\033[38;5;205m'
export COLOR_TEAL='\033[38;5;45m'
export COLOR_LIME='\033[38;5;118m'
export COLOR_SOFT_WHITE='\033[38;5;251m'

# Text formatting
export TEXT_BOLD='\033[1m'
export TEXT_DIM='\033[2m'

# Unicode characters
export BOX_CORNER_TL='╭'
export BOX_CORNER_TR='╮'
export BOX_CORNER_BL='╰'
export BOX_CORNER_BR='╯'
export BOX_HORIZ='─'
export BOX_VERT='│'
export ARROW_RIGHT='→'
export CHECK_MARK='✓'
export X_MARK='✗'
export BULLET='•'
export DIAMOND='◆'
export STAR='★'
export FIRE='🔥'
export ROCKET='🚀'
export GEAR='⚙'
export LOCK='🔒'
export KEY='🔑'
export GLOBE='🌐'
export DATABASE='🗄'
export SERVER='🖥'
export PACKAGE='📦'
export WARNING='⚠'
export INFO='ℹ'
export QUESTION='?'

# Smooth flame gradient colors (top to bottom) - red to gold
export GRADIENT_1='\033[38;5;196m'   # Deep red
export GRADIENT_2='\033[38;5;202m'   # Red-orange
export GRADIENT_3='\033[38;5;208m'   # Dark orange
export GRADIENT_4='\033[38;5;214m'   # Orange
export GRADIENT_5='\033[38;5;220m'   # Light orange
export GRADIENT_6='\033[38;5;221m'   # Gold-orange
export GRADIENT_7='\033[38;5;222m'   # Gold
export GRADIENT_8='\033[38;5;226m'   # Yellow-gold
export GRADIENT_9='\033[38;5;227m'   # Bright gold
export GRADIENT_10='\033[38;5;228m'  # Light gold
export GRADIENT_11='\033[38;5;229m'  # Pale gold

output() {
  echo -e "* $1"
}

success() {
  echo ""
  echo -e "* ${COLOR_GREEN}SUCCESS${COLOR_NC}: $1"
  echo ""
}

error() {
  echo ""
  echo -e "* ${COLOR_RED}ERROR${COLOR_NC}: $1" 1>&2
  echo ""
}

warning() {
  echo ""
  echo -e "* ${COLOR_YELLOW}WARNING${COLOR_NC}: $1"
  echo ""
}

# Error handler - called when script exits with error
error_handler() {
  local exit_code=$?
  local line_no=$1

  if [ $exit_code -ne 0 ]; then
    echo ""
    echo -e "* ${COLOR_RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_NC}"
    echo -e "* ${COLOR_RED}INSTALLATION FAILED${COLOR_NC}"
    echo -e "* ${COLOR_RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_NC}"
    echo ""
    echo -e "* ${COLOR_YELLOW}Exit code:${COLOR_NC} $exit_code"
    [ -n "$line_no" ] && echo -e "* ${COLOR_YELLOW}Failed at line:${COLOR_NC} $line_no"
    echo ""
    echo -e "* ${COLOR_CYAN}Troubleshooting tips:${COLOR_NC}"
    echo -e "  1. Check the log file: ${COLOR_ORANGE}$LOG_PATH${COLOR_NC}"
    echo -e "  2. Ensure you have a stable internet connection"
    echo -e "  3. Verify your GitHub token has 'repo' scope"
    echo -e "  4. Check that your OS is supported"
    echo ""
    echo -e "* ${COLOR_CYAN}For help, visit:${COLOR_NC} https://github.com/Muspelheim-Hosting/pyrodactyl-installer/issues"
    echo ""
    echo -e "* ${COLOR_RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_NC}"
    echo ""
  fi
}

# Set up error trap
trap 'error_handler $LINENO' ERR

# Cleanup function for temporary files
print_brake() {
  local char="${2:-─}"
  for ((n = 0; n < $1; n++)); do
    echo -n "$char"
  done
  echo ""
}

print_header() {
  clear 2>/dev/null || true
  echo ""

  # Top decorative border with flame gradient
  echo -e "${GRADIENT_1}    ╔══════════════════════════════════════════════════════════════════════════════════════╗${COLOR_NC}"
  echo -e "${GRADIENT_1}    ║${COLOR_NC}                                                                                      ${GRADIENT_1}║${COLOR_NC}"

  # ASCII Art with smooth flame gradient
  echo -e "${GRADIENT_1}    ║${COLOR_NC}  ${GRADIENT_1}███╗   ███╗${COLOR_NC} ${GRADIENT_2}██╗   ██╗${COLOR_NC} ${GRADIENT_3}███████╗${COLOR_NC} ${GRADIENT_4}██████╗ ${COLOR_NC} ${GRADIENT_5}███████╗${COLOR_NC} ${GRADIENT_6}██╗${COLOR_NC}     ${GRADIENT_7}██╗  ██╗${COLOR_NC} ${GRADIENT_8}███████╗${COLOR_NC} ${GRADIENT_9}██╗${COLOR_NC} ${GRADIENT_10}███╗   ███╗${COLOR_NC}  ${GRADIENT_1}║${COLOR_NC}"
  echo -e "${GRADIENT_1}    ║${COLOR_NC}  ${GRADIENT_1}████╗ ████║${COLOR_NC} ${GRADIENT_2}██║   ██║${COLOR_NC} ${GRADIENT_3}██╔════╝${COLOR_NC} ${GRADIENT_4}██╔══██╗${COLOR_NC} ${GRADIENT_5}██╔════╝${COLOR_NC} ${GRADIENT_6}██║${COLOR_NC}     ${GRADIENT_7}██║  ██║${COLOR_NC} ${GRADIENT_8}██╔════╝${COLOR_NC} ${GRADIENT_9}██║${COLOR_NC} ${GRADIENT_10}████╗ ████║${COLOR_NC}  ${GRADIENT_1}║${COLOR_NC}"
  echo -e "${GRADIENT_1}    ║${COLOR_NC}  ${GRADIENT_1}██╔████╔██║${COLOR_NC} ${GRADIENT_2}██║   ██║${COLOR_NC} ${GRADIENT_3}███████╗${COLOR_NC} ${GRADIENT_4}██████╔╝${COLOR_NC} ${GRADIENT_5}█████╗  ${COLOR_NC} ${GRADIENT_6}██║${COLOR_NC}     ${GRADIENT_7}███████║${COLOR_NC} ${GRADIENT_8}█████╗  ${COLOR_NC} ${GRADIENT_9}██║${COLOR_NC} ${GRADIENT_10}██╔████╔██║${COLOR_NC}  ${GRADIENT_1}║${COLOR_NC}"
  echo -e "${GRADIENT_1}    ║${COLOR_NC}  ${GRADIENT_1}██║╚██╔╝██║${COLOR_NC} ${GRADIENT_2}██║   ██║${COLOR_NC} ${GRADIENT_3}╚════██║${COLOR_NC} ${GRADIENT_4}██╔═══╝ ${COLOR_NC} ${GRADIENT_5}██╔══╝  ${COLOR_NC} ${GRADIENT_6}██║${COLOR_NC}     ${GRADIENT_7}██╔══██║${COLOR_NC} ${GRADIENT_8}██╔══╝  ${COLOR_NC} ${GRADIENT_9}██║${COLOR_NC} ${GRADIENT_10}██║╚██╔╝██║${COLOR_NC}  ${GRADIENT_1}║${COLOR_NC}"
  echo -e "${GRADIENT_1}    ║${COLOR_NC}  ${GRADIENT_1}██║ ╚═╝ ██║${COLOR_NC} ${GRADIENT_2}╚██████╔╝${COLOR_NC} ${GRADIENT_3}███████║${COLOR_NC} ${GRADIENT_4}██║     ${COLOR_NC} ${GRADIENT_5}███████╗${COLOR_NC} ${GRADIENT_6}███████╗${COLOR_NC} ${GRADIENT_7}██║  ██║${COLOR_NC} ${GRADIENT_8}███████╗${COLOR_NC} ${GRADIENT_9}██║${COLOR_NC} ${GRADIENT_10}██║ ╚═╝ ██║${COLOR_NC}  ${GRADIENT_1}║${COLOR_NC}"
  echo -e "${GRADIENT_1}    ║${COLOR_NC}  ${GRADIENT_1}╚═╝     ╚═╝${COLOR_NC} ${GRADIENT_2} ╚═════╝ ${COLOR_NC} ${GRADIENT_3}╚══════╝${COLOR_NC} ${GRADIENT_4}╚═╝     ${COLOR_NC} ${GRADIENT_5}╚══════╝${COLOR_NC} ${GRADIENT_6}╚══════╝${COLOR_NC} ${GRADIENT_7}╚═╝  ╚═╝${COLOR_NC} ${GRADIENT_8}╚══════╝${COLOR_NC} ${GRADIENT_9}╚═╝${COLOR_NC} ${GRADIENT_10}╚═╝     ╚═╝${COLOR_NC}  ${GRADIENT_1}║${COLOR_NC}"

  # Separator
  echo -e "${GRADIENT_1}    ║${COLOR_NC}                                                                                      ${GRADIENT_1}║${COLOR_NC}"
  echo -e "${GRADIENT_5}    ║${COLOR_NC}                    ${TEXT_BOLD}${COLOR_GOLD}🔥  Pyrodactyl Installation Manager  🔥${COLOR_NC}${TEXT_BOLD}                         ${GRADIENT_5}║${COLOR_NC}"

  # Bottom border
  echo -e "${GRADIENT_11}    ╚══════════════════════════════════════════════════════════════════════════════════════╝${COLOR_NC}"

  # Version info with decorative elements
  echo ""
  echo -e "    ${COLOR_FIRE_ORANGE}${BOX_CORNER_TL}${BOX_HORIZ}${BOX_HORIZ}${BOX_HORIZ}${BOX_CORNER_TR}${COLOR_NC}  ${COLOR_GOLD}Version:${COLOR_NC} ${COLOR_WHITE}${SCRIPT_RELEASE}${COLOR_NC}"
  echo -e "    ${COLOR_FIRE_ORANGE}${BOX_VERT}${COLOR_NC} ${COLOR_ORANGE}⚡${COLOR_NC} ${COLOR_FIRE_ORANGE}${BOX_VERT}${COLOR_NC}  ${COLOR_GOLD}By:${COLOR_NC} ${COLOR_WHITE}Muspelheim Hosting${COLOR_NC}"
  echo -e "    ${COLOR_FIRE_ORANGE}${BOX_CORNER_BL}${BOX_HORIZ}${BOX_HORIZ}${BOX_HORIZ}${BOX_CORNER_BR}${COLOR_NC}"
  echo ""
}

print_flame() {
  local message="$1"
  local icon="${2:-$FIRE}"

  echo ""
  echo -e "  ${COLOR_FIRE_ORANGE}╭────────────────────────────────────────────────────────────────────╮${COLOR_NC}"
  echo -e "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}  ${COLOR_GOLD}${icon}${COLOR_NC}  ${TEXT_BOLD}${COLOR_WHITE}${message}${COLOR_NC}"
  echo -e "  ${COLOR_FIRE_ORANGE}╰────────────────────────────────────────────────────────────────────╯${COLOR_NC}"
  echo ""
}

# Cleanup function for temporary files
cleanup() {
  rm -f /tmp/pyrodactyl-lib.sh 2>/dev/null || true
  rm -f /tmp/lib.sh 2>/dev/null || true
}

# Set trap to cleanup on exit
trap cleanup EXIT INT TERM

# Check for root
check_root() {
  if [[ $EUID -ne 0 ]]; then
    error "This script must be executed with root privileges."
    exit 1
  fi
}

# Check for curl
check_curl() {
  if ! [ -x "$(command -v curl)" ]; then
    error "curl is required in order for this script to work."
    error "Install using: apt install curl (Debian/Ubuntu) or dnf install curl (RHEL)"
    exit 1
  fi
}

# Download and source library
load_library() {
  # Always remove old lib.sh before downloading
  [ -f /tmp/pyrodactyl-lib.sh ] && rm -rf /tmp/pyrodactyl-lib.sh

  output "Loading installer library..."

  if ! curl -sSL -o /tmp/pyrodactyl-lib.sh "$GITHUB_BASE_URL/$GITHUB_SOURCE/lib/lib.sh"; then
    error "Failed to download installer library."
    error "Please check your internet connection and try again."
    exit 1
  fi

  # shellcheck source=/dev/null
  if ! source /tmp/pyrodactyl-lib.sh; then
    error "Failed to load installer library."
    exit 1
  fi
}

# Log execution
log_execution() {
  echo -e "\n\n* pyrodactyl-installer $(date) \n\n" >> "$LOG_PATH" 2>/dev/null || true
}

# Execute UI script
execute_ui() {
  local script_name="$1"
  local next_script="${2:-}"

  run_ui "$script_name" 2>&1 | tee -a "$LOG_PATH"
  local exit_code=${PIPESTATUS[0]}

  # Exit if the installation failed
  if [ $exit_code -ne 0 ]; then
    exit $exit_code
  fi

  if [[ -n "$next_script" ]]; then
    echo ""
    local CONFIRM=""
    while [[ "$CONFIRM" != "y" && "$CONFIRM" != "n" ]]; do
      echo -n "* Installation of $script_name completed. Do you want to proceed to $next_script installation? [y/N]: "
      read -r CONFIRM
      CONFIRM=$(echo "$CONFIRM" | tr '[:upper:]' '[:lower:]')
      [ -z "$CONFIRM" ] && CONFIRM="n"
      if [[ "$CONFIRM" != "y" && "$CONFIRM" != "n" ]]; then
        error "Invalid input. Please enter 'y' or 'n'."
      fi
    done
    if [[ "$CONFIRM" == "y" ]]; then
      execute_ui "$next_script"
    else
      warning "Installation of $next_script aborted."
      exit 1
    fi
  fi
}

# Show welcome screen
# Check installations and set state variables
check_installations() {
  PANEL_INSTALLED=false
  ELYTRA_INSTALLED=false
  PANEL_VERSION=""
  ELYTRA_VERSION=""
  PANEL_UPDATER_INSTALLED=false
  ELYTRA_UPDATER_INSTALLED=false

  if [ -d "/var/www/pyrodactyl" ]; then
    PANEL_INSTALLED=true
    if [ -f "/var/www/pyrodactyl/config/app.php" ]; then
      PANEL_VERSION=$(grep "'version'" "/var/www/pyrodactyl/config/app.php" 2>/dev/null | head -1 | cut -d"'" -f4 || echo "")
    fi
  fi

  if [ -f "/usr/local/bin/elytra" ]; then
    ELYTRA_INSTALLED=true
    if [ -f "/etc/pyrodactyl/elytra-version" ]; then
      ELYTRA_VERSION=$(cat "/etc/pyrodactyl/elytra-version" 2>/dev/null || echo "")
    fi
  fi

  if systemctl is-enabled --quiet pyrodactyl-panel-auto-update.timer 2>/dev/null; then
    PANEL_UPDATER_INSTALLED=true
  fi

  if systemctl is-enabled --quiet pyrodactyl-elytra-auto-update.timer 2>/dev/null; then
    ELYTRA_UPDATER_INSTALLED=true
  fi
}

show_welcome() {
  print_header

  # Detect OS if possible
  local os_info="Unknown"
  if [ -f /etc/os-release ]; then
    # shellcheck source=/dev/null
    source /etc/os-release
    os_info="$NAME $VERSION_ID"
  fi

  echo -e "  ${COLOR_FIRE_ORANGE}${SERVER}${COLOR_NC} ${COLOR_GOLD}Operating System:${COLOR_NC} ${COLOR_WHITE}${os_info}${COLOR_NC}"
  echo ""

  # System Status Box
  echo -e "  ${COLOR_FIRE_ORANGE}╭────────────────────────── System Status ───────────────────────────╮${COLOR_NC}"

  # Check and display installed components
  check_installations

  if [ "$PANEL_INSTALLED" == true ]; then
    echo -e "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}  ${COLOR_LIME}${CHECK_MARK}${COLOR_NC} ${COLOR_SOFT_WHITE}Panel installed${COLOR_NC}${PANEL_VERSION:+ ${COLOR_GRAY}(${PANEL_VERSION})${COLOR_NC}}                               ${COLOR_FIRE_ORANGE}│${COLOR_NC}"
  else
    echo -e "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}  ${COLOR_RED}${X_MARK}${COLOR_NC} ${COLOR_GRAY}Panel not installed                                     ${COLOR_FIRE_ORANGE}│${COLOR_NC}"
  fi

  if [ "$ELYTRA_INSTALLED" == true ]; then
    echo -e "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}  ${COLOR_LIME}${CHECK_MARK}${COLOR_NC} ${COLOR_SOFT_WHITE}Elytra installed${COLOR_NC}${ELYTRA_VERSION:+ ${COLOR_GRAY}(${ELYTRA_VERSION})${COLOR_NC}}                              ${COLOR_FIRE_ORANGE}│${COLOR_NC}"
  else
    echo -e "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}  ${COLOR_RED}${X_MARK}${COLOR_NC} ${COLOR_GRAY}Elytra not installed                                    ${COLOR_FIRE_ORANGE}│${COLOR_NC}"
  fi

  if [ "$PANEL_UPDATER_INSTALLED" == true ]; then
    echo -e "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}  ${COLOR_LIME}${CHECK_MARK}${COLOR_NC} ${COLOR_SOFT_WHITE}Panel auto-updater enabled                              ${COLOR_FIRE_ORANGE}│${COLOR_NC}"
  else
    echo -e "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}  ${COLOR_RED}${X_MARK}${COLOR_NC} ${COLOR_GRAY}Panel auto-updater not installed                        ${COLOR_FIRE_ORANGE}│${COLOR_NC}"
  fi

  if [ "$ELYTRA_UPDATER_INSTALLED" == true ]; then
    echo -e "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}  ${COLOR_LIME}${CHECK_MARK}${COLOR_NC} ${COLOR_SOFT_WHITE}Elytra auto-updater enabled                             ${COLOR_FIRE_ORANGE}│${COLOR_NC}"
  else
    echo -e "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}  ${COLOR_RED}${X_MARK}${COLOR_NC} ${COLOR_GRAY}Elytra auto-updater not installed                       ${COLOR_FIRE_ORANGE}│${COLOR_NC}"
  fi

  echo -e "  ${COLOR_FIRE_ORANGE}╰────────────────────────────────────────────────────────────────────╯${COLOR_NC}"
  echo ""
}

# ------------------ Direct Update Functions ----------------- #

run_panel_update() {
  print_header
  print_flame "Update Pyrodactyl Panel"

  if [ ! -d "/var/www/pyrodactyl" ]; then
    error "Panel is not installed at /var/www/pyrodactyl"
    return 1
  fi

  # Check if auto-updater env file exists
  if [ -f "/etc/pyrodactyl/auto-update-panel.env" ]; then
    output "Using existing auto-updater configuration..."
  else
    # Create temporary env file with defaults
    mkdir -p /etc/pyrodactyl
    echo "PANEL_REPO=\"pyrodactyl-oss/pyrodactyl\"" > /etc/pyrodactyl/auto-update-panel.env
    echo "GITHUB_TOKEN=\"\"" >> /etc/pyrodactyl/auto-update-panel.env
    chmod 600 /etc/pyrodactyl/auto-update-panel.env
  fi

  output "Downloading and running panel auto-updater..."
  echo ""

  # Download and run the auto-update script
  local temp_script
  temp_script=$(mktemp)
  if ! curl -fsSL -o "$temp_script" "$GITHUB_BASE_URL/$GITHUB_SOURCE/installers/auto-update-panel.sh"; then
    error "Failed to download update script"
    rm -f "$temp_script"
    return 1
  fi

  chmod +x "$temp_script"
  "$temp_script" || {
    error "Update failed"
    rm -f "$temp_script"
    return 1
  }

  rm -f "$temp_script"
  echo ""
  output "Press Enter to continue..."
  read -r
}

run_elytra_update() {
  print_header
  print_flame "Update Elytra Daemon"

  if [ ! -f "/usr/local/bin/elytra" ]; then
    error "Elytra is not installed at /usr/local/bin/elytra"
    return 1
  fi

  # Check if auto-updater env file exists
  if [ -f "/etc/pyrodactyl/auto-update-elytra.env" ]; then
    output "Using existing auto-updater configuration..."
  else
    # Create temporary env file with defaults
    mkdir -p /etc/pyrodactyl
    echo "ELYTRA_REPO=\"pyrohost/elytra\"" > /etc/pyrodactyl/auto-update-elytra.env
    echo "GITHUB_TOKEN=\"\"" >> /etc/pyrodactyl/auto-update-elytra.env
    chmod 600 /etc/pyrodactyl/auto-update-elytra.env
  fi

  output "Downloading and running Elytra auto-updater..."
  echo ""

  # Download and run the auto-update script
  local temp_script
  temp_script=$(mktemp)
  if ! curl -fsSL -o "$temp_script" "$GITHUB_BASE_URL/$GITHUB_SOURCE/installers/auto-update-elytra.sh"; then
    error "Failed to download update script"
    rm -f "$temp_script"
    return 1
  fi

  chmod +x "$temp_script"
  "$temp_script" || {
    error "Update failed"
    rm -f "$temp_script"
    return 1
  }

  rm -f "$temp_script"
  echo ""
  output "Press Enter to continue..."
  read -r
}

run_both_updates() {
  print_header
  print_flame "Update Both Panel and Elytra"

  run_panel_update
  echo ""
  run_elytra_update
}



# Show main menu
show_menu() {
  local choice=""

  while true; do
    show_welcome

    # Main Menu Box
    echo -e "  ${COLOR_FIRE_ORANGE}╭────────────────────────── Main Menu ───────────────────────────────╮${COLOR_NC}"
    echo -e "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}                                                                    ${COLOR_FIRE_ORANGE}│${COLOR_NC}"
    echo -e "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}  ${COLOR_GOLD}${PACKAGE}${COLOR_NC}  ${TEXT_BOLD}${COLOR_WHITE}Installation Options${COLOR_NC}                                    ${COLOR_FIRE_ORANGE}│${COLOR_NC}"
    echo -e "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}                                                                    ${COLOR_FIRE_ORANGE}│${COLOR_NC}"
    echo -e "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}     ${COLOR_ORANGE}[${COLOR_WHITE}0${COLOR_ORANGE}]${COLOR_NC} ${COLOR_SOFT_WHITE}Install Pyrodactyl Panel${COLOR_NC}                              ${COLOR_FIRE_ORANGE}│${COLOR_NC}"
    echo -e "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}     ${COLOR_ORANGE}[${COLOR_WHITE}1${COLOR_ORANGE}]${COLOR_NC} ${COLOR_SOFT_WHITE}Install Elytra Daemon${COLOR_NC}                                 ${COLOR_FIRE_ORANGE}│${COLOR_NC}"
    echo -e "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}     ${COLOR_ORANGE}[${COLOR_WHITE}2${COLOR_ORANGE}]${COLOR_NC} ${COLOR_SOFT_WHITE}Install both Panel and Elytra (same machine)${COLOR_NC}          ${COLOR_FIRE_ORANGE}│${COLOR_NC}"
    echo -e "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}                                                                    ${COLOR_FIRE_ORANGE}│${COLOR_NC}"

    # Update options - gray out if not installed
    echo -e "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}  ${COLOR_GOLD}${ROCKET}${COLOR_NC}  ${TEXT_BOLD}${COLOR_WHITE}Update Options${COLOR_NC}                                        ${COLOR_FIRE_ORANGE}│${COLOR_NC}"
    echo -e "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}                                                                    ${COLOR_FIRE_ORANGE}│${COLOR_NC}"

    if [ "$PANEL_INSTALLED" == true ]; then
      echo -e "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}     ${COLOR_ORANGE}[${COLOR_WHITE}3${COLOR_ORANGE}]${COLOR_NC} ${COLOR_SOFT_WHITE}Update Pyrodactyl Panel${COLOR_NC}                               ${COLOR_FIRE_ORANGE}│${COLOR_NC}"
    else
      echo -e "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}     ${COLOR_GRAY}[3] Update Pyrodactyl Panel (not installed)${COLOR_NC}           ${COLOR_FIRE_ORANGE}│${COLOR_NC}"
    fi

    if [ "$ELYTRA_INSTALLED" == true ]; then
      echo -e "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}     ${COLOR_ORANGE}[${COLOR_WHITE}4${COLOR_ORANGE}]${COLOR_NC} ${COLOR_SOFT_WHITE}Update Elytra Daemon${COLOR_NC}                                  ${COLOR_FIRE_ORANGE}│${COLOR_NC}"
    else
      echo -e "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}     ${COLOR_GRAY}[4] Update Elytra Daemon (not installed)${COLOR_NC}              ${COLOR_FIRE_ORANGE}│${COLOR_NC}"
    fi

    if [ "$PANEL_INSTALLED" == true ] && [ "$ELYTRA_INSTALLED" == true ]; then
      echo -e "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}     ${COLOR_ORANGE}[${COLOR_WHITE}5${COLOR_ORANGE}]${COLOR_NC} ${COLOR_SOFT_WHITE}Update both Panel and Elytra${COLOR_NC}                          ${COLOR_FIRE_ORANGE}│${COLOR_NC}"
    else
      echo -e "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}     ${COLOR_GRAY}[5] Update both Panel and Elytra (not available)${COLOR_NC}      ${COLOR_FIRE_ORANGE}│${COLOR_NC}"
    fi

    echo -e "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}                                                                    ${COLOR_FIRE_ORANGE}│${COLOR_NC}"
    echo -e "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}  ${COLOR_GOLD}${GEAR}${COLOR_NC}  ${TEXT_BOLD}${COLOR_WHITE}Management${COLOR_NC}                                            ${COLOR_FIRE_ORANGE}│${COLOR_NC}"
    echo -e "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}                                                                    ${COLOR_FIRE_ORANGE}│${COLOR_NC}"
    echo -e "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}     ${COLOR_ORANGE}[${COLOR_WHITE}6${COLOR_ORANGE}]${COLOR_NC} ${COLOR_SOFT_WHITE}Auto Updater Management${COLOR_NC}                               ${COLOR_FIRE_ORANGE}│${COLOR_NC}"
    echo -e "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}     ${COLOR_ORANGE}[${COLOR_WHITE}7${COLOR_ORANGE}]${COLOR_NC} ${COLOR_SOFT_WHITE}Uninstall Pyrodactyl / Elytra${COLOR_NC}                         ${COLOR_FIRE_ORANGE}│${COLOR_NC}"
    echo -e "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}                                                                    ${COLOR_FIRE_ORANGE}│${COLOR_NC}"
    echo -e "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}  ${COLOR_GOLD}${DIAMOND}${COLOR_NC}  ${COLOR_ORANGE}[${COLOR_WHITE}8${COLOR_ORANGE}]${COLOR_NC} ${COLOR_SOFT_WHITE}Exit${COLOR_NC}                                                  ${COLOR_FIRE_ORANGE}│${COLOR_NC}"
    echo -e "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}                                                                    ${COLOR_FIRE_ORANGE}│${COLOR_NC}"
    echo -e "  ${COLOR_FIRE_ORANGE}╰────────────────────────────────────────────────────────────────────╯${COLOR_NC}"
    echo ""

    echo -ne "  ${COLOR_GOLD}${ARROW_RIGHT}${COLOR_NC} ${COLOR_WHITE}Select an option [0-8]:${COLOR_NC} "
    read -r choice

    case "$choice" in
      0)
        execute_ui "panel"
        continue
        ;;
      1)
        execute_ui "elytra"
        continue
        ;;
      2)
        execute_ui "both"
        continue
        ;;
      3)
        if [ "$PANEL_INSTALLED" == false ]; then
          echo ""
          output_error "Pyrodactyl Panel is not installed"
          echo ""
          sleep 2
          continue
        fi
        run_panel_update
        continue
        ;;
      4)
        if [ "$ELYTRA_INSTALLED" == false ]; then
          echo ""
          output_error "Elytra Daemon is not installed"
          echo ""
          sleep 2
          continue
        fi
        run_elytra_update
        continue
        ;;
      5)
        if [ "$PANEL_INSTALLED" == false ] || [ "$ELYTRA_INSTALLED" == false ]; then
          echo ""
          output_error "Both Panel and Elytra must be installed to use this option"
          echo ""
          sleep 2
          continue
        fi
        run_both_updates
        continue
        ;;
      6)
        execute_ui "auto-updater-menu"
        continue
        ;;
      7)
        execute_ui "uninstall"
        continue
        ;;
      8)
        echo ""
        echo -e "  ${COLOR_GOLD}${FIRE}${COLOR_NC} ${COLOR_SOFT_WHITE}Thank you for using Pyrodactyl Installer!${COLOR_NC}"
        echo ""
        exit 0
        ;;
      *)
        echo ""
        output_error "Invalid option. Please select 0-8."
        echo ""
        sleep 1
        ;;
    esac
  done
}

# Main function
main() {
  check_root
  check_curl
  load_library
  log_execution
  show_welcome

  # Run menu/installation
  if show_menu; then
    echo ""
    print_flame "Thank you for using Pyrodactyl Installer!"
  fi

  # Always show log location at the end
  echo ""
  output "Installation log saved to: ${COLOR_ORANGE}$LOG_PATH${COLOR_NC}"
  echo ""
}

# Run main
main "$@"
