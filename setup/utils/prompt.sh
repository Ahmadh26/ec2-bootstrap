#!/bin/bash

# Check if whiptail is available
check_whiptail() {
    if ! command -v whiptail &> /dev/null; then
        return 1
    fi
    return 0
}

# Checklist menu - returns space-separated list of selected items
# Usage: prompt_checklist "Title" "Description" "item1" "description1" "status1" "item2" "description2" "status2" ...
prompt_checklist() {
    local title="$1"
    local description="$2"
    shift 2
    
    local options=()
    while [ $# -gt 0 ]; do
        local tag="$1"
        local item="$2"
        local status="$3"
        options+=("$tag" "$item" "$status")
        shift 3
    done
    
    whiptail --title "$title" \
        --checklist "$description" \
        20 78 10 \
        "${options[@]}" \
        3>&1 1>&2 2>&3
}

# Input box - returns user input
# Usage: prompt_input "Title" "Description" "Default value"
prompt_input() {
    local title="$1"
    local description="$2"
    local default="${3:-}"
    
    whiptail --title "$title" \
        --inputbox "$description" \
        10 78 "$default" \
        3>&1 1>&2 2>&3
}

# Yes/No question - returns 0 for yes, 1 for no
# Usage: prompt_yesno "Title" "Question"
prompt_yesno() {
    local title="$1"
    local question="$2"
    
    whiptail --title "$title" \
        --yesno "$question" \
        10 78 \
        3>&1 1>&2 2>&3
    
    return $?
}

# Menu selection - returns selected item
# Usage: prompt_menu "Title" "Description" "item1" "description1" "item2" "description2" ...
prompt_menu() {
    local title="$1"
    local description="$2"
    shift 2
    
    local options=()
    while [ $# -gt 0 ]; do
        local tag="$1"
        local item="$2"
        options+=("$tag" "$item")
        shift 2
    done
    
    whiptail --title "$title" \
        --menu "$description" \
        20 78 10 \
        "${options[@]}" \
        3>&1 1>&2 2>&3
}

# Message box - displays information
# Usage: prompt_msgbox "Title" "Message"
prompt_msgbox() {
    local title="$1"
    local message="$2"
    
    whiptail --title "$title" \
        --msgbox "$message" \
        20 78 \
        3>&1 1>&2 2>&3
}

# Radio list - single selection
# Usage: prompt_radiolist "Title" "Description" "item1" "description1" "status1" "item2" "description2" "status2" ...
prompt_radiolist() {
    local title="$1"
    local description="$2"
    shift 2
    
    local options=()
    while [ $# -gt 0 ]; do
        local tag="$1"
        local item="$2"
        local status="$3"
        options+=("$tag" "$item" "$status")
        shift 3
    done
    
    whiptail --title "$title" \
        --radiolist "$description" \
        20 78 10 \
        "${options[@]}" \
        3>&1 1>&2 2>&3
}
