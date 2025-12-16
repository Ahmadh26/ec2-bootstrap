#!/bin/bash

set -e

source "$(dirname "$0")/../utils/log.sh"
source "$(dirname "$0")/../utils/secrets.sh"

log_header "Installing PostgreSQL"

# Check if PostgreSQL is already installed
if command -v psql &> /dev/null && ! is_force_mode; then
    log_info "PostgreSQL is already installed: $(psql --version)"
    exit 0
fi

# Install PostgreSQL
log_progress "Installing PostgreSQL and contrib packages..."
sudo apt-get update -qq
sudo apt-get install -y postgresql postgresql-contrib

# Start and enable PostgreSQL
log_progress "Starting PostgreSQL service..."
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Verify installation
if systemctl is-active --quiet postgresql; then
    log_success "PostgreSQL service is running"
else
    log_error "PostgreSQL service failed to start"
    exit 1
fi

# Get credentials from secrets
PG_USER=$(get_secret "postgres.user")
PG_DATABASE=$(get_secret "postgres.database")
PG_PASSWORD=$(get_secret "postgres.password")

if [ -z "$PG_USER" ] || [ -z "$PG_DATABASE" ] || [ -z "$PG_PASSWORD" ]; then
    log_error "PostgreSQL credentials not found in secrets file"
    exit 1
fi

# Create database user
log_progress "Creating PostgreSQL user: $PG_USER"
sudo -u postgres psql -c "CREATE USER $PG_USER WITH PASSWORD '$PG_PASSWORD';" 2>/dev/null || \
    log_warn "User $PG_USER may already exist"

# Create database
log_progress "Creating database: $PG_DATABASE"
sudo -u postgres psql -c "CREATE DATABASE $PG_DATABASE OWNER $PG_USER;" 2>/dev/null || \
    log_warn "Database $PG_DATABASE may already exist"

# Grant privileges
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $PG_DATABASE TO $PG_USER;"

log_success "PostgreSQL user and database created"
log_info "Database: $PG_DATABASE"
log_info "User: $PG_USER"
log_info "Password: (stored in secrets file)"

# Configure PostgreSQL to listen only on localhost (security)
PG_VERSION=$(sudo -u postgres psql -tAc "SELECT version();" | grep -oP 'PostgreSQL \K[0-9]+')
PG_CONF="/etc/postgresql/${PG_VERSION}/main/postgresql.conf"

if [ -f "$PG_CONF" ]; then
    log_progress "Configuring PostgreSQL to listen on localhost only..."
    sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = 'localhost'/" "$PG_CONF"
    sudo systemctl restart postgresql
    log_success "PostgreSQL configured for localhost access only"
fi

# Display connection string
log_info "Connection string:"
echo "  postgresql://$PG_USER:$PG_PASSWORD@localhost:5432/$PG_DATABASE"

log_success "PostgreSQL installation complete"
