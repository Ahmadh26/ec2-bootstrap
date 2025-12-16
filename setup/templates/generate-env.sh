#!/bin/bash

# Generate .env.example file from secrets
# This script reads from the secrets file and generates a template

SECRETS_FILE="/home/ubuntu/.ec2-setup-secrets.json"

if [ ! -f "$SECRETS_FILE" ]; then
    echo "# No secrets file found"
    exit 0
fi

cat << 'EOF'
# ========================================
# EC2 Bootstrap - Environment Variables
# ========================================
# Generated automatically by EC2 Bootstrap Setup
# Copy this file to .env and use in your applications
#

EOF

# PostgreSQL configuration
if jq -e '.postgres' "$SECRETS_FILE" > /dev/null 2>&1; then
    PG_USER=$(jq -r '.postgres.user // empty' "$SECRETS_FILE")
    PG_PASSWORD=$(jq -r '.postgres.password // empty' "$SECRETS_FILE")
    PG_DATABASE=$(jq -r '.postgres.database // empty' "$SECRETS_FILE")
    
    if [ -n "$PG_USER" ]; then
        cat << EOF
# ========================================
# PostgreSQL Database
# ========================================
DB_HOST=localhost
DB_PORT=5432
DB_USER=$PG_USER
DB_PASSWORD=$PG_PASSWORD
DB_NAME=$PG_DATABASE

# Full connection string
DATABASE_URL=postgresql://$PG_USER:$PG_PASSWORD@localhost:5432/$PG_DATABASE

EOF
    fi
fi

# Redis configuration
if command -v redis-server &> /dev/null; then
    cat << 'EOF'
# ========================================
# Redis Cache
# ========================================
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_URL=redis://localhost:6379

EOF
fi

# MailHog configuration
if systemctl is-active --quiet mailhog 2>/dev/null; then
    cat << 'EOF'
# ========================================
# MailHog (Email Testing)
# ========================================
MAIL_HOST=localhost
MAIL_PORT=1025
MAIL_SECURE=false
MAIL_FROM=noreply@example.com

EOF
fi

# Nginx/Domain configuration
if jq -e '.nginx' "$SECRETS_FILE" > /dev/null 2>&1; then
    DOMAIN=$(jq -r '.nginx.domain // empty' "$SECRETS_FILE")
    
    if [ -n "$DOMAIN" ]; then
        cat << EOF
# ========================================
# Application URLs
# ========================================
DOMAIN=$DOMAIN

EOF
        
        # List all configured apps
        APP_NAMES=$(jq -r '.nginx.apps | keys[]' "$SECRETS_FILE" 2>/dev/null || echo "")
        
        for APP_NAME in $APP_NAMES; do
            APP_PORT=$(jq -r ".nginx.apps.\"$APP_NAME\".port" "$SECRETS_FILE")
            ROUTING_TYPE=$(jq -r ".nginx.apps.\"$APP_NAME\".routing_type" "$SECRETS_FILE")
            ROUTING_VALUE=$(jq -r ".nginx.apps.\"$APP_NAME\".routing_value" "$SECRETS_FILE")
            
            UPPER_NAME=$(echo "$APP_NAME" | tr '[:lower:]' '[:upper:]' | tr '-' '_')
            
            echo "# $APP_NAME"
            echo "${UPPER_NAME}_PORT=$APP_PORT"
            
            if [ "$ROUTING_TYPE" = "subdomain" ]; then
                echo "${UPPER_NAME}_URL=https://${ROUTING_VALUE}.${DOMAIN}"
            else
                echo "${UPPER_NAME}_URL=https://${DOMAIN}${ROUTING_VALUE}"
            fi
            echo ""
        done
    fi
fi

# Node.js environment
cat << 'EOF'
# ========================================
# Application Configuration
# ========================================
NODE_ENV=production
PORT=3000

# API Keys and Secrets
# Add your own API keys here
# JWT_SECRET=your-secret-key-here
# API_KEY=your-api-key-here

EOF

# Additional information
cat << 'EOF'
# ========================================
# Notes
# ========================================
# - Update PORT to match your application's port
# - Replace placeholder values with actual secrets
# - Never commit this file to version control
# - Keep credentials secure and rotate regularly
EOF
