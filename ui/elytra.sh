#!/bin/bash

set -e

######################################################################################
#                                                                                    #
# Pyrodactyl Elytra Installation UI                                                  #
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

ELYTRA_REPO=""
ELYTRA_REPO_PRIVATE=false
GITHUB_TOKEN=""
PANEL_URL=""
NODE_TOKEN=""
NODE_ID=""
CONFIGURE_FIREWALL=false
INSTALL_AUTO_UPDATER=false
USE_SSL=false
BEHIND_PROXY=false
FQDN=""
ELYTRA_INSTALL_DIR="/etc/elytra"

# ------------------ Repository Configuration ----------------- #

configure_github_repository() {
  print_header
  print_section "GitHub Repository Configuration" "$PACKAGE"

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
      output_info "Create one at: $(hyperlink "https://github.com/settings/tokens")"
      output_info "Required scopes: ${COLOR_ORANGE}repo${COLOR_NC}"
      echo ""

      local token_valid=false
      while [ "$token_valid" == false ]; do
        password_input GITHUB_TOKEN "Enter your GitHub token: " "Token cannot be empty"

        output_info "Validating token..."
        if validate_github_token "$GITHUB_TOKEN" "$ELYTRA_REPO"; then
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
  if ! check_releases_exist "$ELYTRA_REPO" "$GITHUB_TOKEN"; then
    echo ""
    output_error "No releases found in repository: ${ELYTRA_REPO}"
    output_warning "Elytra must be installed from a release."
    exit 1
  fi

  local latest_release
  latest_release=$(get_latest_release "$ELYTRA_REPO" "$GITHUB_TOKEN")
  output_success "Found release: ${latest_release}"
}

# ------------------ API Key Configuration ----------------- #

configure_api_key() {
  print_header
  print_section "API Key Configuration" "$KEY"

  echo ""
  output_info "Do you have an API key from your panel installation?"
  echo -e "     ${COLOR_GRAY}The API key would have been displayed at the end of the panel setup.${COLOR_NC}"
  echo ""
  output_highlight "Using an API key allows automatic node configuration"
  echo ""

  local has_api_key=""
  bool_input has_api_key "Do you have an API key?" "n"

  if [ "$has_api_key" == "y" ]; then
    password_input PANEL_API_KEY "Enter your API key: " "API key is required"

    echo ""
    output_info "Enter your panel URL"
    echo -e "     ${COLOR_GRAY}Example:${COLOR_NC} ${COLOR_ORANGE}https://panel.example.com${COLOR_NC}"
    required_input PANEL_URL "Panel URL: " "Panel URL is required"
    PANEL_URL="${PANEL_URL%/}"  # Remove trailing slash

    echo ""
    output_info "Enter a name for this node"
    echo -e "     ${COLOR_GRAY}This will be used to identify the node in the panel${COLOR_NC}"
    required_input NODE_NAME "Node name [Elytra-Node]: " "" "Elytra-Node"
    
    output_success "API key configured - automatic setup will be used"
    USE_API_KEY=true
  else
    output_info "No API key provided - manual configuration will be required"
    USE_API_KEY=false
  fi
}

# ------------------ Panel Connection ----------------- #

configure_panel_connection() {
  print_header
  print_section "Panel Connection Configuration" "$GLOBE"

  # Skip if using API key
  if [ "$USE_API_KEY" == "true" ]; then
    output_success "Using API key for automatic configuration - manual connection details not required"
    return 0
  fi

  echo ""
  output_info "Enter the URL of your Pyrodactyl Panel"
  echo -e "     ${COLOR_GRAY}Example:${COLOR_NC} ${COLOR_ORANGE}https://panel.example.com${COLOR_NC}"
  echo ""

  required_input PANEL_URL "Panel URL: " "Panel URL is required"
  PANEL_URL="${PANEL_URL%/}"  # Remove trailing slash

  echo ""
  output_highlight "To connect this node to the panel, follow these steps:"
  echo ""
  echo -e "     ${COLOR_ORANGE}1.${COLOR_NC} ${COLOR_SOFT_WHITE}Go to:${COLOR_NC} ${PANEL_URL}/admin/nodes"
  echo -e "     ${COLOR_ORANGE}2.${COLOR_NC} ${COLOR_SOFT_WHITE}Create a new node${COLOR_NC}"
  echo -e "     ${COLOR_ORANGE}3.${COLOR_NC} ${COLOR_SOFT_WHITE}Copy the configuration token${COLOR_NC}"
  echo ""

  password_input NODE_TOKEN "Node configuration token: " "Token is required"
  required_input NODE_ID "Node ID: " "Node ID is required"
}

# ------------------ Network Configuration ----------------- #

configure_network() {
  print_header
  print_section "Network Configuration" "$SERVER"

  local behind_proxy_input=""
  bool_input behind_proxy_input "Is this node behind a proxy (e.g., Cloudflare)?" "n"
  BEHIND_PROXY=$([ "$behind_proxy_input" == "y" ] && echo "true" || echo "false")

  if [ "$BEHIND_PROXY" == "true" ]; then
    output_success "Node will be configured to work behind a proxy"
  fi
}

# ------------------ Auto-Updater ----------------- #

configure_auto_updater() {
  print_header
  print_section "Auto-Updater Configuration" "$GEAR"

  local install_auto_update=""
  bool_input install_auto_update "Install auto-updater for Elytra?" "y"

  if [ "$install_auto_update" == "y" ]; then
    INSTALL_AUTO_UPDATER=true
    output_success "Auto-updater will be installed"
  else
    output_info "Auto-updater will not be installed"
  fi
}

# ------------------ Firewall ----------------- #

configure_firewall() {
  print_header
  print_section "Firewall Configuration" "$LOCK"

  ask_firewall CONFIGURE_FIREWALL
}

# ------------------ Summary ----------------- #

show_summary() {
  print_header
  print_section "Installation Summary" "$DIAMOND"

  output_highlight "Please review the following configuration:"
  echo ""

  # Summary box
  echo -e "  ${COLOR_FIRE_ORANGE}╭────────────────────────────────────────────────────────────────────╮${COLOR_NC}"
  printf "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}  ${COLOR_GOLD}%-18s${COLOR_NC} ${COLOR_WHITE}%-48s${COLOR_FIRE_ORANGE}│${COLOR_NC}\n" "Repository:" "${ELYTRA_REPO} $([ "$ELYTRA_REPO_PRIVATE" == "true" ] && echo '(private)' || echo '(public)')"
  printf "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}  ${COLOR_GOLD}%-18s${COLOR_NC} ${COLOR_WHITE}%-48s${COLOR_FIRE_ORANGE}│${COLOR_NC}\n" "Panel URL:" "${PANEL_URL}"
  if [ "$USE_API_KEY" == "true" ]; then
    printf "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}  ${COLOR_GOLD}%-18s${COLOR_NC} ${COLOR_WHITE}%-48s${COLOR_FIRE_ORANGE}│${COLOR_NC}\n" "Setup Method:" "Automatic (via API key)"
    printf "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}  ${COLOR_GOLD}%-18s${COLOR_NC} ${COLOR_WHITE}%-48s${COLOR_FIRE_ORANGE}│${COLOR_NC}\n" "Node Name:" "${NODE_NAME}"
    printf "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}  ${COLOR_GOLD}%-18s${COLOR_NC} ${COLOR_WHITE}%-48s${COLOR_FIRE_ORANGE}│${COLOR_NC}\n" "API Key:" "${PANEL_API_KEY:0:20}..."
  else
    printf "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}  ${COLOR_GOLD}%-18s${COLOR_NC} ${COLOR_WHITE}%-48s${COLOR_FIRE_ORANGE}│${COLOR_NC}\n" "Setup Method:" "Manual"
    printf "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}  ${COLOR_GOLD}%-18s${COLOR_NC} ${COLOR_WHITE}%-48s${COLOR_FIRE_ORANGE}│${COLOR_NC}\n" "Node ID:" "${NODE_ID}"
  fi
  printf "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}  ${COLOR_GOLD}%-18s${COLOR_NC} ${COLOR_WHITE}%-48s${COLOR_FIRE_ORANGE}│${COLOR_NC}\n" "Behind Proxy:" "$([ "$BEHIND_PROXY" == "true" ] && echo "${COLOR_LIME}Yes${COLOR_NC}" || echo "${COLOR_GRAY}No${COLOR_NC}")"
  printf "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}  ${COLOR_GOLD}%-18s${COLOR_NC} ${COLOR_WHITE}%-48s${COLOR_FIRE_ORANGE}│${COLOR_NC}\n" "Auto-Updater:" "$([ "$INSTALL_AUTO_UPDATER" == "true" ] && echo "${COLOR_LIME}Yes${COLOR_NC}" || echo "${COLOR_GRAY}No${COLOR_NC}")"
  printf "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}  ${COLOR_GOLD}%-18s${COLOR_NC} ${COLOR_WHITE}%-48s${COLOR_FIRE_ORANGE}│${COLOR_NC}\n" "Firewall:" "$([ "$CONFIGURE_FIREWALL" == "true" ] && echo "${COLOR_LIME}Yes${COLOR_NC}" || echo "${COLOR_GRAY}No${COLOR_NC}")"
  echo -e "  ${COLOR_FIRE_ORANGE}╰────────────────────────────────────────────────────────────────────╯${COLOR_NC}"
  echo ""

  local confirm=""
  bool_input confirm "Proceed with installation?" "y"

  if [ "$confirm" != "y" ]; then
    output_error "Installation aborted"
    exit 1
  fi
}

# ------------------ Export and Run ----------------- #

export_variables() {
  export ELYTRA_REPO
  export ELYTRA_REPO_PRIVATE
  export GITHUB_TOKEN
  export PANEL_URL
  export PANEL_API_KEY
  export NODE_NAME
  export NODE_TOKEN
  export NODE_ID
  export CONFIGURE_FIREWALL
  export INSTALL_AUTO_UPDATER
  export USE_SSL
  export BEHIND_PROXY
  export FQDN
  export ELYTRA_INSTALL_DIR
}

# ------------------ Main ----------------- #

main() {
  print_header
  print_section "Welcome to the Elytra Daemon Installer" "$FIRE"

  # Show progress steps
  local total_steps=6
  local current_step=0

  ((current_step++))
  print_step $current_step $total_steps "Configuring Repository"
  configure_github_repository

  ((current_step++))
  print_step $current_step $total_steps "Configuring API Key"
  configure_api_key

  ((current_step++))
  print_step $current_step $total_steps "Configuring Panel Connection"
  configure_panel_connection

  ((current_step++))
  print_step $current_step $total_steps "Configuring Network"
  configure_network

  ((current_step++))
  print_step $current_step $total_steps "Configuring Auto-Updater"
  configure_auto_updater

  ((current_step++))
  print_step $current_step $total_steps "Configuring Firewall"
  configure_firewall

  show_summary

  export_variables

  echo ""
  output_info "Starting installation..."
  echo ""
  run_installer "elytra"
}

main
