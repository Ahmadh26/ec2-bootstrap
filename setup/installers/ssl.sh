#!/bin/bash

set -e

source "$(dirname "$0")/../utils/log.sh"
source "$(dirname "$0")/../utils/secrets.sh"
source "$(dirname "$0")/../utils/prompt.sh"

log_header "Installing SSL Certificates (Let's Encrypt)"

# Check if Nginx is installed
if ! command -v nginx &> /dev/null; then
    log_error "Nginx is not installed. Please install Nginx first."
    exit 1
fi

# Check if certbot is already installed
CERTBOT_INSTALLED=false
if command -v certbot &> /dev/null; then
    CERTBOT_INSTALLED=true
    log_info "Certbot is already installed"
fi

# Install certbot via snap if not installed
if [ "$CERTBOT_INSTALLED" = false ]; then
    log_progress "Installing snapd..."
    sudo apt-get update -qq
    sudo apt-get install -y snapd
    
    log_progress "Installing certbot via snap..."
    sudo snap install core
    sudo snap refresh core
    sudo snap install --classic certbot
    
    # Create symlink
    sudo ln -sf /snap/bin/certbot /usr/bin/certbot
    
    log_success "Certbot installed"
fi

# Get domain from secrets
DOMAIN=$(get_secret "nginx.domain")

if [ -z "$DOMAIN" ]; then
    log_error "No domain configured in secrets"
    exit 1
fi

# Collect all subdomains that need certificates
SUBDOMAINS=()

# Get app subdomains
APP_NAMES=$(jq -r '.nginx.apps | keys[]' "$SECRETS_FILE" 2>/dev/null || echo "")
for APP_NAME in $APP_NAMES; do
    ROUTING_TYPE=$(get_secret "nginx.apps.$APP_NAME.routing_type")
    ROUTING_VALUE=$(get_secret "nginx.apps.$APP_NAME.routing_value")
    
    if [ "$ROUTING_TYPE" = "subdomain" ]; then
        FULL_DOMAIN="${ROUTING_VALUE}.${DOMAIN}"
        SUBDOMAINS+=("$FULL_DOMAIN")
    fi
done

# Get MailHog subdomain if configured
if has_secret "mailhog.routing_type"; then
    MAILHOG_ROUTING_TYPE=$(get_secret "mailhog.routing_type")
    if [ "$MAILHOG_ROUTING_TYPE" = "subdomain" ]; then
        MAILHOG_ROUTING_VALUE=$(get_secret "mailhog.routing_value")
        MAILHOG_DOMAIN="${MAILHOG_ROUTING_VALUE}.${DOMAIN}"
        SUBDOMAINS+=("$MAILHOG_DOMAIN")
    fi
fi

# Add root domain if needed
SUBDOMAINS+=("$DOMAIN")

# Remove duplicates
UNIQUE_SUBDOMAINS=($(printf "%s\n" "${SUBDOMAINS[@]}" | sort -u))

log_info "Domains to secure with SSL:"
for subdomain in "${UNIQUE_SUBDOMAINS[@]}"; do
    echo "  - $subdomain"
done

# Ask about wildcard certificate
log_info ""
if prompt_yesno "SSL Certificate Type" "Do you want to use a wildcard certificate (*.${DOMAIN})?\n\nNote: Wildcard requires DNS validation.\nChoose 'No' for individual certificates per subdomain (recommended for beginners)."; then
    USE_WILDCARD=true
    log_info "Using wildcard certificate"
else
    USE_WILDCARD=false
    log_info "Using individual certificates"
fi

# Prompt for email
EMAIL=$(prompt_input "Email Address" "Enter your email address for Let's Encrypt notifications:" "")
EMAIL=$(echo "$EMAIL" | tr -d '"')

if [ -z "$EMAIL" ]; then
    log_error "Email address is required"
    exit 1
fi

# Generate certificates
if [ "$USE_WILDCARD" = true ]; then
    log_progress "Requesting wildcard certificate for *.${DOMAIN}..."
    log_warn "You will need to add a DNS TXT record to verify domain ownership."
    
    sudo certbot certonly \
        --manual \
        --preferred-challenges dns \
        --email "$EMAIL" \
        --agree-tos \
        --no-eff-email \
        -d "*.${DOMAIN}" \
        -d "${DOMAIN}"
    
    if [ $? -eq 0 ]; then
        log_success "Wildcard certificate obtained"
        
        # Update all nginx configs to use SSL
        for subdomain in "${UNIQUE_SUBDOMAINS[@]}"; do
            log_progress "Configuring SSL for $subdomain..."
            sudo certbot install --cert-name "${DOMAIN}" --nginx -d "$subdomain" --redirect
        done
    else
        log_error "Failed to obtain wildcard certificate"
        exit 1
    fi
else
    # Individual certificates
    for subdomain in "${UNIQUE_SUBDOMAINS[@]}"; do
        log_progress "Requesting certificate for $subdomain..."
        
        # Check DNS before requesting certificate
        log_info "Verifying DNS for $subdomain..."
        if host "$subdomain" > /dev/null 2>&1; then
            log_success "DNS verified for $subdomain"
        else
            log_warn "DNS not found for $subdomain. Make sure DNS points to this server's IP."
            
            if ! prompt_yesno "Continue?" "DNS verification failed for $subdomain. Continue anyway?"; then
                log_info "Skipping $subdomain"
                continue
            fi
        fi
        
        sudo certbot --nginx \
            --email "$EMAIL" \
            --agree-tos \
            --no-eff-email \
            --redirect \
            -d "$subdomain"
        
        if [ $? -eq 0 ]; then
            log_success "Certificate obtained for $subdomain"
        else
            log_warn "Failed to obtain certificate for $subdomain"
        fi
    done
fi

# Setup auto-renewal
log_progress "Setting up automatic certificate renewal..."
sudo systemctl enable certbot.timer
sudo systemctl start certbot.timer

if systemctl is-active --quiet certbot.timer; then
    log_success "Auto-renewal timer enabled"
else
    log_warn "Failed to enable auto-renewal timer"
fi

# Test renewal process
log_progress "Testing certificate renewal process..."
if sudo certbot renew --dry-run &> /dev/null; then
    log_success "Certificate renewal test passed"
else
    log_warn "Certificate renewal test had issues"
fi

# Reload Nginx
log_progress "Reloading Nginx..."
sudo systemctl reload nginx

log_success "SSL certificate installation complete"
log_info "Your sites are now secured with HTTPS"
log_info "Certificates will auto-renew before expiration"
