# EC2 Bootstrap - Testing Checklist

## Pre-Installation

- [ ] Fresh Ubuntu 22.04 EC2 instance running
- [ ] SSH access configured
- [ ] Instance has internet connectivity
- [ ] DNS records configured (if using SSL)

## Installation Process

### 1. Run Setup Script

```bash
curl -fsSL https://raw.githubusercontent.com/Ahmadh26/ec2-bootstrap/main/setup/setup.sh | bash
```

- [ ] Script downloads successfully
- [ ] Whiptail and jq are installed automatically
- [ ] Welcome screen displays
- [ ] Component selection menu appears

### 2. Component Selection

- [ ] All 9 components listed with status
- [ ] Already installed components show "(Already installed)"
- [ ] Multiple selections work
- [ ] Selection is confirmed

### 3. Configuration Prompts

#### Node.js

- [ ] Version selection menu (18/20/22)
- [ ] Default to 20 selected

#### PostgreSQL

- [ ] Username prompt appears
- [ ] Database name prompt appears
- [ ] Defaults are reasonable

#### Nginx

- [ ] Domain name prompt
- [ ] App count prompt
- [ ] Per-app prompts (name, port, routing type)
- [ ] Subdomain routing selected by default
- [ ] Re-run mode offers add/reset options

#### MailHog

- [ ] Routing type prompt (subdomain/path)
- [ ] Basic auth yes/no prompt
- [ ] Credentials generated if enabled

### 4. Installation Execution

- [ ] Components install in correct order (dependencies)
- [ ] Progress messages are clear
- [ ] Success messages appear after each component
- [ ] No error messages displayed

### 5. Service Validation

- [ ] Status validation runs automatically
- [ ] Green checkmarks for running services
- [ ] All selected services show as "Running"

### 6. Completion Summary

- [ ] Summary displays installed components
- [ ] Secrets file location shown
- [ ] .env.example location shown
- [ ] ecosystem.config.js location shown (if PM2 installed)
- [ ] Next steps are clear

## Post-Installation Verification

### Files Created

```bash
# Check secrets file
ls -la /home/ubuntu/.ec2-setup-secrets.json
# Should be: -rw------- 1 ubuntu ubuntu

# Check environment template
ls -la /home/ubuntu/.env.example

# Check PM2 config (if PM2 installed)
ls -la /home/ubuntu/ecosystem.config.js

# Check state directory
ls -la /etc/ec2-setup/completed/

# Check log
ls -la /tmp/ec2-setup.log
```

- [ ] Secrets file exists with correct permissions (600)
- [ ] .env.example created
- [ ] ecosystem.config.js created (if PM2 selected)
- [ ] Completion markers exist for installed components
- [ ] Log file contains detailed information

### Service Status

```bash
# Node.js
node -v
npm -v
pnpm -v

# PM2
pm2 -v

# PostgreSQL
sudo systemctl status postgresql
psql -h localhost -U appuser -d myapp -c "SELECT version();"

# Redis
sudo systemctl status redis-server
redis-cli ping

# Nginx
sudo systemctl status nginx
curl -I http://localhost

# MailHog
sudo systemctl status mailhog
curl http://localhost:8025

# CodeDeploy
sudo systemctl status codedeploy-agent
```

- [ ] Node.js version correct
- [ ] pnpm installed
- [ ] PM2 installed (if selected)
- [ ] PostgreSQL running and accessible
- [ ] Redis running and responding
- [ ] Nginx running and serving
- [ ] MailHog running (if selected)
- [ ] CodeDeploy agent running (if selected)

### Nginx Configuration

```bash
# List configurations
ls -l /etc/nginx/sites-enabled/

# Test configuration
sudo nginx -t

# Check app configs
cat /etc/nginx/sites-enabled/app-*.conf
```

- [ ] Default site disabled
- [ ] App configurations created
- [ ] MailHog config created (if selected)
- [ ] nginx -t passes
- [ ] Correct upstreams configured
- [ ] WebSocket headers present

### Database Connectivity

```bash
# PostgreSQL
psql -h localhost -U appuser -d myapp -c "\l"
psql -h localhost -U appuser -d myapp -c "SELECT current_database(), current_user;"

# Redis
redis-cli INFO server
redis-cli SET testkey testvalue
redis-cli GET testkey
redis-cli DEL testkey
```

- [ ] PostgreSQL user exists
- [ ] Database created and accessible
- [ ] Correct ownership/privileges
- [ ] Redis accepts commands
- [ ] Redis stores/retrieves data

### Secrets Validation

```bash
# View secrets
cat /home/ubuntu/.ec2-setup-secrets.json

# Parse with jq
jq '.' /home/ubuntu/.ec2-setup-secrets.json

# Get specific values
jq -r '.postgres.password' /home/ubuntu/.ec2-setup-secrets.json
jq -r '.nginx.domain' /home/ubuntu/.ec2-setup-secrets.json
```

- [ ] Valid JSON format
- [ ] PostgreSQL credentials present
- [ ] Nginx configuration present
- [ ] MailHog credentials present (if auth enabled)
- [ ] Passwords are random (32+ chars)

### Environment Template

```bash
cat /home/ubuntu/.env.example
```

- [ ] PostgreSQL credentials included
- [ ] Redis connection info included
- [ ] MailHog SMTP info included
- [ ] App URLs included
- [ ] Formatted correctly

### SSL (if installed)

```bash
# List certificates
sudo certbot certificates

# Check renewal timer
sudo systemctl status certbot.timer

# Test renewal
sudo certbot renew --dry-run
```

- [ ] Certificates issued successfully
- [ ] Auto-renewal timer active
- [ ] Dry-run succeeds
- [ ] HTTPS redirects working

## Re-Run Testing

### Add Components

```bash
# Re-run setup
curl -fsSL https://raw.githubusercontent.com/Ahmadh26/ec2-bootstrap/main/setup/setup.sh | bash
```

- [ ] Installed components show "(Already installed)"
- [ ] Can select new components
- [ ] Existing components skipped automatically
- [ ] New components install successfully

### Add Nginx Apps

```bash
# Re-run with nginx already installed
```

- [ ] Prompted to add or reset
- [ ] Add mode preserves existing configs
- [ ] New app configs created
- [ ] No conflicts with existing configs

### Force Mode

```bash
# Force reinstall
curl -fsSL https://raw.githubusercontent.com/Ahmadh26/ec2-bootstrap/main/setup/setup.sh | bash -s -- --force
```

- [ ] Markers cleared
- [ ] All components show as not installed
- [ ] Can reinstall everything
- [ ] Services restarted/reconfigured

## Error Handling

### Network Issues

- [ ] Graceful handling of download failures
- [ ] Clear error messages
- [ ] Continues with other components

### Service Failures

- [ ] Failed services logged
- [ ] Error shown but installation continues
- [ ] Log file contains detailed error info

### Invalid Input

- [ ] Invalid domain names handled
- [ ] Invalid ports rejected
- [ ] Empty inputs have defaults

## Idempotency

- [ ] Re-running same config doesn't break anything
- [ ] Services remain running
- [ ] Configs not duplicated
- [ ] Secrets not regenerated

## Cleanup Testing

```bash
# Test manual cleanup procedures from README
```

- [ ] PostgreSQL uninstall works
- [ ] Redis uninstall works
- [ ] Nginx uninstall works
- [ ] MailHog uninstall works
- [ ] Node.js uninstall works
- [ ] PM2 uninstall works
- [ ] Markers can be removed
- [ ] Secrets can be deleted

## GitHub SSH (if installed)

```bash
# Test SSH connection
ssh -T git@github.com
```

- [ ] SSH key generated
- [ ] Public key displayed
- [ ] User prompted to add to GitHub
- [ ] Connection test runs
- [ ] Successful authentication confirmed

## Performance

- [ ] Total installation time < 10 minutes (without SSL)
- [ ] No hanging processes
- [ ] Reasonable resource usage
- [ ] Services start quickly

## Documentation

- [ ] README.md is complete
- [ ] QUICK_REFERENCE.md is helpful
- [ ] Examples are accurate
- [ ] Troubleshooting section is useful

## Edge Cases

- [ ] Running as non-ubuntu user (should work)
- [ ] Running on non-AWS EC2 (CodeDeploy region detection)
- [ ] Multiple domains for SSL
- [ ] Path-based routing instead of subdomain
- [ ] No domain (nginx without SSL)
- [ ] Single app configuration
- [ ] 5+ apps configuration

## Final Checks

- [ ] All scripts have correct permissions (755)
- [ ] All scripts have shebang lines
- [ ] No hardcoded credentials
- [ ] Logs are readable
- [ ] Exit codes are correct
- [ ] Colors display properly
- [ ] Whiptail menus are user-friendly

## Test Scenarios

### Scenario 1: Full Stack

- Select all 9 components
- Configure 2 apps (frontend + backend)
- Enable SSL with individual certs
- Enable MailHog auth

### Scenario 2: Minimal

- Only Node.js + Nginx
- Single app
- No SSL
- No database

### Scenario 3: Database Only

- PostgreSQL + Redis
- No web services
- Verify localhost-only binding

### Scenario 4: Re-run and Add

1. Install Node + Nginx + 1 app
2. Re-run and add PostgreSQL
3. Re-run and add 2 more Nginx apps
4. Verify all working together

### Scenario 5: Force Reinstall

1. Install everything
2. Make manual changes to configs
3. Run with --force
4. Verify clean reinstall

---

## Test Results Template

```
Date: _______________
Tester: _______________
Instance: _______________
Region: _______________

Components Tested:
[ ] Node.js
[ ] PM2
[ ] PostgreSQL
[ ] Redis
[ ] MailHog
[ ] Nginx
[ ] SSL
[ ] CodeDeploy
[ ] GitHub SSH

Installation Time: _____ minutes

Issues Found:
1.
2.
3.

Overall Status: PASS / FAIL

Notes:


```
