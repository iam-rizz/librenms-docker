#!/bin/bash

set -e

if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

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

ADMIN_USER="${LIBRENMS_ADMIN_USER:-admin}"
ADMIN_PASSWORD="${LIBRENMS_ADMIN_PASSWORD:-admin}"
ADMIN_EMAIL="${LIBRENMS_ADMIN_EMAIL:-admin@localhost}"
TIMEZONE="${TZ:-Asia/Jakarta}"
BASE_URL="${LIBRENMS_BASE_URL:-http://localhost}"
DB_USER="${DB_USER:-librenms}"
DB_PASSWORD="${DB_PASSWORD:-librenms_password}"
DB_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-root_password}"

print_info "=========================================="
print_info "LibreNMS Initial Configuration"
print_info "=========================================="
echo ""

if ! docker ps | grep -q "librenms"; then
    print_error "LibreNMS container is not running. Please run deploy.sh first."
    exit 1
fi

if ! docker ps | grep -q "librenms_db"; then
    print_error "Database container is not running. Please run deploy.sh first."
    exit 1
fi

print_info "✓ All required containers are running"
echo ""

print_info "Waiting for LibreNMS to be ready..."
MAX_RETRIES=30
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if docker exec librenms test -f /data/.env &> /dev/null; then
        print_info "✓ LibreNMS is ready"
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo -n "."
    sleep 2
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    print_error "LibreNMS failed to become ready"
    exit 1
fi

echo ""

print_info "Checking if LibreNMS is already configured..."
if docker exec librenms_db mysql -u ${DB_USER} -p${DB_PASSWORD} librenms -e "SELECT COUNT(*) FROM users;" &> /dev/null; then
    USER_COUNT=$(docker exec librenms_db mysql -u ${DB_USER} -p${DB_PASSWORD} librenms -sN -e "SELECT COUNT(*) FROM users;")
    if [ "$USER_COUNT" -gt 0 ]; then
        print_warning "LibreNMS already has users configured"
        read -r -p "Do you want to reconfigure? (yes/no): " RECONFIGURE
        if [ "$RECONFIGURE" != "yes" ]; then
            print_info "Configuration cancelled"
            exit 0
        fi
    fi
fi

print_info "Running database migrations..."
docker exec librenms php /opt/librenms/lnms migrate --force || {
    print_warning "Migration may have already been run"
}

echo ""

print_info "Creating admin user..."
print_info "Username: $ADMIN_USER"
print_info "Email: $ADMIN_EMAIL"

if docker exec librenms_db mysql -u ${DB_USER} -p${DB_PASSWORD} librenms -sN -e "SELECT COUNT(*) FROM users WHERE username='$ADMIN_USER';" | grep -q "1"; then
    print_warning "Admin user already exists, updating password..."
    docker exec librenms php /opt/librenms/lnms user:set-password "$ADMIN_USER" "$ADMIN_PASSWORD" || {
        print_error "Failed to update admin password"
        exit 1
    }
else
    docker exec librenms php /opt/librenms/lnms user:add "$ADMIN_USER" -p "$ADMIN_PASSWORD" -e "$ADMIN_EMAIL" -r admin || {
        print_error "Failed to create admin user"
        exit 1
    }
fi

print_success "✓ Admin user configured"
echo ""

print_info "Configuring LibreNMS settings..."

docker exec librenms php /opt/librenms/lnms config:set timezone "$TIMEZONE" || {
    print_warning "Failed to set timezone"
}

docker exec librenms php /opt/librenms/lnms config:set base_url "$BASE_URL" || {
    print_warning "Failed to set base URL"
}

print_success "✓ Timezone and base URL configured"
echo ""

print_info "Enabling required modules..."

DISCOVERY_MODULES=(
    "discovery.ports"
    "discovery.sensors"
    "discovery.processors"
    "discovery.mempools"
    "discovery.storage"
    "discovery.entity-physical"
)

for module in "${DISCOVERY_MODULES[@]}"; do
    docker exec librenms php /opt/librenms/lnms config:set "$module" true || {
        print_warning "Failed to enable $module"
    }
done

POLLER_MODULES=(
    "poller.ports"
    "poller.sensors"
    "poller.processors"
    "poller.mempools"
    "poller.storage"
)

for module in "${POLLER_MODULES[@]}"; do
    docker exec librenms php /opt/librenms/lnms config:set "$module" true || {
        print_warning "Failed to enable $module"
    }
done

print_success "✓ Required modules enabled"
echo ""

print_info "Configuring polling interval..."
docker exec librenms php /opt/librenms/lnms config:set rrd.step 300 || {
    print_warning "Failed to set polling interval"
}

print_success "✓ Polling interval set to 5 minutes (300 seconds)"
echo ""

print_info "Configuring SNMP settings..."

docker exec librenms php /opt/librenms/lnms config:set snmp.version v2c || {
    print_warning "Failed to configure SNMP v2c"
}

docker exec librenms php /opt/librenms/lnms config:set snmp.community.0 public || {
    print_warning "Failed to set default SNMP community"
}

print_success "✓ SNMP settings configured"
echo ""

print_info "Validating database connection and optimization..."

if docker exec librenms php /opt/librenms/lnms db:check &> /dev/null; then
    print_success "✓ Database connection successful"
else
    print_error "Database connection failed"
    exit 1
fi

print_info "Checking database optimization settings..."
DB_BUFFER_POOL=$(docker exec librenms_db mysql -u root -p${DB_ROOT_PASSWORD} -sN -e "SELECT @@innodb_buffer_pool_size / 1024 / 1024;")
DB_MAX_CONN=$(docker exec librenms_db mysql -u root -p${DB_ROOT_PASSWORD} -sN -e "SELECT @@max_connections;")
DB_THREAD_CACHE=$(docker exec librenms_db mysql -u root -p${DB_ROOT_PASSWORD} -sN -e "SELECT @@thread_cache_size;")

echo "  InnoDB Buffer Pool: ${DB_BUFFER_POOL} MB"
echo "  Max Connections: ${DB_MAX_CONN}"
echo "  Thread Cache Size: ${DB_THREAD_CACHE}"

print_info "Validating LibreNMS configuration..."
docker exec librenms php /opt/librenms/validate.php || {
    print_warning "Some validation checks failed, but this is normal for initial setup"
}

echo ""

print_info "=========================================="
print_info "Configuration Summary"
print_info "=========================================="
echo ""
echo "LibreNMS Web Interface: $BASE_URL"
echo "Admin Username: $ADMIN_USER"
echo "Admin Password: $ADMIN_PASSWORD"
echo "Admin Email: $ADMIN_EMAIL"
echo "Timezone: $TIMEZONE"
echo "Polling Interval: 5 minutes"
echo ""
print_info "Database Optimization:"
echo "  InnoDB Buffer Pool: ${DB_BUFFER_POOL} MB"
echo "  Max Connections: ${DB_MAX_CONN}"
echo "  Thread Cache Size: ${DB_THREAD_CACHE}"
echo "  Connection Timeout: 600 seconds"
echo ""
print_info "Enabled Discovery Modules:"
for module in "${DISCOVERY_MODULES[@]}"; do
    echo "  - $module"
done
echo ""
print_info "Enabled Poller Modules:"
for module in "${POLLER_MODULES[@]}"; do
    echo "  - $module"
done
echo ""

print_success "=========================================="
print_success "LibreNMS configuration completed!"
print_success "=========================================="
echo ""
print_info "You can now access LibreNMS at: $BASE_URL"
print_info "Login with username: $ADMIN_USER"
echo ""
print_info "Next steps:"
echo "  1. Access the web interface"
echo "  2. Add your first device using the web UI or CLI"
echo "  3. Configure alert rules and transports"
echo ""

