#!/bin/bash

set -e 

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_success() {
    echo -e "${BLUE}[SUCCESS]${NC} $1"
}

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

print_info "=========================================="
print_info "LibreNMS OLT Monitoring System - Setup"
print_info "=========================================="
echo ""

print_info "Detecting shell configuration..."

SHELL_NAME=$(basename "$SHELL")
SHELL_RC=""

case "$SHELL_NAME" in
    bash)
        if [ -f "$HOME/.bashrc" ]; then
            SHELL_RC="$HOME/.bashrc"
        elif [ -f "$HOME/.bash_profile" ]; then
            SHELL_RC="$HOME/.bash_profile"
        else
            SHELL_RC="$HOME/.bashrc"
            touch "$SHELL_RC"
        fi
        print_info "Detected: Bash (config: $SHELL_RC)"
        ;;
    zsh)
        if [ -f "$HOME/.zshrc" ]; then
            SHELL_RC="$HOME/.zshrc"
        else
            SHELL_RC="$HOME/.zshrc"
            touch "$SHELL_RC"
        fi
        print_info "Detected: Zsh (config: $SHELL_RC)"
        ;;
    fish)
        SHELL_RC="$HOME/.config/fish/config.fish"
        if [ ! -f "$SHELL_RC" ]; then
            mkdir -p "$HOME/.config/fish"
            touch "$SHELL_RC"
        fi
        print_info "Detected: Fish (config: $SHELL_RC)"
        ;;
    *)
        print_warning "Unknown shell: $SHELL_NAME"
        print_warning "Defaulting to .bashrc"
        SHELL_RC="$HOME/.bashrc"
        ;;
esac

echo ""

if grep -q "# LibreNMS OLT Monitoring Aliases" "$SHELL_RC" 2>/dev/null; then
    print_warning "Aliases already exist in $SHELL_RC"
    read -p "Do you want to update them? (yes/no): " UPDATE_ALIASES
    
    if [ "$UPDATE_ALIASES" != "yes" ]; then
        print_info "Setup cancelled"
        exit 0
    fi
    
    print_info "Removing old aliases..."
    if [ "$SHELL_NAME" = "fish" ]; then
        sed -i '/# LibreNMS OLT Monitoring Aliases/,/# End LibreNMS Aliases/d' "$SHELL_RC"
    else
        sed -i '/# LibreNMS OLT Monitoring Aliases/,/# End LibreNMS Aliases/d' "$SHELL_RC"
    fi
fi

print_info "Adding aliases to $SHELL_RC..."

if [ "$SHELL_NAME" = "fish" ]; then
    cat >> "$SHELL_RC" << EOF

# LibreNMS OLT Monitoring Aliases
# Project: $PROJECT_DIR

# Resource monitoring
alias librenms-stats='sudo docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"'
alias librenms-stats-live='sudo docker stats --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"'
alias librenms-resources='cd $PROJECT_DIR && sudo docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" && echo "" && echo "Total Memory:" && sudo docker stats --no-stream --format "{{.MemUsage}}" | awk -F"/" "{print \$1}" | awk "{sum+=\$1} END {print sum \" MiB / 2048 MiB\"}"'

# Container management
alias librenms-up='cd $PROJECT_DIR && sudo docker compose up -d'
alias librenms-down='cd $PROJECT_DIR && sudo docker compose down'
alias librenms-restart='cd $PROJECT_DIR && sudo docker compose restart'
alias librenms-logs='cd $PROJECT_DIR && sudo docker compose logs -f'
alias librenms-ps='cd $PROJECT_DIR && sudo docker compose ps'

# Backup and restore
alias librenms-backup='cd $PROJECT_DIR && sudo bash scripts/backup.sh'
alias librenms-restore='cd $PROJECT_DIR && sudo bash scripts/restore.sh'
alias librenms-backups='ls -lh $PROJECT_DIR/backups/*.tar.gz 2>/dev/null || echo "No backups found"'

# Quick access
alias librenms-cd='cd $PROJECT_DIR'
alias librenms-help='cat $PROJECT_DIR/README.md | less'

# End LibreNMS Aliases
EOF
else
    cat >> "$SHELL_RC" << EOF

# LibreNMS OLT Monitoring Aliases
# Project: $PROJECT_DIR

# Resource monitoring
alias librenms-stats='sudo docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"'
alias librenms-stats-live='sudo docker stats --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"'
alias librenms-resources='cd $PROJECT_DIR && sudo docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" && echo "" && echo "Total Memory:" && sudo docker stats --no-stream --format "{{.MemUsage}}" | awk -F"/" '"'"'{print \$1}'"'"' | awk '"'"'{sum+=\$1} END {print sum " MiB / 2048 MiB"}'"'"''

# Container management
alias librenms-up='cd $PROJECT_DIR && sudo docker compose up -d'
alias librenms-down='cd $PROJECT_DIR && sudo docker compose down'
alias librenms-restart='cd $PROJECT_DIR && sudo docker compose restart'
alias librenms-logs='cd $PROJECT_DIR && sudo docker compose logs -f'
alias librenms-ps='cd $PROJECT_DIR && sudo docker compose ps'

# Backup and restore
alias librenms-backup='cd $PROJECT_DIR && sudo bash scripts/backup.sh'
alias librenms-restore='cd $PROJECT_DIR && sudo bash scripts/restore.sh'
alias librenms-backups='ls -lh $PROJECT_DIR/backups/*.tar.gz 2>/dev/null || echo "No backups found"'

# Quick access
alias librenms-cd='cd $PROJECT_DIR'
alias librenms-help='cat $PROJECT_DIR/README.md | less'

# End LibreNMS Aliases
EOF
fi

print_success "✓ Aliases added successfully!"
echo ""

print_info "=========================================="
print_info "Available Aliases"
print_info "=========================================="
echo ""
echo "Resource Monitoring:"
echo "  librenms-stats         - Show current resource usage (snapshot)"
echo "  librenms-stats-live    - Show live resource usage (updating)"
echo "  librenms-resources     - Show detailed resource usage with totals"
echo ""
echo "Container Management:"
echo "  librenms-up            - Start all containers"
echo "  librenms-down          - Stop all containers"
echo "  librenms-restart       - Restart all containers"
echo "  librenms-logs          - View container logs (live)"
echo "  librenms-ps            - Show container status"
echo ""
echo "Backup & Restore:"
echo "  librenms-backup        - Create backup"
echo "  librenms-restore       - Restore from backup"
echo "  librenms-backups       - List available backups"
echo ""
echo "Quick Access:"
echo "  librenms-cd            - Go to project directory"
echo "  librenms-help          - Show README documentation"
echo ""

print_info "=========================================="
print_info "Next Steps"
print_info "=========================================="
echo ""
echo "1. Reload your shell configuration:"
echo "   source $SHELL_RC"
echo ""
echo "2. Or restart your terminal"
echo ""
echo "3. Try the new aliases:"
echo "   librenms-stats"
echo "   librenms-resources"
echo ""

print_success "Setup completed successfully!"
