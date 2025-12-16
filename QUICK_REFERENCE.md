# EC2 Bootstrap - Quick Reference

## Installation Commands

### Standard Installation

```bash
curl -fsSL https://raw.githubusercontent.com/Ahmadh26/ec2-bootstrap/main/setup/setup.sh | bash
```

### Force Reinstall

```bash
curl -fsSL https://raw.githubusercontent.com/Ahmadh26/ec2-bootstrap/main/setup/setup.sh | bash -s -- --force
```

## Component Ports

| Service            | Port | Access          |
| ------------------ | ---- | --------------- |
| Nginx HTTP         | 80   | Public          |
| Nginx HTTPS        | 443  | Public          |
| PostgreSQL         | 5432 | localhost only  |
| Redis              | 6379 | localhost only  |
| MailHog SMTP       | 1025 | localhost only  |
| MailHog UI         | 8025 | via Nginx proxy |
| Frontend (example) | 3000 | via Nginx proxy |
| Backend (example)  | 5001 | via Nginx proxy |

## Key Files

```
/home/ubuntu/.ec2-setup-secrets.json    # Credentials (chmod 600)
/home/ubuntu/.env.example               # Environment template
/home/ubuntu/ecosystem.config.js        # PM2 configuration
/etc/ec2-setup/completed/               # State markers
/tmp/ec2-setup.log                      # Installation log
```

## Common Commands

### View Secrets

```bash
cat /home/ubuntu/.ec2-setup-secrets.json
jq '.' /home/ubuntu/.ec2-setup-secrets.json
```

### Service Status

```bash
sudo systemctl status postgresql
sudo systemctl status redis-server
sudo systemctl status nginx
sudo systemctl status mailhog
sudo systemctl status codedeploy-agent
```

### PM2 Management

```bash
pm2 start ecosystem.config.js    # Start all apps
pm2 list                          # List running apps
pm2 logs                          # View logs
pm2 restart all                   # Restart all
pm2 save                          # Save process list
```

### Nginx Management

```bash
sudo nginx -t                     # Test configuration
sudo systemctl reload nginx       # Reload config
sudo systemctl restart nginx      # Restart service
ls /etc/nginx/sites-enabled/      # List enabled sites
```

### Database Access

```bash
# PostgreSQL
psql -h localhost -U appuser -d myapp

# Redis
redis-cli
```

### SSL Certificates

```bash
sudo certbot certificates         # List certificates
sudo certbot renew --dry-run      # Test renewal
sudo systemctl status certbot.timer  # Check auto-renewal timer
```

## Troubleshooting

### Check Logs

```bash
cat /tmp/ec2-setup.log
sudo tail -f /var/log/nginx/error.log
sudo journalctl -u nginx -f
sudo journalctl -u postgresql -f
```

### Re-run Specific Component

```bash
# Clear specific marker
sudo rm /etc/ec2-setup/completed/nginx

# Re-run setup (will only install nginx)
curl -fsSL https://raw.githubusercontent.com/Ahmadh26/ec2-bootstrap/main/setup/setup.sh | bash
```

### Reset Everything

```bash
# Clear all markers
sudo rm -rf /etc/ec2-setup

# Force reinstall
curl -fsSL https://raw.githubusercontent.com/Ahmadh26/ec2-bootstrap/main/setup/setup.sh | bash -s -- --force
```

## Directory Structure

```
setup/
├── setup.sh                 # Main script
├── installers/             # 9 component installers
│   ├── node.sh
│   ├── pm2.sh
│   ├── postgres.sh
│   ├── redis.sh
│   ├── mailhog.sh
│   ├── nginx.sh
│   ├── ssl.sh
│   ├── codedeploy.sh
│   └── github_ssh.sh
├── templates/
│   └── generate-env.sh     # Environment generator
└── utils/
    ├── log.sh              # Logging
    ├── prompt.sh           # Whiptail dialogs
    ├── secrets.sh          # Secret management
    └── state.sh            # State tracking
```

## Secrets JSON Schema

```json
{
  "postgres": {
    "user": "string",
    "password": "string (32 chars)",
    "database": "string"
  },
  "nginx": {
    "domain": "string",
    "mode": "new|add|reset",
    "app_count": number,
    "apps": {
      "app_name": {
        "port": number,
        "routing_type": "subdomain|path",
        "routing_value": "string"
      }
    }
  },
  "mailhog": {
    "routing_type": "subdomain|path",
    "routing_value": "string",
    "auth_enabled": "true|false",
    "auth_user": "string",
    "auth_password": "string (16 chars)"
  }
}
```

## Node.js Versions

- **18**: Node.js 18 LTS
- **20**: Node.js 20 LTS (Recommended)
- **22**: Node.js 22 LTS

## Nginx Routing Examples

### Subdomain (Default)

```
app.example.com  → localhost:3000
api.example.com  → localhost:5001
mail.example.com → localhost:8025
```

### Path-Based

```
example.com/      → localhost:3000
example.com/api   → localhost:5001
example.com/mail  → localhost:8025
```

## Security Best Practices

1. **Rotate secrets regularly**: Generate new passwords periodically
2. **Backup secrets file**: Keep `/home/ubuntu/.ec2-setup-secrets.json` backed up
3. **Use security groups**: Configure AWS security groups for firewall rules
4. **Update regularly**: Run `sudo apt update && sudo apt upgrade` periodically
5. **Monitor logs**: Check `/tmp/ec2-setup.log` and service logs regularly
6. **SSL renewal**: Certbot auto-renews, but monitor expiration dates
7. **Database backups**: Set up regular PostgreSQL backups

## Support

- **Issues**: https://github.com/Ahmadh26/ec2-bootstrap/issues
- **Logs**: `/tmp/ec2-setup.log`
- **Documentation**: See README.md
