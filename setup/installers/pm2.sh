#!/bin/bash

set -e

source "$(dirname "$0")/../utils/log.sh"

log_header "Installing PM2"

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    log_error "Node.js is not installed. Please install Node.js first."
    exit 1
fi

# Check if PM2 is already installed
if command -v pm2 &> /dev/null && ! is_force_mode; then
    log_info "PM2 is already installed: $(pm2 -v)"
    exit 0
fi

# Install PM2 globally
log_progress "Installing PM2 globally..."
sudo npm install -g pm2

if command -v pm2 &> /dev/null; then
    PM2_VERSION=$(pm2 -v)
    log_success "PM2 installed: $PM2_VERSION"
else
    log_error "PM2 installation failed"
    exit 1
fi

# Setup PM2 startup script for ubuntu user
log_progress "Configuring PM2 startup script..."
sudo env PATH=$PATH:/usr/bin pm2 startup systemd -u ubuntu --hp /home/ubuntu

log_success "PM2 startup configured for user 'ubuntu'"

# Generate ecosystem.config.js
log_progress "Generating PM2 ecosystem configuration..."

ECOSYSTEM_FILE="/home/ubuntu/ecosystem.config.js"

cat > "$ECOSYSTEM_FILE" << 'EOF'
module.exports = {
  apps: [
    {
      name: 'dashboard',
      cwd: '/home/ubuntu/dashboard',
      script: 'pnpm',
      args: 'start',
      instances: 1,
      autorestart: true,
      watch: false,
      max_memory_restart: '1G',
    },
    {
      name: 'api',
      cwd: '/home/ubuntu/api',
      script: 'pnpm',
      args: 'start',
      instances: 1,
      autorestart: true,
      watch: false,
      max_memory_restart: '1G',
    },
  ],
};
EOF

chown ubuntu:ubuntu "$ECOSYSTEM_FILE"
chmod 644 "$ECOSYSTEM_FILE"

log_success "PM2 ecosystem config created at $ECOSYSTEM_FILE"
log_info "Edit the config file to match your application structure"
log_info "Start your apps with: pm2 start ecosystem.config.js"
log_info "Save PM2 process list: pm2 save"

log_success "PM2 installation complete"
