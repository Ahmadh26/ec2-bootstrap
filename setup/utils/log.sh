#!/bin/bash

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Log file
LOG_FILE="/tmp/ec2-setup.log"

# Initialize log file
init_log() {
    echo "=== EC2 Bootstrap Setup - $(date) ===" > "$LOG_FILE"
}

# Log to file
log_to_file() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Info message (blue)
log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
    log_to_file "INFO: $1"
}

# Success message (green)
log_success() {
    echo -e "${GREEN}✓${NC} $1"
    log_to_file "SUCCESS: $1"
}

# Warning message (yellow)
log_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    log_to_file "WARNING: $1"
}

# Error message (red)
log_error() {
    echo -e "${RED}✗${NC} $1" >&2
    log_to_file "ERROR: $1"
}

# Section header (cyan)
log_header() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    log_to_file "SECTION: $1"
}

# Progress message
log_progress() {
    echo -e "${CYAN}▶${NC} $1"
    log_to_file "PROGRESS: $1"
}
