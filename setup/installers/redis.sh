#!/bin/bash

set -e

source "$(dirname "$0")/../utils/log.sh"

log_header "Installing Redis"

# Check if Redis is already installed
if command -v redis-server &> /dev/null && ! is_force_mode; then
    log_info "Redis is already installed: $(redis-server --version)"
    exit 0
fi

# Install Redis
log_progress "Installing Redis..."
sudo apt-get update -qq
sudo apt-get install -y redis-server

# Configure Redis to bind to localhost only
log_progress "Configuring Redis..."
REDIS_CONF="/etc/redis/redis.conf"

if [ -f "$REDIS_CONF" ]; then
    # Backup original config
    sudo cp "$REDIS_CONF" "${REDIS_CONF}.backup"
    
    # Ensure Redis binds to localhost only
    sudo sed -i 's/^bind .*/bind 127.0.0.1 ::1/' "$REDIS_CONF"
    
    # Disable protected mode (safe since we're bound to localhost)
    sudo sed -i 's/^protected-mode yes/protected-mode no/' "$REDIS_CONF"
    
    # Set supervised to systemd
    sudo sed -i 's/^supervised no/supervised systemd/' "$REDIS_CONF"
    
    log_success "Redis configured for localhost access only"
else
    log_warn "Redis config file not found at expected location"
fi

# Start and enable Redis
log_progress "Starting Redis service..."
sudo systemctl start redis-server
sudo systemctl enable redis-server

# Verify installation
if systemctl is-active --quiet redis-server; then
    log_success "Redis service is running"
else
    log_error "Redis service failed to start"
    exit 1
fi

# Test Redis connection
if redis-cli ping &> /dev/null; then
    log_success "Redis is responding to commands"
else
    log_error "Redis is not responding"
    exit 1
fi

log_info "Redis connection: localhost:6379"
log_info "No authentication required (localhost-only access)"

log_success "Redis installation complete"
