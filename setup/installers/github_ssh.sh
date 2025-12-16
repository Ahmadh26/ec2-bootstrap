#!/bin/bash

set -e

source "$(dirname "$0")/../utils/log.sh"
source "$(dirname "$0")/../utils/prompt.sh"

log_header "Setting up GitHub SSH Access"

SSH_DIR="/home/ubuntu/.ssh"
SSH_KEY="$SSH_DIR/id_ed25519"
SSH_CONFIG="$SSH_DIR/config"

# Check if SSH key already exists
if [ -f "$SSH_KEY" ] && ! is_force_mode; then
    log_info "SSH key already exists at $SSH_KEY"
    
    if [ -f "${SSH_KEY}.pub" ]; then
        log_info "Public key:"
        cat "${SSH_KEY}.pub"
    fi
    
    exit 0
fi

# Create .ssh directory if it doesn't exist
if [ ! -d "$SSH_DIR" ]; then
    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"
fi

# Generate SSH key
log_progress "Generating ed25519 SSH key..."

ssh-keygen -t ed25519 -C "ubuntu@$(hostname)" -f "$SSH_KEY" -N ""

if [ $? -eq 0 ]; then
    log_success "SSH key generated successfully"
else
    log_error "Failed to generate SSH key"
    exit 1
fi

# Set correct permissions
chmod 600 "$SSH_KEY"
chmod 644 "${SSH_KEY}.pub"
chown -R ubuntu:ubuntu "$SSH_DIR"

# Create/update SSH config for GitHub
log_progress "Configuring SSH for GitHub..."

if [ ! -f "$SSH_CONFIG" ]; then
    touch "$SSH_CONFIG"
    chmod 600 "$SSH_CONFIG"
fi

# Add GitHub host configuration if not already present
if ! grep -q "Host github.com" "$SSH_CONFIG"; then
    cat >> "$SSH_CONFIG" << 'EOF'

# GitHub
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
EOF
    log_success "SSH config updated for GitHub"
fi

chown ubuntu:ubuntu "$SSH_CONFIG"

# Display public key
log_success "SSH key setup complete!"
echo ""
log_header "Your Public SSH Key"
echo ""
cat "${SSH_KEY}.pub"
echo ""

# Instructions for user
log_header "Next Steps"
echo ""
log_info "1. Copy the public key above"
log_info "2. Go to: https://github.com/settings/ssh/new"
log_info "3. Paste the key and give it a title (e.g., 'EC2 Instance')"
log_info "4. Click 'Add SSH key'"
echo ""

# Pause for user to add key to GitHub
prompt_msgbox "Add SSH Key to GitHub" \
    "Please add the SSH public key to your GitHub account now.\n\nThe key has been displayed above and is also saved at:\n${SSH_KEY}.pub\n\nSteps:\n1. Copy the public key\n2. Go to https://github.com/settings/ssh/new\n3. Paste and save\n\nPress OK when you've added the key..."

# Test SSH connection to GitHub
log_progress "Testing SSH connection to GitHub..."
echo ""

# Run as ubuntu user and capture output
sudo -u ubuntu ssh -T git@github.com 2>&1 | tee /tmp/github-ssh-test.log || true

# Check if connection was successful
if grep -q "successfully authenticated" /tmp/github-ssh-test.log; then
    log_success "Successfully authenticated with GitHub!"
elif grep -q "You've successfully authenticated" /tmp/github-ssh-test.log; then
    log_success "Successfully authenticated with GitHub!"
else
    log_warn "GitHub SSH test had unexpected output"
    log_info "You can test manually with: ssh -T git@github.com"
fi

rm -f /tmp/github-ssh-test.log

log_success "GitHub SSH setup complete"
log_info "You can now clone repositories using SSH:"
log_info "  git clone git@github.com:username/repository.git"
