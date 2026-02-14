#!/bin/bash

set -e

######################################################################################
#                                                                                    #
# Pyrodactyl Uninstallation UI                                                       #
#                                                                                    #
# Copyright (C) 2025, Muspelheim Hosting                                             #
#                                                                                    #
######################################################################################

# Check if lib is loaded, load if not or fail otherwise.
fn_exists() { declare -F "$1" >/dev/null; }
if ! fn_exists lib_loaded; then
  source /tmp/pyrodactyl-lib.sh 2>/dev/null || source <(curl -sSL "${GITHUB_BASE_URL:-"https://raw.githubusercontent.com/Muspelheim-Hosting/pyrodactyl-installer"}/${GITHUB_SOURCE:-"main"}/lib/lib.sh")
  ! fn_exists lib_loaded && echo "* ERROR: Could not load lib script" && exit 1
fi

# ------------------ Configuration Variables ----------------- #

REMOVE_PANEL=false
REMOVE_ELYTRA=false
REMOVE_AUTO_UPDATERS=false
REMOVE_DATABASE=false
REMOVE_DATA=false

# ------------------ Detection ----------------- #

detect_installed_components() {
  PANEL_INSTALLED=false
  ELYTRA_INSTALLED=false
  PANEL_UPDATER_INSTALLED=false
  ELYTRA_UPDATER_INSTALLED=false

  if [ -d "/var/www/pyrodactyl" ]; then
    PANEL_INSTALLED=true
  fi

  if [ -f "/usr/local/bin/elytra" ]; then
    ELYTRA_INSTALLED=true
  fi

  if systemctl is-enabled --quiet pyrodactyl-panel-auto-update.timer 2>/dev/null; then
    PANEL_UPDATER_INSTALLED=true
  fi

  if systemctl is-enabled --quiet pyrodactyl-elytra-auto-update.timer 2>/dev/null; then
    ELYTRA_UPDATER_INSTALLED=true
  fi
}

# ------------------ Main Menu ----------------- #

show_main_menu() {
  print_header
  print_section "Uninstall Pyrodactyl / Elytra" "$X_MARK"

  output_highlight "Installed components detected:"
  echo ""

  # Status box
  echo -e "  ${COLOR_FIRE_ORANGE}╭────────────────────────────────────────────────────────────────────╮${COLOR_NC}"
  print_status "Pyrodactyl Panel" "$PANEL_INSTALLED"
  print_status "Elytra Daemon" "$ELYTRA_INSTALLED"
  if [ "$PANEL_UPDATER_INSTALLED" == true ] || [ "$ELYTRA_UPDATER_INSTALLED" == true ]; then
    echo -e "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}  ${COLOR_LIME}${CHECK_MARK}${COLOR_NC} ${COLOR_SOFT_WHITE}Auto-updaters${COLOR_NC}                                        ${COLOR_FIRE_ORANGE}│${COLOR_NC}"
  else
    echo -e "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}  ${COLOR_RED}${X_MARK}${COLOR_NC} ${COLOR_GRAY}Auto-updaters${COLOR_NC}                                        ${COLOR_FIRE_ORANGE}│${COLOR_NC}"
  fi
  echo -e "  ${COLOR_FIRE_ORANGE}╰────────────────────────────────────────────────────────────────────╯${COLOR_NC}"
  echo ""

  output_highlight "What would you like to uninstall?"
  echo ""
  print_menu_item "0" "Uninstall Panel only"
  print_menu_item "1" "Uninstall Elytra only"
  print_menu_item "2" "Uninstall both Panel and Elytra"
  echo ""
  print_menu_item "3" "Remove auto-updaters only"
  print_menu_item "4" "Uninstall everything" "Panel, Elytra, Auto-updaters"
  echo ""
  echo -e "  ${COLOR_GRAY}${BULLET} [5] Cancel${COLOR_NC}"
  echo ""

  local choice=""
  while true; do
    echo -ne "  ${COLOR_GOLD}${ARROW_RIGHT}${COLOR_NC} ${COLOR_WHITE}Select [0-5]:${COLOR_NC} "
    read -r choice

    case "$choice" in
      0)
        if [ "$PANEL_INSTALLED" == false ]; then
          output_error "Panel is not installed"
          sleep 1
          continue
        fi
        REMOVE_PANEL=true
        confirm_uninstall "Panel"
        return
        ;;
      1)
        if [ "$ELYTRA_INSTALLED" == false ]; then
          output_error "Elytra is not installed"
          sleep 1
          continue
        fi
        REMOVE_ELYTRA=true
        confirm_uninstall "Elytra"
        return
        ;;
      2)
        if [ "$PANEL_INSTALLED" == false ] && [ "$ELYTRA_INSTALLED" == false ]; then
          output_error "Neither Panel nor Elytra are installed"
          sleep 1
          continue
        fi
        REMOVE_PANEL=true
        REMOVE_ELYTRA=true
        confirm_uninstall "both Panel and Elytra"
        return
        ;;
      3)
        if [ "$PANEL_UPDATER_INSTALLED" == false ] && [ "$ELYTRA_UPDATER_INSTALLED" == false ]; then
          output_error "No auto-updaters are installed"
          sleep 1
          continue
        fi
        REMOVE_AUTO_UPDATERS=true
        confirm_uninstall "auto-updaters"
        return
        ;;
      4)
        if [ "$PANEL_INSTALLED" == false ] && [ "$ELYTRA_INSTALLED" == false ]; then
          output_error "Nothing is installed"
          sleep 1
          continue
        fi
        REMOVE_PANEL=true
        REMOVE_ELYTRA=true
        REMOVE_AUTO_UPDATERS=true
        confirm_uninstall "everything"
        return
        ;;
      5)
        echo ""
        output_info "Cancelled"
        echo ""
        exit 0
        ;;
      *)
        output_error "Invalid option. Please select 0-5."
        sleep 1
        ;;
    esac
  done
}

# ------------------ Confirmation ----------------- #

confirm_uninstall() {
  local component="$1"

  print_header
  print_section "Confirm Uninstall" "$WARNING"

  output_warning "You are about to uninstall ${component}"
  echo ""

  if [ "$REMOVE_PANEL" == true ]; then
    echo -e "  ${COLOR_FIRE_ORANGE}╭────────────────────────── Panel Removal ───────────────────────────╮${COLOR_NC}"
    echo -e "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}  ${COLOR_WHITE}This will remove:${COLOR_NC}                                          ${COLOR_FIRE_ORANGE}│${COLOR_NC}"
    echo -e "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}    ${COLOR_GRAY}• Panel files (/var/www/pyrodactyl)${COLOR_NC}                      ${COLOR_FIRE_ORANGE}│${COLOR_NC}"
    echo -e "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}    ${COLOR_GRAY}• Nginx configuration${COLOR_NC}                                    ${COLOR_FIRE_ORANGE}│${COLOR_NC}"
    echo -e "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}    ${COLOR_GRAY}• Systemd services (pyroq)${COLOR_NC}                               ${COLOR_FIRE_ORANGE}│${COLOR_NC}"
    echo -e "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}    ${COLOR_GRAY}• Cron jobs${COLOR_NC}                                              ${COLOR_FIRE_ORANGE}│${COLOR_NC}"
    echo -e "  ${COLOR_FIRE_ORANGE}╰────────────────────────────────────────────────────────────────────╯${COLOR_NC}"
    echo ""

    local remove_db=""
    bool_input remove_db "Also remove the panel database?" "n"
    [ "$remove_db" == "y" ] && REMOVE_DATABASE=true

    local remove_data=""
    bool_input remove_data "Also remove all server data and backups?" "n"
    [ "$remove_data" == "y" ] && REMOVE_DATA=true
  fi

  if [ "$REMOVE_ELYTRA" == true ]; then
    echo -e "  ${COLOR_FIRE_ORANGE}╭────────────────────────── Elytra Removal ──────────────────────────╮${COLOR_NC}"
    echo -e "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}  ${COLOR_WHITE}This will remove:${COLOR_NC}                                          ${COLOR_FIRE_ORANGE}│${COLOR_NC}"
    echo -e "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}    ${COLOR_GRAY}• Elytra binary (/usr/local/bin/elytra)${COLOR_NC}                  ${COLOR_FIRE_ORANGE}│${COLOR_NC}"
    echo -e "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}    ${COLOR_GRAY}• Elytra configuration (/etc/elytra)${COLOR_NC}                     ${COLOR_FIRE_ORANGE}│${COLOR_NC}"
    echo -e "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}    ${COLOR_GRAY}• Systemd service (elytra)${COLOR_NC}                               ${COLOR_FIRE_ORANGE}│${COLOR_NC}"
    echo -e "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}    ${COLOR_GRAY}• Docker containers (game servers will be stopped)${COLOR_NC}       ${COLOR_FIRE_ORANGE}│${COLOR_NC}"
    echo -e "  ${COLOR_FIRE_ORANGE}╰────────────────────────────────────────────────────────────────────╯${COLOR_NC}"
    echo ""
  fi

  if [ "$REMOVE_AUTO_UPDATERS" == true ]; then
    echo -e "  ${COLOR_FIRE_ORANGE}╭──────────────────────── Auto-Updater Removal ──────────────────────╮${COLOR_NC}"
    echo -e "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}  ${COLOR_WHITE}This will remove:${COLOR_NC}                                          ${COLOR_FIRE_ORANGE}│${COLOR_NC}"
    echo -e "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}    ${COLOR_GRAY}• Auto-update scripts${COLOR_NC}                                    ${COLOR_FIRE_ORANGE}│${COLOR_NC}"
    echo -e "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}    ${COLOR_GRAY}• Systemd timer services${COLOR_NC}                                 ${COLOR_FIRE_ORANGE}│${COLOR_NC}"
    echo -e "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}    ${COLOR_GRAY}• Configuration files${COLOR_NC}                                    ${COLOR_FIRE_ORANGE}│${COLOR_NC}"
    echo -e "  ${COLOR_FIRE_ORANGE}╰────────────────────────────────────────────────────────────────────╯${COLOR_NC}"
    echo ""
  fi

  echo ""
  output_error "This action cannot be undone!"
  echo ""
  local confirm=""
  bool_input confirm "Are you sure you want to proceed?" "n"

  if [ "$confirm" != "y" ]; then
    echo ""
    output_info "Uninstall cancelled"
    echo ""
    exit 0
  fi
}

# ------------------ Export and Run ----------------- #

export_variables() {
  export REMOVE_PANEL
  export REMOVE_ELYTRA
  export REMOVE_AUTO_UPDATERS
  export REMOVE_DATABASE
  export REMOVE_DATA
}

# ------------------ Main ----------------- #

main() {
  detect_installed_components

  if [ "$PANEL_INSTALLED" == false ] && [ "$ELYTRA_INSTALLED" == false ] && [ "$PANEL_UPDATER_INSTALLED" == false ] && [ "$ELYTRA_UPDATER_INSTALLED" == false ]; then
    print_header
    print_section "Nothing to Uninstall" "$INFO"
    output_info "No Pyrodactyl components were detected on this system."
    echo ""
    output_highlight "If you believe this is an error, you may need to manually remove:"
    echo ""
    echo -e "  ${COLOR_GRAY}• /var/www/pyrodactyl${COLOR_NC} ${COLOR_SOFT_WHITE}(Panel files)${COLOR_NC}"
    echo -e "  ${COLOR_GRAY}• /usr/local/bin/elytra${COLOR_NC} ${COLOR_SOFT_WHITE}(Elytra binary)${COLOR_NC}"
    echo -e "  ${COLOR_GRAY}• /etc/elytra${COLOR_NC} ${COLOR_SOFT_WHITE}(Elytra configuration)${COLOR_NC}"
    echo ""
    exit 0
  fi

  show_main_menu
  export_variables

  echo ""
  output_info "Starting uninstallation..."
  echo ""
  run_installer "uninstall"
}

main
