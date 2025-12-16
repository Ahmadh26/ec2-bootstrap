#!/bin/bash

set -e

source "$(dirname "$0")/../utils/log.sh"

log_header "Installing Node.js"

# Check if Node.js is already installed
if command -v node &> /dev/null && ! is_force_mode; then
    CURRENT_VERSION=$(node -v)
    log_info "Node.js is already installed: $CURRENT_VERSION"
    
    if command -v pnpm &> /dev/null; then
        log_info "pnpm is already installed: $(pnpm -v)"
    else
        log_info "Installing pnpm..."
        sudo npm install -g pnpm
        log_success "pnpm installed successfully"
    fi
    
    exit 0
fi

# Get Node.js version from environment or default to 20
VERSION=${NODE_VERSION:-20}

log_info "Installing Node.js version $VERSION..."

# Remove any existing Node.js installations
if command -v node &> /dev/null; then
    log_info "Removing existing Node.js installation..."
    sudo apt-get remove -y nodejs npm 2>/dev/null || true
fi

# Install Node.js from NodeSource
log_progress "Setting up NodeSource repository..."
curl -fsSL https://deb.nodesource.com/setup_${VERSION}.x | sudo -E bash -

log_progress "Installing Node.js ${VERSION}.x..."
sudo apt-get install -y nodejs

# Verify installation
if command -v node &> /dev/null; then
    NODE_VERSION_INSTALLED=$(node -v)
    NPM_VERSION_INSTALLED=$(npm -v)
    log_success "Node.js installed: $NODE_VERSION_INSTALLED"
    log_success "npm installed: $NPM_VERSION_INSTALLED"
else
    log_error "Node.js installation failed"
    exit 1
fi

# Install pnpm globally
log_progress "Installing pnpm..."
sudo npm install -g pnpm

if command -v pnpm &> /dev/null; then
    PNPM_VERSION=$(pnpm -v)
    log_success "pnpm installed: $PNPM_VERSION"
else
    log_error "pnpm installation failed"
    exit 1
fi

log_success "Node.js and pnpm installation complete"
