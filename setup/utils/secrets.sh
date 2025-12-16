#!/bin/bash

SECRETS_FILE="/home/ubuntu/.ec2-setup-secrets.json"

# Generate a random password
generate_password() {
    local length="${1:-32}"
    openssl rand -base64 "$length" | tr -d "=+/" | cut -c1-"$length"
}

# Initialize secrets file if it doesn't exist
init_secrets_file() {
    if [ ! -f "$SECRETS_FILE" ]; then
        echo '{}' > "$SECRETS_FILE"
        chmod 600 "$SECRETS_FILE"
        chown ubuntu:ubuntu "$SECRETS_FILE"
    fi
}

# Add or update a secret using jq
# Usage: set_secret "path.to.key" "value"
# Example: set_secret "postgres.password" "mypassword"
set_secret() {
    local key_path="$1"
    local value="$2"
    
    init_secrets_file
    
    # Build jq path dynamically
    local jq_path=$(echo "$key_path" | sed 's/\./"]["/g')
    jq --arg val "$value" ".${key_path} = \$val" "$SECRETS_FILE" > "${SECRETS_FILE}.tmp"
    mv "${SECRETS_FILE}.tmp" "$SECRETS_FILE"
    chmod 600 "$SECRETS_FILE"
}

# Get a secret value
# Usage: get_secret "path.to.key"
get_secret() {
    local key_path="$1"
    
    if [ ! -f "$SECRETS_FILE" ]; then
        echo ""
        return 1
    fi
    
    jq -r ".${key_path} // empty" "$SECRETS_FILE"
}

# Check if a secret exists
# Usage: has_secret "path.to.key"
has_secret() {
    local key_path="$1"
    local value=$(get_secret "$key_path")
    
    [ -n "$value" ] && [ "$value" != "null" ]
}

# Generate and store a password if it doesn't exist
# Usage: ensure_password "path.to.key" [length]
ensure_password() {
    local key_path="$1"
    local length="${2:-32}"
    
    if ! has_secret "$key_path"; then
        local password=$(generate_password "$length")
        set_secret "$key_path" "$password"
    fi
    
    get_secret "$key_path"
}

# Display secrets file location
show_secrets_location() {
    echo "$SECRETS_FILE"
}

# Pretty print secrets (for display purposes only - masks sensitive data)
display_secrets_summary() {
    if [ ! -f "$SECRETS_FILE" ]; then
        echo "No secrets file found"
        return
    fi
    
    echo "Secrets stored in: $SECRETS_FILE"
    echo ""
    jq -r 'to_entries | .[] | "\(.key): ****"' "$SECRETS_FILE"
}
