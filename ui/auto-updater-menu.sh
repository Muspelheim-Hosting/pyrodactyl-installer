#!/bin/bash

set -e

######################################################################################
#                                                                                    #
# Pyrodactyl Auto-Updater Management UI                                              #
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

# ------------------ State Variables ----------------- #

PANEL_REPO=""
PANEL_REPO_PRIVATE=false
GITHUB_TOKEN_PANEL=""
ELYTRA_REPO=""
ELYTRA_REPO_PRIVATE=false
GITHUB_TOKEN_ELYTRA=""

# ------------------ Panel Auto-Updater ----------------- #

configure_panel_auto_updater() {
  print_header
  print_section "Panel Auto-Updater Configuration" "$GEAR"

  echo ""
  output_info "The default Pyrodactyl Panel repository is:"
  echo -e "     ${COLOR_ORANGE}${DEFAULT_PANEL_REPO}${COLOR_NC}"
  echo ""

  local use_default=""
  bool_input use_default "Use default repository?" "y"

  if [ "$use_default" == "y" ]; then
    PANEL_REPO="$DEFAULT_PANEL_REPO"
    output_success "Using default repository: ${COLOR_ORANGE}${PANEL_REPO}${COLOR_NC}"
  else
    required_input PANEL_REPO "Enter the GitHub repository (format: owner/repo): " "Repository cannot be empty"

    if [[ ! "$PANEL_REPO" =~ ^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$ ]]; then
      output_error "Invalid repository format. Must be 'owner/repo'"
      exit 1
    fi
  fi

  echo ""
  print_kv "Repository" "${PANEL_REPO}"

  # Only ask about private repo if not using default (default is public)
  if [ "$use_default" == "n" ]; then
    local is_private=""
    bool_input is_private "Is this a private repository?" "n"
    PANEL_REPO_PRIVATE=$([ "$is_private" == "y" ] && echo "true" || echo "false")

    if [ "$PANEL_REPO_PRIVATE" == "true" ]; then
      echo ""
      output_info "A GitHub Personal Access Token is required for private repositories."
      output_info "Create one at: https://github.com/settings/tokens"
      output_info "Required scopes: ${COLOR_ORANGE}repo${COLOR_NC}"
      echo ""

      local token_valid=false
      while [ "$token_valid" == false ]; do
        password_input GITHUB_TOKEN_PANEL "Enter your GitHub token: " "Token cannot be empty"

        output_info "Validating token..."
        if validate_github_token "$GITHUB_TOKEN_PANEL" "$PANEL_REPO"; then
          output_success "Token validated successfully"
          token_valid=true
        else
          output_warning "Token validation failed. Please check your token and try again."
        fi
      done
    fi
  else
    PANEL_REPO_PRIVATE="false"
  fi

  echo ""
  output_info "Checking for releases in repository..."
  if ! check_releases_exist "$PANEL_REPO" "$GITHUB_TOKEN_PANEL"; then
    echo ""
    output_error "No releases found in repository: ${PANEL_REPO}"
    output_warning "You must publish a release before using the auto-updater."
    exit 1
  fi

  local latest_release
  latest_release=$(get_latest_release "$PANEL_REPO" "$GITHUB_TOKEN_PANEL")
  output_success "Found release: ${latest_release}"

  export PANEL_REPO
  export PANEL_REPO_PRIVATE
  export GITHUB_TOKEN="$GITHUB_TOKEN_PANEL"

  install_auto_updater_panel
}

# ------------------ Elytra Auto-Updater ----------------- #

configure_elytra_auto_updater() {
  print_header
  print_section "Elytra Auto-Updater Configuration" "$GEAR"

  echo ""
  output_info "The default Elytra repository is:"
  echo -e "     ${COLOR_ORANGE}${DEFAULT_ELYTRA_REPO}${COLOR_NC}"
  echo ""

  local use_default=""
  bool_input use_default "Use default repository?" "y"

  if [ "$use_default" == "y" ]; then
    ELYTRA_REPO="$DEFAULT_ELYTRA_REPO"
    output_success "Using default repository: ${COLOR_ORANGE}${ELYTRA_REPO}${COLOR_NC}"
  else
    required_input ELYTRA_REPO "Enter the GitHub repository (format: owner/repo): " "Repository cannot be empty"

    if [[ ! "$ELYTRA_REPO" =~ ^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$ ]]; then
      output_error "Invalid repository format. Must be 'owner/repo'"
      exit 1
    fi
  fi

  echo ""
  print_kv "Repository" "${ELYTRA_REPO}"

  # Only ask about private repo if not using default (default is public)
  if [ "$use_default" == "n" ]; then
    local is_private=""
    bool_input is_private "Is this a private repository?" "n"
    ELYTRA_REPO_PRIVATE=$([ "$is_private" == "y" ] && echo "true" || echo "false")

    if [ "$ELYTRA_REPO_PRIVATE" == "true" ]; then
      echo ""
      output_info "A GitHub Personal Access Token is required for private repositories."
      output_info "Create one at: https://github.com/settings/tokens"
      output_info "Required scopes: ${COLOR_ORANGE}repo${COLOR_NC}"
      echo ""

      local token_valid=false
      while [ "$token_valid" == false ]; do
        password_input GITHUB_TOKEN_ELYTRA "Enter your GitHub token: " "Token cannot be empty"

        output_info "Validating token..."
        if validate_github_token "$GITHUB_TOKEN_ELYTRA" "$ELYTRA_REPO"; then
          output_success "Token validated successfully"
          token_valid=true
        else
          output_warning "Token validation failed. Please check your token and try again."
        fi
      done
    fi
  else
    ELYTRA_REPO_PRIVATE="false"
  fi

  echo ""
  output_info "Checking for releases in repository..."
  if ! check_releases_exist "$ELYTRA_REPO" "$GITHUB_TOKEN_ELYTRA"; then
    echo ""
    output_error "No releases found in repository: ${ELYTRA_REPO}"
    output_warning "You must publish a release before using the auto-updater."
    exit 1
  fi

  local latest_release
  latest_release=$(get_latest_release "$ELYTRA_REPO" "$GITHUB_TOKEN_ELYTRA")
  output_success "Found release: ${latest_release}"

  export ELYTRA_REPO
  export ELYTRA_REPO_PRIVATE
  export GITHUB_TOKEN="$GITHUB_TOKEN_ELYTRA"

  install_auto_updater_elytra
}

# ------------------ Both Auto-Updaters ----------------- #

configure_both_auto_updaters() {
  print_header
  print_section "Configure Both Auto-Updaters" "$GEAR"

  configure_panel_auto_updater

  echo ""
  output_info "Now configuring Elytra auto-updater..."
  echo ""

  configure_elytra_auto_updater

  output_success "Both auto-updaters installed successfully!"
}

# ------------------ Remove Menu ----------------- #

show_remove_menu() {
  print_header
  print_section "Remove Auto-Updaters" "$X_MARK"

  # Check what's installed
  local panel_updater_installed=false
  local elytra_updater_installed=false

  if systemctl is-enabled --quiet pyrodactyl-panel-auto-update.timer 2>/dev/null; then
    panel_updater_installed=true
  fi

  if systemctl is-enabled --quiet pyrodactyl-elytra-auto-update.timer 2>/dev/null; then
    elytra_updater_installed=true
  fi

  if [ "$panel_updater_installed" == false ] && [ "$elytra_updater_installed" == false ]; then
    output_warning "No auto-updaters are currently installed."
    echo ""
    output_info "Press Enter to return to main menu..."
    read -r
    return
  fi

  output_highlight "Which auto-updaters would you like to remove?"
  echo ""

  if [ "$panel_updater_installed" == true ]; then
    print_menu_item "0" "Panel auto-updater only"
  fi

  if [ "$elytra_updater_installed" == true ]; then
    print_menu_item "1" "Elytra auto-updater only"
  fi

  if [ "$panel_updater_installed" == true ] && [ "$elytra_updater_installed" == true ]; then
    print_menu_item "2" "Both auto-updaters"
  fi

  echo -e "  ${COLOR_GRAY}${BULLET} [3] Cancel${COLOR_NC}"
  echo ""

  local choice=""
  while true; do
    echo -ne "  ${COLOR_GOLD}${ARROW_RIGHT}${COLOR_NC} ${COLOR_WHITE}Select option:${COLOR_NC} "
    read -r choice

    case "$choice" in
      0)
        if [ "$panel_updater_installed" == true ]; then
          output_warning "This will remove the Panel auto-updater"
          local confirm=""
          bool_input confirm "Are you sure?" "n"
          if [ "$confirm" == "y" ]; then
            remove_auto_updater_panel
            output_success "Panel auto-updater removed"
          fi
          break
        else
          output_error "Invalid option"
        fi
        ;;
      1)
        if [ "$elytra_updater_installed" == true ]; then
          output_warning "This will remove the Elytra auto-updater"
          local confirm=""
          bool_input confirm "Are you sure?" "n"
          if [ "$confirm" == "y" ]; then
            remove_auto_updater_elytra
            output_success "Elytra auto-updater removed"
          fi
          break
        else
          output_error "Invalid option"
        fi
        ;;
      2)
        if [ "$panel_updater_installed" == true ] && [ "$elytra_updater_installed" == true ]; then
          output_warning "This will remove both auto-updaters"
          local confirm=""
          bool_input confirm "Are you sure?" "n"
          if [ "$confirm" == "y" ]; then
            remove_auto_updater_panel
            remove_auto_updater_elytra
            output_success "All auto-updaters removed"
          fi
          break
        else
          output_error "Invalid option"
        fi
        ;;
      3)
        output_info "Cancelled"
        break
        ;;
      *)
        output_error "Invalid option"
        ;;
    esac
  done
}

# ------------------ Trigger Update Functions ----------------- #

# ------------------ Main Menu ----------------- #

show_main_menu() {
  while true; do
    print_header
    print_section "Auto-Updater Management" "$GEAR"

    output_highlight "What would you like to do?"
    echo ""
    echo -e "  ${COLOR_GOLD}${PACKAGE}${COLOR_NC}  ${TEXT_BOLD}${COLOR_WHITE}Install Options${COLOR_NC}"
    echo ""
    print_menu_item "0" "Install Panel auto-updater"
    print_menu_item "1" "Install Elytra auto-updater"
    print_menu_item "2" "Install both auto-updaters"
    echo ""
    echo -e "  ${COLOR_GOLD}${X_MARK}${COLOR_NC}  ${TEXT_BOLD}${COLOR_WHITE}Remove Options${COLOR_NC}"
    echo ""
    print_menu_item "3" "Remove auto-updaters"
    echo ""
    echo -e "  ${COLOR_GOLD}${ARROW_RIGHT}${COLOR_NC}  ${TEXT_BOLD}${COLOR_WHITE}Navigation${COLOR_NC}"
    echo ""
    print_menu_item "4" "Return to main menu"
    echo ""

    local choice=""
    echo -ne "  ${COLOR_GOLD}${ARROW_RIGHT}${COLOR_NC} ${COLOR_WHITE}Select [0-4]:${COLOR_NC} "
    read -r choice

    case "$choice" in
      0)
        configure_panel_auto_updater
        echo ""
        output_info "Press Enter to continue..."
        read -r
        ;;
      1)
        configure_elytra_auto_updater
        echo ""
        output_info "Press Enter to continue..."
        read -r
        ;;
      2)
        configure_both_auto_updaters
        echo ""
        output_info "Press Enter to continue..."
        read -r
        ;;
      3)
        show_remove_menu
        ;;
      4)
        output_info "Returning to main menu..."
        exit 0
        ;;
      *)
        output_error "Invalid option. Please select 0-4."
        sleep 2
        ;;
    esac
  done
}

# ------------------ Main ----------------- #

main() {
  show_main_menu
}

main
