#!/bin/bash

set -e

if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

BACKUP_BASE_DIR="./backups"
RESTORE_TEMP_DIR="/tmp/librenms_restore_$$"

DB_CONTAINER="librenms_db"
DB_NAME="${DB_NAME:-librenms}"
DB_USER="${DB_USER:-librenms}"
DB_PASSWORD="${DB_PASSWORD:-librenms_password}"
DB_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-root_password}"

if [ $# -eq 0 ]; then
    print_error "Usage: $0 <backup_file.tar.gz>"
    echo ""
    print_info "Available backups:"
    ls -lh "${BACKUP_BASE_DIR}"/*.tar.gz 2>/dev/null || print_warning "No backups found in ${BACKUP_BASE_DIR}"
    exit 1
fi

BACKUP_FILE="$1"

if [ ! -f "${BACKUP_FILE}" ]; then
    print_error "Backup file not found: ${BACKUP_FILE}"
    exit 1
fi

if ! docker ps --format '{{.Names}}' | grep -q "^${DB_CONTAINER}$"; then
    print_error "Database container is not running. Please start the system first with: docker compose up -d"
    exit 1
fi

if ! docker ps --format '{{.Names}}' | grep -q "^librenms$"; then
    print_error "LibreNMS container is not running. Please start the system first with: docker compose up -d"
    exit 1
fi

print_warning "=========================================="
print_warning "WARNING: This will overwrite existing data!"
print_warning "=========================================="
echo ""
read -r -p "Are you sure you want to continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    print_info "Restore cancelled"
    exit 0
fi

print_info "Starting restore process from: ${BACKUP_FILE}"

mkdir -p "${RESTORE_TEMP_DIR}"

print_info "Extracting backup archive..."
tar -xzf "${BACKUP_FILE}" -C "${RESTORE_TEMP_DIR}"

BACKUP_DIR=$(find "${RESTORE_TEMP_DIR}" -maxdepth 1 -type d -name "librenms_backup_*" | head -1)

if [ -z "${BACKUP_DIR}" ]; then
    print_error "Invalid backup archive: backup directory not found"
    rm -rf "${RESTORE_TEMP_DIR}"
    exit 1
fi

print_info "✓ Backup extracted successfully"

if [ -f "${BACKUP_DIR}/backup_info.txt" ]; then
    echo ""
    print_info "Backup Information:"
    cat "${BACKUP_DIR}/backup_info.txt"
    echo ""
fi

if [ -f "${BACKUP_DIR}/database.sql" ]; then
    print_info "Restoring database..."
    docker exec ${DB_CONTAINER} mysql -u root -p${DB_ROOT_PASSWORD} -e "DROP DATABASE IF EXISTS ${DB_NAME};"
    docker exec ${DB_CONTAINER} mysql -u root -p${DB_ROOT_PASSWORD} -e "CREATE DATABASE ${DB_NAME};"
    
    if docker exec -i ${DB_CONTAINER} mysql -u root -p${DB_ROOT_PASSWORD} ${DB_NAME} < "${BACKUP_DIR}/database.sql"; then
        print_info "✓ Database restored successfully"
    else
        print_error "Database restore failed"
        rm -rf "${RESTORE_TEMP_DIR}"
        exit 1
    fi
else
    print_error "Database backup file not found in archive"
    rm -rf "${RESTORE_TEMP_DIR}"
    exit 1
fi

if [ -d "${BACKUP_DIR}/rrd" ]; then
    print_info "Restoring RRD files..."
    docker exec librenms rm -rf /data/rrd
    docker cp "${BACKUP_DIR}/rrd" librenms:/data/
    docker exec librenms chown -R librenms:librenms /data/rrd
    print_info "✓ RRD files restored successfully"
else
    print_warning "No RRD files found in backup"
fi

if [ -f "${BACKUP_DIR}/config.php" ]; then
    print_info "Restoring configuration..."
    docker cp "${BACKUP_DIR}/config.php" librenms:/data/
    docker exec librenms chown librenms:librenms /data/config.php
    print_info "✓ Configuration restored successfully"
else
    print_warning "No configuration file found in backup"
fi

if [ -d "${BACKUP_DIR}/logs" ]; then
    print_info "Restoring logs..."
    docker cp "${BACKUP_DIR}/logs" librenms:/data/
    docker exec librenms chown -R librenms:librenms /data/logs
    print_info "✓ Logs restored successfully"
fi

if [ -d "${BACKUP_DIR}/plugins" ]; then
    print_info "Restoring plugins..."
    docker cp "${BACKUP_DIR}/plugins" librenms:/data/
    docker exec librenms chown -R librenms:librenms /data/plugins
    print_info "✓ Plugins restored successfully"
fi

print_info "Validating restored data..."

if docker exec ${DB_CONTAINER} mysql -u ${DB_USER} -p${DB_PASSWORD} ${DB_NAME} -e "SELECT COUNT(*) FROM devices;" &> /dev/null; then
    DEVICE_COUNT=$(docker exec ${DB_CONTAINER} mysql -u ${DB_USER} -p${DB_PASSWORD} ${DB_NAME} -e "SELECT COUNT(*) FROM devices;" -s -N 2>/dev/null || echo "0")
    print_info "✓ Database validation passed (${DEVICE_COUNT} devices found)"
else
    print_error "Database validation failed"
    rm -rf "${RESTORE_TEMP_DIR}"
    exit 1
fi

if docker exec librenms test -d /data/rrd; then
    RRD_COUNT=$(docker exec librenms find /data/rrd -name "*.rrd" | wc -l)
    print_info "✓ RRD files validation passed (${RRD_COUNT} files found)"
else
    print_warning "RRD directory not found"
fi

print_info "Restarting LibreNMS services..."
docker compose restart librenms dispatcher

sleep 5
rm -rf "${RESTORE_TEMP_DIR}"

echo ""
print_info "=========================================="
print_info "Restore completed successfully!"
print_info "=========================================="
echo ""
print_info "Restored from: ${BACKUP_FILE}"
print_info "Devices restored: ${DEVICE_COUNT}"
print_info "RRD files restored: ${RRD_COUNT}"
echo ""
print_info "LibreNMS Web Interface: http://localhost:80"
print_info "Please verify the restored data through the web interface"
echo ""
