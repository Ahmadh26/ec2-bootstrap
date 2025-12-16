#!/bin/bash

set -e

# Detect if running via curl | bash (stdin)
if [ ! -t 0 ] && [ -z "${BASH_SOURCE[0]}" -o "${BASH_SOURCE[0]}" = "bash" ]; then
    echo "Detected piped execution. Downloading setup files..."
    
    # Create temporary directory
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    # Download the entire setup directory
    REPO_URL="https://github.com/Ahmadh26/ec2-bootstrap"
    BRANCH="main"
    
    echo "Downloading from $REPO_URL..."
    
    # Try git clone first (faster), fallback to wget
    if command -v git &> /dev/null; then
        git clone --depth 1 --branch "$BRANCH" "$REPO_URL.git" . 2>/dev/null || {
            echo "Git clone failed, trying wget..."
            wget -q "$REPO_URL/archive/refs/heads/$BRANCH.tar.gz" -O repo.tar.gz
            tar -xzf repo.tar.gz --strip-components=1
            rm repo.tar.gz
        }
    else
        wget -q "$REPO_URL/archive/refs/heads/$BRANCH.tar.gz" -O repo.tar.gz
        tar -xzf repo.tar.gz --strip-components=1
        rm repo.tar.gz
    fi
    
    # Execute the downloaded script
    echo "Executing setup..."
    cd setup
    exec bash setup.sh "$@"
    exit 0
fi

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source utility scripts
source "$SCRIPT_DIR/utils/log.sh"
source "$SCRIPT_DIR/utils/prompt.sh"
source "$SCRIPT_DIR/utils/secrets.sh"
source "$SCRIPT_DIR/utils/state.sh"

# Configuration
FORCE_MODE=false
SELECTED_COMPONENTS=()
NODE_VERSION=""
NGINX_CONFIG=()

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force)
                FORCE_MODE=true
                set_force_mode
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Usage: $0 [--force]"
                exit 1
                ;;
        esac
    done
}

# Check and install prerequisites
install_prerequisites() {
    log_header "Checking Prerequisites"
    
    local needs_update=false
    
    # Check for whiptail
    if ! command -v whiptail &> /dev/null; then
        log_info "Installing whiptail..."
        needs_update=true
    fi
    
    # Check for jq
    if ! command -v jq &> /dev/null; then
        log_info "Installing jq..."
        needs_update=true
    fi
    
    if [ "$needs_update" = true ]; then
        sudo apt-get update -qq
        
        if ! command -v whiptail &> /dev/null; then
            sudo apt-get install -y whiptail
            log_success "Installed whiptail"
        fi
        
        if ! command -v jq &> /dev/null; then
            sudo apt-get install -y jq
            log_success "Installed jq"
        fi
    else
        log_success "All prerequisites are installed"
    fi
}

# Show welcome message
show_welcome() {
    clear
    prompt_msgbox "EC2 Bootstrap Setup" \
        "Welcome to the EC2 Bootstrap Setup!\n\nThis interactive script will help you install and configure common services for your NestJS/Next.js backend stack.\n\nSupported components:\n- Node.js + pnpm\n- PM2\n- Nginx\n- SSL (Let's Encrypt)\n- PostgreSQL\n- Redis\n- MailHog\n- AWS CodeDeploy Agent\n- GitHub SSH Access\n\nPress OK to continue..."
}

# Select components to install
select_components() {
    log_header "Component Selection"
    
    local node_status=$(get_status_label "node")
    local pm2_status=$(get_status_label "pm2")
    local nginx_status=$(get_status_label "nginx")
    local ssl_status=$(get_status_label "ssl")
    local postgres_status=$(get_status_label "postgres")
    local redis_status=$(get_status_label "redis")
    local mailhog_status=$(get_status_label "mailhog")
    local codedeploy_status=$(get_status_label "codedeploy")
    local github_status=$(get_status_label "github_ssh")
    
    local selection=$(prompt_checklist "Select Components" \
        "Use SPACE to select/deselect, ARROW keys to navigate, ENTER to confirm:" \
        "node" "Node.js + pnpm $node_status" "OFF" \
        "pm2" "PM2 Process Manager $pm2_status" "OFF" \
        "nginx" "Nginx Web Server $nginx_status" "OFF" \
        "ssl" "SSL/Let's Encrypt $ssl_status" "OFF" \
        "postgres" "PostgreSQL Database $postgres_status" "OFF" \
        "redis" "Redis Cache $redis_status" "OFF" \
        "mailhog" "MailHog Email Testing $mailhog_status" "OFF" \
        "codedeploy" "AWS CodeDeploy Agent $codedeploy_status" "OFF" \
        "github_ssh" "GitHub SSH Setup $github_status" "OFF")
    
    if [ -z "$selection" ]; then
        log_error "No components selected. Exiting."
        exit 0
    fi
    
    # Convert selection to array
    SELECTED_COMPONENTS=($(echo "$selection" | tr -d '"'))
    
    log_info "Selected components: ${SELECTED_COMPONENTS[*]}"
}

# Prompt for Node.js version
prompt_node_version() {
    if [[ " ${SELECTED_COMPONENTS[@]} " =~ " node " ]]; then
        NODE_VERSION=$(prompt_radiolist "Node.js Version" \
            "Select the Node.js LTS version to install:" \
            "20" "Node.js 20 LTS (Recommended)" "ON" \
            "18" "Node.js 18 LTS" "OFF" \
            "22" "Node.js 22 LTS" "OFF")
        
        NODE_VERSION=$(echo "$NODE_VERSION" | tr -d '"')
        log_info "Selected Node.js version: $NODE_VERSION"
    fi
}

# Reorder components based on dependencies
reorder_components() {
    local ordered=()
    
    # Node must come before PM2
    if [[ " ${SELECTED_COMPONENTS[@]} " =~ " node " ]]; then
        ordered+=("node")
    fi
    
    # Add other components in dependency order
    for component in postgres redis mailhog nginx codedeploy github_ssh; do
        if [[ " ${SELECTED_COMPONENTS[@]} " =~ " $component " ]]; then
            ordered+=("$component")
        fi
    done
    
    # PM2 after Node
    if [[ " ${SELECTED_COMPONENTS[@]} " =~ " pm2 " ]]; then
        ordered+=("pm2")
    fi
    
    # SSL must come after Nginx
    if [[ " ${SELECTED_COMPONENTS[@]} " =~ " ssl " ]]; then
        if [[ ! " ${ordered[@]} " =~ " nginx " ]]; then
            log_warn "SSL requires Nginx. Adding Nginx to installation list."
            ordered+=("nginx")
        fi
        ordered+=("ssl")
    fi
    
    SELECTED_COMPONENTS=("${ordered[@]}")
    log_info "Installation order: ${SELECTED_COMPONENTS[*]}"
}

# Configure PostgreSQL
configure_postgres() {
    if [[ " ${SELECTED_COMPONENTS[@]} " =~ " postgres " ]]; then
        log_header "PostgreSQL Configuration"
        
        local pg_user=$(prompt_input "PostgreSQL User" "Enter the PostgreSQL username to create:" "appuser")
        pg_user=$(echo "$pg_user" | tr -d '"')
        
        local pg_database=$(prompt_input "PostgreSQL Database" "Enter the PostgreSQL database name to create:" "$pg_user")
        pg_database=$(echo "$pg_database" | tr -d '"')
        
        local pg_password=$(generate_password 32)
        
        set_secret "postgres.user" "$pg_user"
        set_secret "postgres.database" "$pg_database"
        set_secret "postgres.password" "$pg_password"
        
        log_success "PostgreSQL configuration saved"
    fi
}

# Configure Nginx applications
configure_nginx() {
    if [[ " ${SELECTED_COMPONENTS[@]} " =~ " nginx " ]]; then
        log_header "Nginx Configuration"
        
        # Check if nginx is already installed and we're adding apps
        if is_completed "nginx" && ! is_force_mode; then
            if prompt_yesno "Nginx Setup" "Nginx is already installed. Do you want to add new app configurations?"; then
                set_secret "nginx.mode" "add"
            else
                if prompt_yesno "Nginx Setup" "Do you want to completely re-setup Nginx (this will backup existing configs)?"; then
                    set_secret "nginx.mode" "reset"
                else
                    log_info "Skipping Nginx configuration"
                    return
                fi
            fi
        else
            set_secret "nginx.mode" "new"
        fi
        
        local app_count=$(prompt_input "Number of Apps" "How many applications do you want to configure with Nginx?" "2")
        app_count=$(echo "$app_count" | tr -d '"')
        
        set_secret "nginx.app_count" "$app_count"
        
        # Get primary domain
        local domain=$(prompt_input "Domain Name" "Enter your primary domain name (e.g., example.com):" "")
        domain=$(echo "$domain" | tr -d '"')
        set_secret "nginx.domain" "$domain"
        
        # Configure each app
        for ((i=1; i<=app_count; i++)); do
            log_info "Configuring app $i of $app_count"
            
            local app_name=$(prompt_input "App $i - Name" "Enter a name for this app (e.g., frontend, backend, api):" "app$i")
            app_name=$(echo "$app_name" | tr -d '"')
            
            local app_port=$(prompt_input "App $i - Port" "Enter the port this app runs on:" "$((3000 + i - 1))")
            app_port=$(echo "$app_port" | tr -d '"')
            
            local routing_type=$(prompt_radiolist "App $i - Routing" \
                "How should this app be accessed?" \
                "subdomain" "Subdomain (e.g., app.example.com)" "ON" \
                "path" "Path-based (e.g., example.com/app)" "OFF")
            routing_type=$(echo "$routing_type" | tr -d '"')
            
            local routing_value=""
            if [ "$routing_type" = "subdomain" ]; then
                routing_value=$(prompt_input "App $i - Subdomain" "Enter the subdomain (e.g., 'api' for api.example.com):" "$app_name")
            else
                routing_value=$(prompt_input "App $i - Path" "Enter the path (e.g., '/api' for example.com/api):" "/$app_name")
            fi
            routing_value=$(echo "$routing_value" | tr -d '"')
            
            set_secret "nginx.apps.$app_name.port" "$app_port"
            set_secret "nginx.apps.$app_name.routing_type" "$routing_type"
            set_secret "nginx.apps.$app_name.routing_value" "$routing_value"
        done
        
        log_success "Nginx configuration saved"
    fi
}

# Configure MailHog
configure_mailhog() {
    if [[ " ${SELECTED_COMPONENTS[@]} " =~ " mailhog " ]]; then
        log_header "MailHog Configuration"
        
        local routing_type=$(prompt_radiolist "MailHog Routing" \
            "How should MailHog UI be accessed?" \
            "subdomain" "Subdomain (e.g., mail.example.com)" "ON" \
            "path" "Path-based (e.g., example.com/mail)" "OFF")
        routing_type=$(echo "$routing_type" | tr -d '"')
        
        local routing_value=""
        if [ "$routing_type" = "subdomain" ]; then
            routing_value=$(prompt_input "MailHog Subdomain" "Enter the subdomain for MailHog:" "mail")
        else
            routing_value=$(prompt_input "MailHog Path" "Enter the path for MailHog:" "/mail")
        fi
        routing_value=$(echo "$routing_value" | tr -d '"')
        
        set_secret "mailhog.routing_type" "$routing_type"
        set_secret "mailhog.routing_value" "$routing_value"
        
        if prompt_yesno "MailHog Authentication" "Do you want to enable basic authentication for MailHog?"; then
            set_secret "mailhog.auth_enabled" "true"
            
            local auth_user=$(prompt_input "MailHog Username" "Enter username for MailHog:" "admin")
            auth_user=$(echo "$auth_user" | tr -d '"')
            
            local auth_password=$(generate_password 16)
            
            set_secret "mailhog.auth_user" "$auth_user"
            set_secret "mailhog.auth_password" "$auth_password"
            
            log_success "MailHog authentication enabled"
        else
            set_secret "mailhog.auth_enabled" "false"
        fi
    fi
}

# Run installers
run_installers() {
    log_header "Installing Components"
    
    for component in "${SELECTED_COMPONENTS[@]}"; do
        if is_completed "$component"; then
            log_info "Skipping $component (already installed)"
            continue
        fi
        
        log_progress "Installing $component..."
        
        local installer="$SCRIPT_DIR/installers/$component.sh"
        if [ -f "$installer" ]; then
            # Export necessary variables
            export NODE_VERSION
            export SCRIPT_DIR
            
            if bash "$installer"; then
                mark_completed "$component"
                log_success "$component installed successfully"
            else
                log_error "$component installation failed! Check logs at /tmp/ec2-setup.log"
                log_warn "Continuing with remaining components..."
            fi
        else
            log_error "Installer not found: $installer"
        fi
    done
}

# Generate environment template
generate_env_template() {
    log_header "Generating Environment Files"
    
    local env_file="/home/ubuntu/.env.example"
    bash "$SCRIPT_DIR/templates/generate-env.sh" > "$env_file"
    chown ubuntu:ubuntu "$env_file"
    chmod 644 "$env_file"
    
    log_success "Environment template created at $env_file"
}

# Validate installed services
validate_services() {
    log_header "Service Status Validation"
    
    local all_ok=true
    
    for component in "${SELECTED_COMPONENTS[@]}"; do
        case "$component" in
            postgres)
                if systemctl is-active --quiet postgresql; then
                    log_success "PostgreSQL: Running"
                else
                    log_error "PostgreSQL: Not running"
                    all_ok=false
                fi
                ;;
            redis)
                if systemctl is-active --quiet redis-server; then
                    log_success "Redis: Running"
                else
                    log_error "Redis: Not running"
                    all_ok=false
                fi
                ;;
            nginx)
                if systemctl is-active --quiet nginx; then
                    log_success "Nginx: Running"
                else
                    log_error "Nginx: Not running"
                    all_ok=false
                fi
                ;;
            mailhog)
                if systemctl is-active --quiet mailhog; then
                    log_success "MailHog: Running"
                else
                    log_error "MailHog: Not running"
                    all_ok=false
                fi
                ;;
            codedeploy)
                if systemctl is-active --quiet codedeploy-agent; then
                    log_success "CodeDeploy Agent: Running"
                else
                    log_error "CodeDeploy Agent: Not running"
                    all_ok=false
                fi
                ;;
            node)
                if command -v node &> /dev/null; then
                    log_success "Node.js: $(node -v)"
                else
                    log_error "Node.js: Not found"
                    all_ok=false
                fi
                ;;
            pm2)
                if command -v pm2 &> /dev/null; then
                    log_success "PM2: Installed"
                else
                    log_error "PM2: Not found"
                    all_ok=false
                fi
                ;;
        esac
    done
    
    return $([ "$all_ok" = true ] && echo 0 || echo 1)
}

# Show completion summary
show_summary() {
    log_header "Installation Complete!"
    
    echo ""
    log_success "Successfully installed components:"
    for component in "${SELECTED_COMPONENTS[@]}"; do
        echo "  - $component"
    done
    
    echo ""
    log_info "Important files:"
    echo "  - Secrets: $(show_secrets_location)"
    echo "  - Logs: /tmp/ec2-setup.log"
    
    if [ -f "/home/ubuntu/.env.example" ]; then
        echo "  - Environment template: /home/ubuntu/.env.example"
    fi
    
    if [ -f "/home/ubuntu/ecosystem.config.js" ]; then
        echo "  - PM2 config: /home/ubuntu/ecosystem.config.js"
    fi
    
    echo ""
    log_info "Next steps:"
    echo "  1. Review your secrets file: cat $(show_secrets_location)"
    echo "  2. Configure your applications using the .env.example file"
    echo "  3. Deploy your code and start with PM2"
    
    if [[ " ${SELECTED_COMPONENTS[@]} " =~ " ssl " ]]; then
        echo "  4. SSL certificates are configured and will auto-renew"
    fi
    
    echo ""
    log_warn "Keep your secrets file secure! It contains sensitive passwords."
    echo ""
}

# Main execution
main() {
    # Parse arguments
    parse_args "$@"
    
    # Initialize
    init_log
    init_state_dir
    init_secrets_file
    
    # Clear markers if force mode
    if is_force_mode; then
        clear_all_markers
    fi
    
    # Install prerequisites
    install_prerequisites
    
    # Show welcome
    show_welcome
    
    # Select components
    select_components
    
    # Reorder based on dependencies
    reorder_components
    
    # Prompt for Node.js version
    prompt_node_version
    
    # Configure components
    configure_postgres
    configure_nginx
    configure_mailhog
    
    # Run installers
    run_installers
    
    # Generate environment template
    if [ ${#SELECTED_COMPONENTS[@]} -gt 0 ]; then
        generate_env_template
    fi
    
    # Validate services
    validate_services
    
    # Show summary
    show_summary
}

# Run main function
main "$@"
