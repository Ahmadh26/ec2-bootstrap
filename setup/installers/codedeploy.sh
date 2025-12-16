#!/bin/bash

set -e

source "$(dirname "$0")/../utils/log.sh"

log_header "Installing AWS CodeDeploy Agent"

# Check if CodeDeploy agent is already installed
if systemctl list-unit-files | grep -q codedeploy-agent && ! is_force_mode; then
    log_info "CodeDeploy agent is already installed"
    
    if systemctl is-active --quiet codedeploy-agent; then
        log_info "CodeDeploy agent is running"
    fi
    
    exit 0
fi

# Detect AWS region from instance metadata
log_progress "Detecting AWS region..."
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region 2>/dev/null || echo "us-east-1")
log_info "Detected region: $REGION"

# Install prerequisites
log_progress "Installing prerequisites..."
sudo apt-get update -qq
sudo apt-get install -y ruby wget

# Download CodeDeploy agent installer
log_progress "Downloading CodeDeploy agent installer..."
cd /tmp

INSTALLER_URL="https://aws-codedeploy-${REGION}.s3.${REGION}.amazonaws.com/latest/install"

wget -q "$INSTALLER_URL" -O install

if [ ! -f install ]; then
    log_error "Failed to download CodeDeploy installer"
    exit 1
fi

# Make installer executable
chmod +x install

# Run installer
log_progress "Installing CodeDeploy agent..."
sudo ./install auto

# Clean up
rm -f install

# Start and enable service
log_progress "Starting CodeDeploy agent service..."
sudo systemctl start codedeploy-agent
sudo systemctl enable codedeploy-agent

# Verify installation
if systemctl is-active --quiet codedeploy-agent; then
    log_success "CodeDeploy agent is running"
else
    log_error "CodeDeploy agent failed to start"
    exit 1
fi

# Check agent status
AGENT_STATUS=$(sudo systemctl status codedeploy-agent | grep "Active:" || echo "unknown")
log_info "Agent status: $AGENT_STATUS"

log_success "AWS CodeDeploy agent installation complete"
log_info "Region: $REGION"
log_info "The agent will automatically receive deployments from CodeDeploy"
