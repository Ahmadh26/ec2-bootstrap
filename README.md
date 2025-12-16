# EC2 Bootstrap Setup

**Interactive, idempotent setup script for Ubuntu 22.04 EC2 instances** — Install and configure a complete NestJS/Next.js backend stack with a single command.

## 🚀 Quick Start

SSH into your fresh Ubuntu 22.04 EC2 instance and run:

```bash
curl -fsSL https://raw.githubusercontent.com/Ahmadh26/ec2-bootstrap/main/setup/setup.sh | bash
```

### Force Reinstall

To reinstall components (clears completion markers):

```bash
curl -fsSL https://raw.githubusercontent.com/Ahmadh26/ec2-bootstrap/main/setup/setup.sh | bash -s -- --force
```

---

## 📦 Supported Components

The script provides an interactive checklist to select components:

| Component               | Description                                                  | Ports      |
| ----------------------- | ------------------------------------------------------------ | ---------- |
| **Node.js + pnpm**      | Node.js LTS (18/20/22) via NodeSource + pnpm package manager | -          |
| **PM2**                 | Process manager with auto-startup and ecosystem config       | -          |
| **Nginx**               | Web server with multi-app reverse proxy support              | 80, 443    |
| **SSL (Let's Encrypt)** | Free SSL certificates with auto-renewal                      | 443        |
| **PostgreSQL**          | Relational database (localhost-only)                         | 5432       |
| **Redis**               | In-memory cache (localhost-only)                             | 6379       |
| **MailHog**             | Email testing tool with SMTP + web UI                        | 1025, 8025 |
| **AWS CodeDeploy**      | Automated deployment agent                                   | -          |
| **GitHub SSH**          | SSH key generation for GitHub access                         | -          |

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  Internet                                                   │
└────────────────────┬────────────────────────────────────────┘
                     │
                ┌────▼─────┐
                │  Nginx   │  (Port 80/443)
                │ + SSL    │
                └────┬─────┘
                     │
        ┌────────────┼────────────┐
        │            │            │
   ┌────▼───┐   ┌───▼────┐  ┌───▼────────┐
   │Frontend│   │Backend │  │  MailHog   │
   │  :3000 │   │ :5001  │  │  UI :8025  │
   └────┬───┘   └───┬────┘  └────────────┘
        │           │
        └─────┬─────┘
              │
     ┌────────┼────────┐
     │        │        │
┌────▼───┐ ┌─▼──────┐ │
│PostreSQL│ │ Redis  │ │
│  :5432  │ │ :6379  │ │
└─────────┘ └────────┘ │
    (localhost)         │
                   ┌────▼────┐
                   │   PM2   │
                   │ Manager │
                   └─────────┘
```

---

## 🔄 Component Dependencies

The script automatically reorders installations based on dependencies:

```
Node.js → PM2
Nginx → SSL
```

---

## 🎯 Usage Flow

1. **Component Selection** — Interactive checklist with already-installed indicators
2. **Configuration Prompts**:
   - Node.js version (18/20/22)
   - PostgreSQL username and database name
   - Nginx apps (name, port, subdomain vs path routing)
   - MailHog routing and optional basic auth
3. **Installation** — Components installed in dependency order
4. **Validation** — Service status checks with green/red indicators
5. **Summary** — Shows installed components and generated files

---

## 🔐 Secrets Management

All credentials are stored in a secure JSON file:

**Location**: `/home/ubuntu/.ec2-setup-secrets.json` (chmod 600)

### Secrets Schema

```json
{
	"postgres": {
		"user": "appuser",
		"password": "generated-32-char-password",
		"database": "myapp"
	},
	"nginx": {
		"domain": "example.com",
		"mode": "new",
		"app_count": 2,
		"apps": {
			"frontend": {
				"port": 3000,
				"routing_type": "subdomain",
				"routing_value": "app"
			},
			"backend": {
				"port": 5001,
				"routing_type": "subdomain",
				"routing_value": "api"
			}
		}
	},
	"mailhog": {
		"routing_type": "subdomain",
		"routing_value": "mail",
		"auth_enabled": "true",
		"auth_user": "admin",
		"auth_password": "generated-16-char-password"
	}
}
```

### Accessing Secrets

```bash
# View secrets file
cat /home/ubuntu/.ec2-setup-secrets.json

# Pretty print with jq
jq '.' /home/ubuntu/.ec2-setup-secrets.json

# Get specific value
jq -r '.postgres.password' /home/ubuntu/.ec2-setup-secrets.json
```

---

## 📝 Generated Files

After installation, you'll find these files in `/home/ubuntu/`:

### `.env.example`

Environment variables template with all credentials and URLs:

```bash
# Copy to your app directory
cp /home/ubuntu/.env.example /home/ubuntu/my-app/.env

# View contents
cat /home/ubuntu/.env.example
```

### `ecosystem.config.js`

PM2 process configuration:

```javascript
module.exports = {
	apps: [
		{
			name: 'app-frontend',
			script: './dist/main.js',
			cwd: '/home/ubuntu/frontend',
			instances: 1,
			autorestart: true,
			max_memory_restart: '1G',
			env: { NODE_ENV: 'production', PORT: 3000 },
		},
		// ... more apps
	],
};
```

**Usage**:

```bash
# Start all apps
pm2 start ecosystem.config.js

# Save process list
pm2 save

# View status
pm2 status
```

---

## 🌐 Nginx Multi-App Examples

### Subdomain Routing (Default)

Configure apps with subdomains:

```
Frontend: app.example.com → localhost:3000
Backend:  api.example.com → localhost:5001
MailHog:  mail.example.com → localhost:8025
```

### Path-Based Routing

Alternative configuration:

```
Frontend: example.com/ → localhost:3000
Backend:  example.com/api → localhost:5001
MailHog:  example.com/mail → localhost:8025
```

### Adding More Apps

Re-run the script and choose **"Add new app configurations"** when prompted.

---

## ✅ Post-Install Verification

### Check Service Status

```bash
# PostgreSQL
sudo systemctl status postgresql
psql -h localhost -U appuser -d myapp

# Redis
sudo systemctl status redis-server
redis-cli ping

# Nginx
sudo systemctl status nginx
curl -I http://localhost

# MailHog
sudo systemctl status mailhog
curl http://localhost:8025

# CodeDeploy Agent
sudo systemctl status codedeploy-agent

# Node.js & pnpm
node -v
pnpm -v

# PM2
pm2 -v
pm2 list
```

### Test Database Connection

```bash
# PostgreSQL
psql -h localhost -U appuser -d myapp -c "SELECT version();"

# Redis
redis-cli ping
```

### View Nginx Configurations

```bash
ls -l /etc/nginx/sites-enabled/
cat /etc/nginx/sites-enabled/app-frontend.conf
```

---

## 🔧 Troubleshooting

### Check Logs

```bash
# Setup log
cat /tmp/ec2-setup.log

# Nginx error log
sudo tail -f /var/log/nginx/error.log

# PostgreSQL log
sudo tail -f /var/log/postgresql/postgresql-*-main.log

# Service-specific logs
sudo journalctl -u nginx -f
sudo journalctl -u postgresql -f
sudo journalctl -u mailhog -f
```

### Common Issues

#### Nginx Configuration Test Failed

```bash
# Test configuration
sudo nginx -t

# Check for port conflicts
sudo netstat -tlnp | grep :80
```

#### PostgreSQL Connection Failed

```bash
# Verify service is running
sudo systemctl status postgresql

# Check connection
psql -h localhost -U appuser -d myapp
```

#### SSL Certificate Issues

```bash
# Test renewal
sudo certbot renew --dry-run

# Check certificate status
sudo certbot certificates

# Verify DNS points to server
nslookup your-domain.com
```

#### MailHog Not Accessible

```bash
# Check if service is running
sudo systemctl status mailhog

# Test SMTP
telnet localhost 1025

# Test UI
curl http://localhost:8025
```

---

## 🧹 Manual Cleanup

If you need to completely remove installed components:

### PostgreSQL

```bash
# Stop service
sudo systemctl stop postgresql

# Remove packages
sudo apt remove postgresql postgresql-contrib -y
sudo apt autoremove -y

# Delete data
sudo rm -rf /var/lib/postgresql
sudo rm -rf /etc/postgresql

# Remove user
sudo deluser postgres
```

### Redis

```bash
sudo systemctl stop redis-server
sudo apt remove redis-server -y
sudo rm -rf /var/lib/redis
sudo rm -rf /etc/redis
```

### Nginx

```bash
sudo systemctl stop nginx
sudo apt remove nginx nginx-common -y
sudo rm -rf /etc/nginx
sudo rm -rf /var/log/nginx
```

### MailHog

```bash
sudo systemctl stop mailhog
sudo systemctl disable mailhog
sudo rm /usr/local/bin/mailhog
sudo rm /etc/systemd/system/mailhog.service
sudo systemctl daemon-reload
```

### Node.js + pnpm

```bash
# If installed via NodeSource
sudo apt remove nodejs npm -y
sudo rm -rf /etc/apt/sources.list.d/nodesource.list
sudo rm -rf /usr/lib/node_modules

# Remove pnpm
sudo npm uninstall -g pnpm
```

### PM2

```bash
# Remove startup script
pm2 unstartup

# Remove globally
sudo npm uninstall -g pm2

# Remove PM2 data
rm -rf /home/ubuntu/.pm2
```

### CodeDeploy Agent

```bash
sudo systemctl stop codedeploy-agent
sudo apt remove codedeploy-agent -y
sudo rm -rf /opt/codedeploy-agent
```

### SSL Certificates

```bash
sudo certbot revoke --cert-path /etc/letsencrypt/live/your-domain/cert.pem
sudo apt remove certbot -y
sudo rm -rf /etc/letsencrypt
```

### Completion Markers & Secrets

```bash
# Remove state directory
sudo rm -rf /etc/ec2-setup

# Remove secrets file
rm /home/ubuntu/.ec2-setup-secrets.json

# Remove generated files
rm /home/ubuntu/.env.example
rm /home/ubuntu/ecosystem.config.js

# Remove logs
rm /tmp/ec2-setup.log
```

---

## 🔒 Security Notes

- **Development/Staging Use**: This script is optimized for development and staging environments
- **Firewall**: Security groups should handle firewall rules (not UFW)
- **Localhost Services**: PostgreSQL and Redis bind to localhost only
- **Secrets File**: Automatically set to chmod 600 (user-only access)
- **SSL**: Auto-renewal configured via certbot timer
- **MailHog Auth**: Optional basic authentication for web UI

### Production Hardening

For production deployments, consider:

- Enabling PostgreSQL authentication and SSL
- Configuring Redis authentication (requirepass)
- Setting up proper firewall rules
- Using environment-specific secrets management
- Implementing rate limiting in Nginx
- Regular security updates and monitoring

---

## 📂 Repository Structure

```
setup/
├── setup.sh                 # Main interactive entrypoint
├── installers/              # Component installers
│   ├── node.sh             # Node.js + pnpm
│   ├── pm2.sh              # PM2 process manager
│   ├── postgres.sh         # PostgreSQL database
│   ├── redis.sh            # Redis cache
│   ├── mailhog.sh          # MailHog email testing
│   ├── nginx.sh            # Nginx web server
│   ├── ssl.sh              # Let's Encrypt SSL
│   ├── codedeploy.sh       # AWS CodeDeploy agent
│   └── github_ssh.sh       # GitHub SSH setup
├── nginx/                   # Nginx configs (generated dynamically)
├── templates/               # File templates
│   └── generate-env.sh     # Environment file generator
└── utils/                   # Utility functions
    ├── log.sh              # Logging functions
    ├── prompt.sh           # Whiptail dialogs
    ├── secrets.sh          # Secrets management
    └── state.sh            # State tracking
```

---

## 🤝 Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

---

## 📄 License

MIT License - Feel free to use this for your projects.

---

## ⚡ Tips

1. **Run on Fresh Instance**: Best results on a clean Ubuntu 22.04 install
2. **DNS First**: Set up DNS records before running SSL installer
3. **Save Secrets**: Backup `/home/ubuntu/.ec2-setup-secrets.json` after first run
4. **Re-run Safe**: Script is idempotent — safe to re-run
5. **Force Mode**: Use `--force` to reinstall specific components
6. **Add Apps**: Re-run to add more Nginx app configurations

---

**Made with ❤️ for NestJS/Next.js developers**
