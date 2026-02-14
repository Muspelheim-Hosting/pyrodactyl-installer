 ```
pyrodactyl\install-scripts\new\ui\panel.sh
```
#!/bin/bash

set -e

######################################################################################
#                                                                                    #
# Pyrodactyl Panel Installation UI                                                   #
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

PANEL_REPO=""
PANEL_REPO_PRIVATE=false
GITHUB_TOKEN=""
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
INSTALL_AUTO_UPDATER=false
SSL_CERT_PATH=""
SSL_KEY_PATH=""
DB_HOST="127.0.0.1"
DB_PORT="3306"
DB_NAME="panel"
DB_USER="pyrodactyl"
DB_PASSWORD=""

# ------------------ Repository Configuration ----------------- #

configure_github_repository() {
  print_header
  print_section "GitHub Repository Configuration" "$PACKAGE"

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
      output_info "Create one at: $(hyperlink "https://github.com/settings/tokens")"
      output_info "Required scopes: ${COLOR_ORANGE}repo${COLOR_NC}"
      echo ""

      local token_valid=false
      while [ "$token_valid" == false ]; do
        password_input GITHUB_TOKEN "Enter your GitHub token: " "Token cannot be empty"

        output_info "Validating token..."
        if validate_github_token "$GITHUB_TOKEN" "$PANEL_REPO"; then
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
  if ! check_releases_exist "$PANEL_REPO" "$GITHUB_TOKEN"; then
    echo ""
    output_error "No releases found in repository: ${PANEL_REPO}"
    output_warning "You must publish a release before using this installer."
    exit 1
  fi

  local latest_release
  latest_release=$(get_latest_release "$PANEL_REPO" "$GITHUB_TOKEN")
  output_success "Found release: ${latest_release}"
}

# ------------------ Installation Method ----------------- #

configure_installation_method() {
  print_header
  print_section "Installation Method" "$GEAR"

  echo ""
  output_highlight "How would you like to install the panel?"
  echo ""
  print_menu_item "0" "Download latest release tarball" "recommended for production"
  print_menu_item "1" "Clone from Git repository" "for development"
  echo ""

  local method_choice=""
  while [[ "$method_choice" != "0" && "$method_choice" != "1" ]]; do
    echo -ne "  ${COLOR_GOLD}${ARROW_RIGHT}${COLOR_NC} ${COLOR_WHITE}Select [0-1]:${COLOR_NC} "
    read -r method_choice
  done

  if [ "$method_choice" == "0" ]; then
    PANEL_INSTALL_METHOD="release"
    output_success "Will download latest release tarball"
  else
    PANEL_INSTALL_METHOD="clone"
    output_success "Will clone from Git repository"
  fi
}

# ------------------ Domain Configuration ----------------- #

configure_fqdn() {
  print_header
  print_section "Domain Configuration" "$GLOBE"

  echo ""
  output_info "Please enter the domain or subdomain for your panel."
  echo -e "     ${COLOR_GRAY}Example:${COLOR_NC} ${COLOR_ORANGE}panel.example.com${COLOR_NC}"
  echo ""

  local valid_fqdn=false
  while [ "$valid_fqdn" == false ]; do
    required_input PANEL_FQDN "Domain/Subdomain: " "Domain is required"

    if check_fqdn "$PANEL_FQDN"; then
      # Verify DNS resolution
      output_info "Verifying DNS for ${COLOR_ORANGE}${PANEL_FQDN}${COLOR_NC}..."
      if bash <(curl -sSL "$GITHUB_URL/lib/verify-fqdn.sh") "$PANEL_FQDN"; then
        valid_fqdn=true
      else
        # DNS verification failed and user chose not to continue
        output_error "Please fix your DNS configuration or enter a different domain."
      fi
    else
      output_error "Invalid FQDN format. Must be a valid domain name (not IP address)."
    fi
  done

  output_success "Domain configured: ${COLOR_ORANGE}${PANEL_FQDN}${COLOR_NC}"
}

# ------------------ SSL Configuration ----------------- #

configure_ssl() {
  print_header
  print_section "SSL/TLS Configuration" "$LOCK"

  local use_ssl=""
  bool_input use_ssl "Would you like to use SSL/HTTPS?" "y"

  if [ "$use_ssl" == "y" ]; then
    echo ""
    print_menu_item "0" "Let's Encrypt" "auto-generated, requires domain to point to this server"
    print_menu_item "1" "Use existing SSL certificate" "provide your own certificate files"
    print_menu_item "2" "No SSL" "not recommended for production"
    echo ""

    local ssl_choice=""
    while [[ "$ssl_choice" != "0" && "$ssl_choice" != "1" && "$ssl_choice" != "2" ]]; do
      echo -ne "  ${COLOR_GOLD}${ARROW_RIGHT}${COLOR_NC} ${COLOR_WHITE}Select [0-2]:${COLOR_NC} "
      read -r ssl_choice
    done

    case "$ssl_choice" in
      0)
        CONFIGURE_LETSENCRYPT=true
        output_success "Will use Let's Encrypt for SSL"
        ;;
      1)
        required_input SSL_CERT_PATH "Path to SSL certificate: " "Path is required"
        required_input SSL_KEY_PATH "Path to SSL key: " "Path is required"
        output_success "Will use existing SSL certificate"
        ;;
      2)
        output_warning "SSL will not be configured"
        ;;
    esac
  fi
}

# ------------------ Database Configuration ----------------- #

configure_database() {
  print_header
  print_section "Database Configuration" "$DATABASE"

  local use_local_db=""
  bool_input use_local_db "Use local database?" "y"

  if [ "$use_local_db" == "n" ]; then
    required_input DB_HOST "Database host: " "Host is required"
    required_input DB_PORT "Database port [3306]: " "" "3306"
  fi

  echo ""
  output_info "Database credentials:"
  required_input DB_NAME "Database name [panel]: " "" "panel"
  required_input DB_USER "Database username [pyrodactyl]: " "" "pyrodactyl"
  password_input DB_PASSWORD "Database password: " "Password cannot be empty"
  output_success "Database configuration complete"
}

# ------------------ Timezone Configuration ----------------- #

configure_timezone() {
  print_header
  print_section "Timezone Configuration"

  output_info "Available timezones can be found at:"
  echo -e "     ${COLOR_CYAN}$(hyperlink "https://www.php.net/manual/en/timezones.php")${COLOR_NC}"
  echo ""

  required_input PANEL_TIMEZONE "Timezone [UTC]: " "" "UTC"
  print_kv "Timezone" "${PANEL_TIMEZONE}"
}

# ------------------ Admin Account ----------------- #

configure_admin_account() {
  print_header
  print_section "Admin Account Configuration" "$PACKAGE"

  output_info "Create your administrator account:"
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
      output_success "Password confirmed"
    else
      output_error "Passwords do not match. Please try again."
    fi
  done
}

# ------------------ Auto-Updater ----------------- #

configure_auto_updater() {
  print_header
  print_section "Auto-Updater Configuration" "$GEAR"

  local install_auto_update=""
  bool_input install_auto_update "Install auto-updater for the panel?" "y"

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
  print_section "Firewall Configuration"

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

  local ssl_type
  if [ "$CONFIGURE_LETSENCRYPT" == "true" ]; then
    ssl_type="Let's Encrypt"
  elif [ -n "$SSL_CERT_PATH" ]; then
    ssl_type="Custom Certificate"
  else
    ssl_type="None"
  fi

  printf "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}  ${COLOR_GOLD}%-18s${COLOR_NC} ${COLOR_WHITE}%-48s${COLOR_FIRE_ORANGE}│${COLOR_NC}\\n" "Repository:" "${PANEL_REPO} $([ "$PANEL_REPO_PRIVATE" == "true" ] && echo '(private)' || echo '(public)')"
  printf "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}  ${COLOR_GOLD}%-18s${COLOR_NC} ${COLOR_WHITE}%-48s${COLOR_FIRE_ORANGE}│${COLOR_NC}\\n" "Install Method:" "${PANEL_INSTALL_METHOD}"
  printf "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}  ${COLOR_GOLD}%-18s${COLOR_NC} ${COLOR_WHITE}%-48s${COLOR_FIRE_ORANGE}│${COLOR_NC}\\n" "Domain:" "${PANEL_FQDN}"
  printf "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}  ${COLOR_GOLD}%-18s${COLOR_NC} ${COLOR_WHITE}%-48s${COLOR_FIRE_ORANGE}│${COLOR_NC}\\n" "SSL:" "${ssl_type}"
  printf "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}  ${COLOR_GOLD}%-18s${COLOR_NC} ${COLOR_WHITE}%-48s${COLOR_FIRE_ORANGE}│${COLOR_NC}\\n" "Database:" "${DB_NAME}@${DB_HOST}:${DB_PORT}"
  printf "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}  ${COLOR_GOLD}%-18s${COLOR_NC} ${COLOR_WHITE}%-48s${COLOR_FIRE_ORANGE}│${COLOR_NC}\\n" "Timezone:" "${PANEL_TIMEZONE}"
  printf "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}  ${COLOR_GOLD}%-18s${COLOR_NC} ${COLOR_WHITE}%-48s${COLOR_FIRE_ORANGE}│${COLOR_NC}\\n" "Admin Email:" "${PANEL_ADMIN_EMAIL}"
  printf "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}  ${COLOR_GOLD}%-18s${COLOR_NC} ${COLOR_WHITE}%-48s${COLOR_FIRE_ORANGE}│${COLOR_NC}\\n" "Auto-Updater:" "$([ "$INSTALL_AUTO_UPDATER" == "true" ] && echo "${COLOR_LIME}Yes${COLOR_NC}" || echo "${COLOR_GRAY}No${COLOR_NC}")"
  printf "  ${COLOR_FIRE_ORANGE}│${COLOR_NC}  ${COLOR_GOLD}%-18s${COLOR_NC} ${COLOR_WHITE}%-48s${COLOR_FIRE_ORANGE}│${COLOR_NC}\\n" "Firewall:" "$([ "$CONFIGURE_FIREWALL" == "true" ] && echo "${COLOR_LIME}Yes${COLOR_NC}" || echo "${COLOR_GRAY}No${COLOR_NC}")"

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
  export PANEL_REPO
  export PANEL_REPO_PRIVATE
  export GITHUB_TOKEN
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
  export INSTALL_AUTO_UPDATER
  export SSL_CERT_PATH
  export SSL_KEY_PATH
  export DB_HOST
  export DB_PORT
  export DB_NAME
  export DB_USER
  export DB_PASSWORD
}

# ------------------ Main ----------------- #

main() {
  print_header
  print_section "Welcome to the Pyrodactyl Panel Installer" "$FIRE"

  # Show progress steps
  local total_steps=9
  local current_step=0

  ((current_step++))
  print_step $current_step $total_steps "Configuring Repository"
  configure_github_repository

  ((current_step++))
  print_step $current_step $total_steps "Selecting Installation Method"
  configure_installation_method

  ((current_step++))
  print_step $current_step $total_steps "Configuring Domain"
  configure_fqdn

  ((current_step++))
  print_step $current_step $total_steps "Configuring SSL/TLS"
  configure_ssl

  ((current_step++))
  print_step $current_step $total_steps "Configuring Database"
  configure_database

  ((current_step++))
  print_step $current_step $total_steps "Setting Timezone"
  configure_timezone

  ((current_step++))
  print_step $current_step $total_steps "Creating Admin Account"
  configure_admin_account

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
  run_installer "panel"
}

main
