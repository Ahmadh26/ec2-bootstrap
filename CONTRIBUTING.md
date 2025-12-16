# Contributing to EC2 Bootstrap

Thank you for your interest in contributing! This guide will help you get started.

## 🚀 Getting Started

1. **Fork the repository**
2. **Clone your fork**
   ```bash
   git clone https://github.com/YOUR_USERNAME/ec2-bootstrap.git
   cd ec2-bootstrap
   ```
3. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

## 📁 Project Structure

```
setup/
├── setup.sh                 # Main orchestration script
├── installers/             # Component-specific installers
│   └── *.sh               # Each component is self-contained
├── templates/              # File generation templates
│   └── generate-env.sh    # Environment file generator
└── utils/                  # Shared utility functions
    ├── log.sh             # Logging functions
    ├── prompt.sh          # Whiptail UI functions
    ├── secrets.sh         # Credential management
    └── state.sh           # Installation state tracking
```

## 🛠️ Development Guidelines

### Shell Script Standards

1. **Use bash**: All scripts should start with `#!/bin/bash`
2. **Set strict mode**: Use `set -e` to exit on errors
3. **Source utilities**: Import shared functions from `utils/`
4. **Make executable**: All `.sh` files should have `chmod +x`

### Code Style

```bash
# Good
if [ "$VAR" = "value" ]; then
    log_info "Processing..."
fi

# Variable names: UPPERCASE for exports, lowercase for local
EXPORT_VAR="value"
local_var="value"

# Function names: lowercase with underscores
my_function() {
    local param="$1"
    # function body
}
```

### Logging

Use the logging functions from `utils/log.sh`:

```bash
log_header "Section Title"      # Blue header with borders
log_info "Information message"  # Blue info icon
log_success "Success message"   # Green checkmark
log_warn "Warning message"      # Yellow warning icon
log_error "Error message"       # Red X icon
log_progress "In progress..."   # Cyan arrow
```

### Error Handling

```bash
# Check command success
if ! command -v tool &> /dev/null; then
    log_error "Tool not found"
    exit 1
fi

# Capture output and errors
if output=$(command 2>&1); then
    log_success "Command succeeded"
else
    log_error "Command failed: $output"
    exit 1
fi
```

### Idempotency

All installers must be idempotent (safe to run multiple times):

```bash
# Check if already installed
if command -v tool &> /dev/null && ! is_force_mode; then
    log_info "Tool is already installed"
    exit 0
fi

# Check completion marker
if is_completed "component_name"; then
    log_info "Component already installed"
    exit 0
fi

# ... installation logic ...

# Mark as completed
mark_completed "component_name"
```

## 📝 Adding a New Component

### 1. Create Installer Script

Create `setup/installers/yourcomponent.sh`:

```bash
#!/bin/bash

set -e

source "$(dirname "$0")/../utils/log.sh"
source "$(dirname "$0")/../utils/secrets.sh"

log_header "Installing Your Component"

# Check if already installed
if command -v yourcomponent &> /dev/null && ! is_force_mode; then
    log_info "Your Component is already installed"
    exit 0
fi

# Installation logic
log_progress "Installing dependencies..."
sudo apt-get update -qq
sudo apt-get install -y yourcomponent

# Configuration
log_progress "Configuring..."
# ... configuration steps ...

# Start and enable service
log_progress "Starting service..."
sudo systemctl start yourcomponent
sudo systemctl enable yourcomponent

# Verify
if systemctl is-active --quiet yourcomponent; then
    log_success "Your Component is running"
else
    log_error "Service failed to start"
    exit 1
fi

log_success "Your Component installation complete"
```

### 2. Update Main Setup Script

In `setup/setup.sh`, add your component to the checklist:

```bash
# In select_components() function
local yourcomponent_status=$(get_status_label "yourcomponent")

local selection=$(prompt_checklist "Select Components" \
    "..." \
    "yourcomponent" "Your Component Description $yourcomponent_status" "OFF" \
    ...)
```

Add dependency handling in `reorder_components()` if needed:

```bash
# If your component depends on another
if [[ " ${SELECTED_COMPONENTS[@]} " =~ " yourcomponent " ]]; then
    if [[ ! " ${ordered[@]} " =~ " dependency " ]]; then
        log_warn "Your Component requires Dependency. Adding to list."
        ordered+=("dependency")
    fi
    ordered+=("yourcomponent")
fi
```

Add validation in `validate_services()`:

```bash
yourcomponent)
    if systemctl is-active --quiet yourcomponent; then
        log_success "Your Component: Running"
    else
        log_error "Your Component: Not running"
        all_ok=false
    fi
    ;;
```

### 3. Update Documentation

Update `README.md`:

- Add to component table
- Add to architecture diagram if applicable
- Add verification commands
- Add cleanup instructions

### 4. Test Your Component

```bash
# Test fresh install
./setup/setup.sh

# Test idempotency (run twice)
./setup/setup.sh
./setup/setup.sh

# Test force mode
./setup/setup.sh --force

# Verify state management
ls /etc/ec2-setup/completed/
```

## 🧪 Testing

### Local Testing

Use a local Ubuntu 22.04 VM or container:

```bash
# Docker
docker run -it ubuntu:22.04 bash

# Vagrant
vagrant init ubuntu/jammy64
vagrant up
vagrant ssh
```

### Integration Testing

1. Create fresh EC2 instance
2. Run full installation
3. Verify all services
4. Test re-run scenarios
5. Test force mode

### Checklist

- [ ] Script is executable (`chmod +x`)
- [ ] Has proper shebang (`#!/bin/bash`)
- [ ] Uses `set -e`
- [ ] Idempotent (safe to run multiple times)
- [ ] Checks force mode
- [ ] Creates completion marker
- [ ] Logs all steps
- [ ] Handles errors gracefully
- [ ] Verifies service is running
- [ ] Updates README.md
- [ ] No hardcoded secrets

## 📋 Pull Request Process

1. **Update documentation**: Ensure README, QUICK_REFERENCE, and relevant docs are updated
2. **Test thoroughly**: Run through TESTING.md checklist
3. **Write clear commit messages**:

   ```
   feat: Add MongoDB installer

   - Create installers/mongodb.sh
   - Add to component selection menu
   - Update README with MongoDB instructions
   - Add cleanup documentation
   ```

4. **Submit PR** with description of changes
5. **Respond to feedback**: Address review comments

## 🎯 Contribution Ideas

### New Components

- MongoDB
- MySQL/MariaDB
- Docker
- Docker Compose
- Traefik
- Prometheus
- Grafana
- Elasticsearch
- RabbitMQ

### Enhancements

- Add backup/restore functionality
- Implement rollback on failure
- Add monitoring setup
- Create systemd service for auto-updates
- Add support for Ubuntu 24.04
- Add support for Amazon Linux 2023
- Implement configuration templates
- Add environment-specific configs (dev/staging/prod)

### Documentation

- Video tutorials
- Troubleshooting guides
- Architecture diagrams
- Use case examples
- Migration guides

## 🐛 Bug Reports

When reporting bugs, please include:

1. **Description**: Clear description of the issue
2. **Environment**:
   ```
   OS: Ubuntu 22.04
   Instance: t2.micro
   Region: us-east-1
   Components: node, nginx, postgres
   ```
3. **Steps to reproduce**
4. **Expected behavior**
5. **Actual behavior**
6. **Logs**: Include relevant portions of `/tmp/ec2-setup.log`
7. **Screenshots** (if applicable)

## 💡 Feature Requests

Feature requests are welcome! Please include:

1. **Use case**: Why is this feature needed?
2. **Proposed solution**: How should it work?
3. **Alternatives**: Other approaches considered?
4. **Impact**: Who benefits from this feature?

## ✅ Code Review Criteria

Pull requests will be reviewed for:

- **Functionality**: Does it work as intended?
- **Code quality**: Is it readable and maintainable?
- **Error handling**: Are errors handled gracefully?
- **Documentation**: Is it properly documented?
- **Testing**: Has it been tested thoroughly?
- **Idempotency**: Can it be run multiple times safely?
- **Security**: Are there any security concerns?

## 📜 Code of Conduct

- Be respectful and inclusive
- Welcome newcomers
- Focus on constructive feedback
- Help others learn and grow

## 🙏 Recognition

Contributors will be recognized in:

- README.md contributors section
- Release notes
- GitHub contributors page

## 📞 Questions?

- Open an issue for general questions
- Start a discussion for ideas and proposals
- Tag maintainers for urgent matters

---

**Thank you for contributing to EC2 Bootstrap!** 🎉
