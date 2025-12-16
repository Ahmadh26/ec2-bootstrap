#!/bin/bash

set -e

source "$(dirname "$0")/../utils/log.sh"

log_header "Installing MailHog"

MAILHOG_VERSION="v1.0.1"
MAILHOG_URL="https://github.com/mailhog/MailHog/releases/download/${MAILHOG_VERSION}/MailHog_linux_amd64"
MAILHOG_BIN="/usr/local/bin/mailhog"

# Check if MailHog is already installed
if [ -f "$MAILHOG_BIN" ] && ! is_force_mode; then
    log_info "MailHog is already installed"
    
    if systemctl is-active --quiet mailhog; then
        log_info "MailHog service is running"
    fi
    
    exit 0
fi

# Download MailHog binary
log_progress "Downloading MailHog ${MAILHOG_VERSION}..."
sudo wget -q -O "$MAILHOG_BIN" "$MAILHOG_URL"

# Make it executable
sudo chmod +x "$MAILHOG_BIN"

# Verify download
if [ ! -f "$MAILHOG_BIN" ]; then
    log_error "Failed to download MailHog"
    exit 1
fi

log_success "MailHog binary installed at $MAILHOG_BIN"

# Create systemd service file
log_progress "Creating systemd service..."

MAILHOG_SERVICE="/etc/systemd/system/mailhog.service"

sudo tee "$MAILHOG_SERVICE" > /dev/null << 'EOF'
[Unit]
Description=MailHog Email Testing Tool
After=network.target

[Service]
Type=simple
User=ubuntu
ExecStart=/usr/local/bin/mailhog
Restart=on-failure
RestartSec=10

# Environment variables
Environment="MH_SMTP_BIND_ADDR=0.0.0.0:1025"
Environment="MH_UI_BIND_ADDR=0.0.0.0:8025"
Environment="MH_API_BIND_ADDR=0.0.0.0:8025"
Environment="MH_STORAGE=memory"

[Install]
WantedBy=multi-user.target
EOF

log_success "Systemd service file created"

# Reload systemd and start MailHog
log_progress "Starting MailHog service..."
sudo systemctl daemon-reload
sudo systemctl start mailhog
sudo systemctl enable mailhog

# Verify service is running
if systemctl is-active --quiet mailhog; then
    log_success "MailHog service is running"
else
    log_error "MailHog service failed to start"
    exit 1
fi

log_info "MailHog SMTP: 0.0.0.0:1025"
log_info "MailHog UI: http://localhost:8025"
log_info "Configure your apps to use SMTP: localhost:1025 (no authentication)"

log_success "MailHog installation complete"
