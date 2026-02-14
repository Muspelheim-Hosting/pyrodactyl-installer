#!/bin/bash

set -e

######################################################################################
#                                                                                    #
# Pyrodactyl Panel + Elytra Combined Installation UI                                 #
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

# Panel Configuration
PANEL_REPO=""
PANEL_REPO_PRIVATE=false
GITHUB_TOKEN_PANEL=""
PANEL_INSTALL_METHOD="release"
PANEL_FQDN=""
PANEL_TIMEZONE="UTC"
PANEL_ADMIN_EMAIL=""
PANEL_ADMIN_USERNAME=""
PANEL_ADMIN_FIRSTNAME=""
PANEL_ADMIN_LASTNAME=""
PANEL_ADMIN_PASSWORD=""
CONFIGURE_LETSENCRYPT=false
CONFIGURE_FIREWALL=false
INSTALL_AUTO_UPDATER_PANEL=false
INSTALL_AUTO_UPDATER_ELYTRA=false
SSL_CERT_PATH=""
SSL_KEY_PATH=""
DB_HOST="127.0.0.1"
DB_PORT="3306"
DB_NAME="panel"
DB_USER="pyrodactyl"
DB_PASSWORD=""

# Elytra Configuration
ELYTRA_REPO=""
ELYTRA_REPO_PRIVATE=false
GITHUB_TOKEN_ELYTRA=""
NODE_NAME="local"
NODE_DESCRIPTION="Local Node"
BEHIND_PROXY=false

# ------------------ Panel Repository ----------------- #

configure_panel_repository() {
  print_header
  print_section "Panel Repository Configuration" "$PACKAGE"

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
          warning "Token validation failed. Please check your token and try again."
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
    output_warning "You must publish a release before using this installer."
    exit 1
  fi

  local latest_release
  latest_release=$(get_latest_release "$PANEL_REPO" "$GITHUB_TOKEN_PANEL")
  output_success "Found release: ${latest_release}"
}

# ------------------ Panel Settings ----------------- #

configure_panel_settings() {
  print_header
  print_flame "Panel Configuration"

  output "How would you like to install the panel?"
  echo ""
  output "[${COLOR_ORANGE}0${COLOR_NC}] Download latest release tarball (recommended)"
  output "[${COLOR_ORANGE}1${COLOR_NC}] Clone from Git repository (development)"
  echo ""

  local method_choice=""
  while [[ "$method_choice" != "0" && "$method_choice" != "1" ]]; do
    echo -n "* Select [0-1]: "
    read -r method_choice
  done

  if [ "$method_choice" == "0" ]; then
    PANEL_INSTALL_METHOD="release"
  else
    PANEL_INSTALL_METHOD="clone"
  fi

  echo ""

  local valid_fqdn=false
  while [ "$valid_fqdn" == false ]; do
    required_input PANEL_FQDN "Enter the domain for your panel (e.g., panel.example.com): " "Domain is required"

    if check_fqdn "$PANEL_FQDN"; then
      # Verify DNS resolution
      if bash <(curl -sSL "$GITHUB_URL/lib/verify-fqdn.sh") "$PANEL_FQDN"; then
        valid_fqdn=true
      else
        # DNS verification failed and user chose not to continue
        error "Please fix your DNS configuration or enter a different domain."
      fi
    else
      error "Invalid FQDN format. Must be a valid domain name."
    fi
  done

  echo ""
  local use_ssl=""
  bool_input use_ssl "Would you like to use SSL/HTTPS?" "y"

  if [ "$use_ssl" == "y" ]; then
    echo ""
    output "[${COLOR_ORANGE}0${COLOR_NC}] Let's Encrypt (auto-generated)"
    output "[${COLOR_ORANGE}1${COLOR_NC}] Use existing SSL certificate"
    output "[${COLOR_ORANGE}2${COLOR_NC}] No SSL (not recommended)"
    echo ""

    local ssl_choice=""
    while [[ "$ssl_choice" != "0" && "$ssl_choice" != "1" && "$ssl_choice" != "2" ]]; do
      echo -n "* Select [0-2]: "
      read -r ssl_choice
    done

    case "$ssl_choice" in
      0)
        CONFIGURE_LETSENCRYPT=true
        ;;
      1)
        required_input SSL_CERT_PATH "Path to SSL certificate: " "Path is required"
        required_input SSL_KEY_PATH "Path to SSL key: " "Path is required"
        ;;
      2)
        output "SSL will not be configured"
        ;;
    esac
  fi

  echo ""
  required_input PANEL_TIMEZONE "Timezone [UTC]: " "" "UTC"

  echo ""
  email_input PANEL_ADMIN_EMAIL "Admin email: " "Invalid email address"
  required_input PANEL_ADMIN_USERNAME "Admin username: " "Username is required"
  required_input PANEL_ADMIN_FIRSTNAME "First name: " "First name is required"
  required_input PANEL_ADMIN_LASTNAME "Last name: " "Last name is required"

  local password_match=false
  while [ "$password_match" == false ]; do
    password_input PANEL_ADMIN_PASSWORD "Admin password: " "Password cannot be empty"
    local password_confirm=""
    password_input password_confirm "Confirm password: " "Confirmation is required"

    if [ "$PANEL_ADMIN_PASSWORD" == "$password_confirm" ]; then
      password_match=true
    else
      error "Passwords do not match. Please try again."
    fi
  done

}

# ------------------ Elytra Configuration ----------------- #

configure_elytra_settings() {
  print_header
  print_flame "Elytra Repository Configuration"

  output "The default Elytra repository is:"
  output "  ${COLOR_ORANGE}${DEFAULT_ELYTRA_REPO}${COLOR_NC}"
  echo ""

  local use_default=""
  bool_input use_default "Use default repository?" "y"

  if [ "$use_default" == "y" ]; then
    ELYTRA_REPO="$DEFAULT_ELYTRA_REPO"
  else
    required_input ELYTRA_REPO "Enter the GitHub repository (format: owner/repo): " "Repository cannot be empty"

    if [[ ! "$ELYTRA_REPO" =~ ^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$ ]]; then
      error "Invalid repository format. Must be 'owner/repo'"
      exit 1
    fi
  fi

  echo ""
  output "Repository: ${COLOR_ORANGE}${ELYTRA_REPO}${COLOR_NC}"

  # Only ask about private repo if not using default (default is public)
  if [ "$use_default" == "n" ]; then
    local is_private=""
    bool_input is_private "Is this a private repository?" "n"
    ELYTRA_REPO_PRIVATE=$([ "$is_private" == "y" ] && echo "true" || echo "false")

    if [ "$ELYTRA_REPO_PRIVATE" == "true" ]; then
      echo ""
      output "A GitHub Personal Access Token is required for private repositories."
      output "Create one at: https://github.com/settings/tokens"
      echo ""

      local token_valid=false
      while [ "$token_valid" == false ]; do
        password_input GITHUB_TOKEN_ELYTRA "Enter your GitHub token: " "Token cannot be empty"

        output "Validating token..."
        if validate_github_token "$GITHUB_TOKEN_ELYTRA" "$ELYTRA_REPO"; then
          success "Token validated successfully"
          token_valid=true
        else
          warning "Token validation failed. Please check your token and try again."
        fi
      done
    fi
  else
    ELYTRA_REPO_PRIVATE="false"
  fi

  output "Checking for releases in repository..."
  if ! check_releases_exist "$ELYTRA_REPO" "$GITHUB_TOKEN_ELYTRA"; then
    echo ""
    error "No releases found in repository: ${ELYTRA_REPO}"
    warning "Elytra must be installed from a release."
    exit 1
  fi

  local latest_release
  latest_release=$(get_latest_release "$ELYTRA_REPO" "$GITHUB_TOKEN_ELYTRA")
  success "Found release: ${latest_release}"

  echo ""
  print_flame "Elytra Node Configuration"
  echo ""

  output "Configuring Elytra to connect to the panel at: ${COLOR_ORANGE}https://${PANEL_FQDN}${COLOR_NC}"
  output "(This will be set automatically - no panel URL input needed)"
  echo ""

  required_input NODE_NAME "Node name [local]: " "" "local"
  required_input NODE_DESCRIPTION "Node description [Local Node]: " "" "Local Node"

  local behind_proxy_input=""
  bool_input behind_proxy_input "Is this node behind a proxy (e.g., Cloudflare)?" "n"
  BEHIND_PROXY=$([ "$behind_proxy_input" == "y" ] && echo "true" || echo "false")
}

# ------------------ Minecraft Server Setup ----------------- #

configure_minecraft_server() {
  print_header
  print_flame "Minecraft Server Setup"

  output "Would you like to automatically create a Minecraft server on this node?"
  output "This will create a vanilla Minecraft server with 4GB RAM allocation."
  echo ""

  local create_server=""
  bool_input create_server "Create Minecraft server automatically?" "n"
  CREATE_MINECRAFT_SERVER=$([ "$create_server" == "y" ] && echo "true" || echo "false")

  if [ "$CREATE_MINECRAFT_SERVER" == "true" ]; then
    output "A Minecraft server will be created automatically after installation."
  else
    output "No server will be created. You can create one manually later."
  fi
}

# ------------------ Auto-Updaters ----------------- #

configure_auto_updaters() {
  print_header
  print_flame "Auto-Updater Configuration"

  local install_panel_au=""
  bool_input install_panel_au "Install auto-updater for the panel?" "y"
  [ "$install_panel_au" == "y" ] && INSTALL_AUTO_UPDATER_PANEL=true

  local install_elytra_au=""
  bool_input install_elytra_au "Install auto-updater for Elytra?" "y"
  [ "$install_elytra_au" == "y" ] && INSTALL_AUTO_UPDATER_ELYTRA=true
}

# ------------------ Firewall ----------------- #

configure_firewall_settings() {
  print_header
  print_flame "Firewall Configuration"

  ask_firewall CONFIGURE_FIREWALL
}

# ------------------ Summary ----------------- #

show_summary() {
  print_header
  print_section "Installation Summary" "$DIAMOND"

  output_highlight "Please review the following configuration:"
  echo ""

  # Panel Configuration Box
  echo -e "  ${COLOR_FIRE_ORANGE}╭────────────────────── Panel Configuration ─────────────────────────╮${COLOR_NC}"
  printf "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}  ${COLOR_GOLD}%-18s${COLOR_NC} ${COLOR_WHITE}%-48s${COLOR_FIRE_ORANGE}│${COLOR_NC}\n" "Repository:" "${PANEL_REPO} $([ "$PANEL_REPO_PRIVATE" == "true" ] && echo '(private)' || echo '(public)')"
  printf "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}  ${COLOR_GOLD}%-18s${COLOR_NC} ${COLOR_WHITE}%-48s${COLOR_FIRE_ORANGE}│${COLOR_NC}\n" "Install Method:" "${PANEL_INSTALL_METHOD}"
  printf "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}  ${COLOR_GOLD}%-18s${COLOR_NC} ${COLOR_WHITE}%-48s${COLOR_FIRE_ORANGE}│${COLOR_NC}\n" "Domain:" "${PANEL_FQDN}"
  printf "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}  ${COLOR_GOLD}%-18s${COLOR_NC} ${COLOR_WHITE}%-48s${COLOR_FIRE_ORANGE}│${COLOR_NC}\n" "SSL:" "$([ "$CONFIGURE_LETSENCRYPT" == "true" ] && echo "Let's Encrypt" || ([ -n "$SSL_CERT_PATH" ] && echo "Custom Certificate" || echo "None"))"
  printf "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}  ${COLOR_GOLD}%-18s${COLOR_NC} ${COLOR_WHITE}%-48s${COLOR_FIRE_ORANGE}│${COLOR_NC}\n" "Timezone:" "${PANEL_TIMEZONE}"
  printf "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}  ${COLOR_GOLD}%-18s${COLOR_NC} ${COLOR_WHITE}%-48s${COLOR_FIRE_ORANGE}│${COLOR_NC}\n" "Admin:" "${PANEL_ADMIN_USERNAME} (${PANEL_ADMIN_EMAIL})"
  printf "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}  ${COLOR_GOLD}%-18s${COLOR_NC} ${COLOR_WHITE}%-48s${COLOR_FIRE_ORANGE}│${COLOR_NC}\n" "Auto-Updater:" "$([ "$INSTALL_AUTO_UPDATER_PANEL" == "true" ] && echo "${COLOR_LIME}Yes${COLOR_NC}" || echo "${COLOR_GRAY}No${COLOR_NC}")"
  echo -e "  ${COLOR_FIRE_ORANGE}╰────────────────────────────────────────────────────────────────────╯${COLOR_NC}"
  echo ""

  # Elytra Configuration Box
  echo -e "  ${COLOR_FIRE_ORANGE}╭────────────────────── Elytra Configuration ────────────────────────╮${COLOR_NC}"
  printf "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}  ${COLOR_GOLD}%-18s${COLOR_NC} ${COLOR_WHITE}%-48s${COLOR_FIRE_ORANGE}│${COLOR_NC}\n" "Repository:" "${ELYTRA_REPO} $([ "$ELYTRA_REPO_PRIVATE" == "true" ] && echo '(private)' || echo '(public)')"
  printf "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}  ${COLOR_GOLD}%-18s${COLOR_NC} ${COLOR_WHITE}%-48s${COLOR_FIRE_ORANGE}│${COLOR_NC}\n" "Panel URL:" "https://${PANEL_FQDN} (auto-configured)"
  printf "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}  ${COLOR_GOLD}%-18s${COLOR_NC} ${COLOR_WHITE}%-48s${COLOR_FIRE_ORANGE}│${COLOR_NC}\n" "Node Name:" "${NODE_NAME}"
  printf "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}  ${COLOR_GOLD}%-18s${COLOR_NC} ${COLOR_WHITE}%-48s${COLOR_FIRE_ORANGE}│${COLOR_NC}\n" "Node Description:" "${NODE_DESCRIPTION}"
  printf "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}  ${COLOR_GOLD}%-18s${COLOR_NC} ${COLOR_WHITE}%-48s${COLOR_FIRE_ORANGE}│${COLOR_NC}\n" "Behind Proxy:" "$([ "$BEHIND_PROXY" == "true" ] && echo "${COLOR_LIME}Yes${COLOR_NC}" || echo "${COLOR_GRAY}No${COLOR_NC}")"
  printf "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}  ${COLOR_GOLD}%-18s${COLOR_NC} ${COLOR_WHITE}%-48s${COLOR_FIRE_ORANGE}│${COLOR_NC}\n" "Auto-Updater:" "$([ "$INSTALL_AUTO_UPDATER_ELYTRA" == "true" ] && echo "${COLOR_LIME}Yes${COLOR_NC}" || echo "${COLOR_GRAY}No${COLOR_NC}")"
  echo -e "  ${COLOR_FIRE_ORANGE}╰────────────────────────────────────────────────────────────────────╯${COLOR_NC}"
  echo ""

  # Minecraft Server Box
  if [ "$CREATE_MINECRAFT_SERVER" == "true" ]; then
    echo -e "  ${COLOR_FIRE_ORANGE}╭────────────────────── Minecraft Server ────────────────────────────╮${COLOR_NC}"
    printf "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}  ${COLOR_GOLD}%-18s${COLOR_NC} ${COLOR_WHITE}%-48s${COLOR_FIRE_ORANGE}│${COLOR_NC}\n" "Auto-Create:" "${COLOR_LIME}Yes${COLOR_NC}"
    printf "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}  ${COLOR_GOLD}%-18s${COLOR_NC} ${COLOR_WHITE}%-48s${COLOR_FIRE_ORANGE}│${COLOR_NC}\n" "Server Type:" "Vanilla Minecraft Java"
    printf "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}  ${COLOR_GOLD}%-18s${COLOR_NC} ${COLOR_WHITE}%-48s${COLOR_FIRE_ORANGE}│${COLOR_NC}\n" "Memory:" "4GB"
    printf "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}  ${COLOR_GOLD}%-18s${COLOR_NC} ${COLOR_WHITE}%-48s${COLOR_FIRE_ORANGE}│${COLOR_NC}\n" "Disk:" "32GB"
    echo -e "  ${COLOR_FIRE_ORANGE}╰────────────────────────────────────────────────────────────────────╯${COLOR_NC}"
    echo ""
  fi

  # General Settings Box
  echo -e "  ${COLOR_FIRE_ORANGE}╭────────────────────── General Settings ────────────────────────────╮${COLOR_NC}"
  printf "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}  ${COLOR_GOLD}%-18s${COLOR_NC} ${COLOR_WHITE}%-48s${COLOR_FIRE_ORANGE}│${COLOR_NC}\n" "Firewall:" "$([ "$CONFIGURE_FIREWALL" == "true" ] && echo "${COLOR_LIME}Enabled${COLOR_NC}" || echo "${COLOR_GRAY}Disabled${COLOR_NC}")"
  if [ "$CONFIGURE_FIREWALL" == "true" ]; then
    printf "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}  ${COLOR_GOLD}%-18s${COLOR_NC} ${COLOR_WHITE}%-48s${COLOR_FIRE_ORANGE}│${COLOR_NC}\n" "Game Support:" "Minecraft, CS:GO/TF2/GMod, ARK, Rust, Valheim, FiveM"
  fi
  echo -e "  ${COLOR_FIRE_ORANGE}╰────────────────────────────────────────────────────────────────────╯${COLOR_NC}"
  echo ""

  local confirm=""
  bool_input confirm "Proceed with installation of both Panel and Elytra?" "y"

  if [ "$confirm" != "y" ]; then
    output_error "Installation aborted"
    exit 1
  fi
}

# ------------------ Export and Run ----------------- #

export_variables() {
  # Panel variables
  export PANEL_REPO
  export PANEL_REPO_PRIVATE
  export GITHUB_TOKEN="$GITHUB_TOKEN_PANEL"
  export PANEL_INSTALL_METHOD
  export PANEL_FQDN
  export PANEL_TIMEZONE
  export PANEL_ADMIN_EMAIL
  export PANEL_ADMIN_USERNAME
  export PANEL_ADMIN_FIRSTNAME
  export PANEL_ADMIN_LASTNAME
  export PANEL_ADMIN_PASSWORD
  export CONFIGURE_LETSENCRYPT
  export CONFIGURE_FIREWALL
  export INSTALL_AUTO_UPDATER="$INSTALL_AUTO_UPDATER_PANEL"
  export INSTALL_AUTO_UPDATER_PANEL
  export INSTALL_AUTO_UPDATER_ELYTRA
  export SSL_CERT_PATH
  export SSL_KEY_PATH
  export DB_HOST
  export DB_PORT
  export DB_NAME
  export DB_USER
  export DB_PASSWORD

  # Elytra variables
  export ELYTRA_REPO
  export ELYTRA_REPO_PRIVATE
  export GITHUB_TOKEN_ELYTRA
  export NODE_NAME
  export NODE_DESCRIPTION
  export BEHIND_PROXY

  # Minecraft server setup
  export CREATE_MINECRAFT_SERVER

  # Combined installation flag
  export BOTH_INSTALL=true
}

# ------------------ Main ----------------- #

main() {
  print_header
  print_section "Welcome to the Pyrodactyl + Elytra Combined Installer" "$FIRE"

  configure_panel_repository
  configure_panel_settings
  configure_elytra_settings
  configure_auto_updaters
  configure_minecraft_server
  configure_firewall_settings
  show_summary

  export_variables

  echo ""
  output_info "Starting installation..."
  echo ""
  run_installer "both"
}

main
