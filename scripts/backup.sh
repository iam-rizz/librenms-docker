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
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="${BACKUP_BASE_DIR}/librenms_backup_${TIMESTAMP}"
BACKUP_ARCHIVE="${BACKUP_BASE_DIR}/librenms_backup_${TIMESTAMP}.tar.gz"

DB_CONTAINER="librenms_db"
DB_NAME="${DB_NAME:-librenms}"
DB_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-root_password}"

if ! docker ps --format '{{.Names}}' | grep -q "^${DB_CONTAINER}$"; then
    print_error "Database container is not running. Please start the system first."
    exit 1
fi

if ! docker ps --format '{{.Names}}' | grep -q "^librenms$"; then
    print_error "LibreNMS container is not running. Please start the system first."
    exit 1
fi

print_info "Starting backup process..."

mkdir -p "${BACKUP_DIR}"

print_info "Backing up MariaDB database..."
if docker exec ${DB_CONTAINER} mysqldump \
    -u root \
    -p${DB_ROOT_PASSWORD} \
    --single-transaction \
    --quick \
    --lock-tables=false \
    ${DB_NAME} > "${BACKUP_DIR}/database.sql"; then
    DB_SIZE=$(du -h "${BACKUP_DIR}/database.sql" | cut -f1)
    print_info "✓ Database backup completed (${DB_SIZE})"
else
    print_error "Database backup failed"
    rm -rf "${BACKUP_DIR}"
    exit 1
fi

print_info "Backing up RRD files..."
if docker exec librenms test -d /data/rrd; then
    docker cp librenms:/data/rrd "${BACKUP_DIR}/" 2>/dev/null || true
    if [ -d "${BACKUP_DIR}/rrd" ]; then
        RRD_SIZE=$(du -sh "${BACKUP_DIR}/rrd" | cut -f1)
        print_info "✓ RRD files backup completed (${RRD_SIZE})"
    else
        print_warning "No RRD files found to backup"
    fi
else
    print_warning "RRD directory does not exist yet"
fi

print_info "Backing up configuration files..."
if docker exec librenms test -f /data/config.php; then
    docker cp librenms:/data/config.php "${BACKUP_DIR}/" 2>/dev/null || true
    if [ -f "${BACKUP_DIR}/config.php" ]; then
        print_info "✓ Configuration backup completed"
    else
        print_warning "Configuration file not found"
    fi
else
    print_warning "Configuration file does not exist yet"
fi

print_info "Backing up additional data..."
docker exec librenms test -d /data/logs && docker cp librenms:/data/logs "${BACKUP_DIR}/" 2>/dev/null || true
docker exec librenms test -d /data/plugins && docker cp librenms:/data/plugins "${BACKUP_DIR}/" 2>/dev/null || true

print_info "Creating backup metadata..."
cat > "${BACKUP_DIR}/backup_info.txt" << EOF
Backup Information
==================
Timestamp: ${TIMESTAMP}
Date: $(date)
Hostname: $(hostname)
LibreNMS Version: $(docker exec librenms cat /opt/librenms/VERSION 2>/dev/null || echo "Unknown")
Database: ${DB_NAME}
Backup Directory: ${BACKUP_DIR}
EOF

print_info "Compressing backup..."
if tar -czf "${BACKUP_ARCHIVE}" -C "${BACKUP_BASE_DIR}" "librenms_backup_${TIMESTAMP}"; then
    ARCHIVE_SIZE=$(du -h "${BACKUP_ARCHIVE}" | cut -f1)
    print_info "✓ Backup compressed successfully (${ARCHIVE_SIZE})"
    
    rm -rf "${BACKUP_DIR}"
    
    echo ""
    print_info "=========================================="
    print_info "Backup completed successfully!"
    print_info "=========================================="
    echo ""
    print_info "Backup file: ${BACKUP_ARCHIVE}"
    print_info "Backup size: ${ARCHIVE_SIZE}"
    print_info "Timestamp: ${TIMESTAMP}"
    echo ""
    
    print_info "Recent backups:"
    find "${BACKUP_BASE_DIR}" -name "*.tar.gz" -type f -printf "%T@ %p\n" 2>/dev/null | sort -rn | head -5 | cut -d' ' -f2- | xargs ls -lh 2>/dev/null || print_warning "No previous backups found"
    echo ""
else
    print_error "Backup compression failed"
    exit 1
fi
