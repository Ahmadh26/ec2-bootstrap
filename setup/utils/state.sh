#!/bin/bash

STATE_DIR="/etc/ec2-setup/completed"
FORCE_MODE=false

# Initialize state directory
init_state_dir() {
    if [ ! -d "$STATE_DIR" ]; then
        sudo mkdir -p "$STATE_DIR"
        sudo chmod 755 "$STATE_DIR"
    fi
}

# Set force mode
set_force_mode() {
    FORCE_MODE=true
}

# Check if force mode is enabled
is_force_mode() {
    [ "$FORCE_MODE" = true ]
}

# Clear all completion markers (used with --force)
clear_all_markers() {
    if [ -d "$STATE_DIR" ]; then
        sudo rm -f "$STATE_DIR"/*
        log_info "Cleared all completion markers"
    fi
}

# Mark a component as completed
mark_completed() {
    local component="$1"
    init_state_dir
    sudo touch "$STATE_DIR/$component"
    log_to_file "Marked $component as completed"
}

# Check if a component is completed
is_completed() {
    local component="$1"
    
    # If force mode is enabled, treat nothing as completed
    if is_force_mode; then
        return 1
    fi
    
    [ -f "$STATE_DIR/$component" ]
}

# Get completion status label
get_status_label() {
    local component="$1"
    
    if is_completed "$component"; then
        echo "(Already installed)"
    else
        echo ""
    fi
}

# List all completed components
list_completed() {
    if [ ! -d "$STATE_DIR" ]; then
        return
    fi
    
    ls "$STATE_DIR" 2>/dev/null | sort
}

# Remove a specific completion marker
remove_marker() {
    local component="$1"
    if [ -f "$STATE_DIR/$component" ]; then
        sudo rm -f "$STATE_DIR/$component"
        log_info "Removed completion marker for $component"
    fi
}

# Check if any components are installed
has_any_installed() {
    [ -d "$STATE_DIR" ] && [ -n "$(ls -A "$STATE_DIR" 2>/dev/null)" ]
}
