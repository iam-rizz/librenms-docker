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

if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please install Docker first."
    exit 1
fi

if ! command -v docker compose &> /dev/null; then
    print_error "Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

print_info "Starting LibreNMS OLT Monitoring System deployment..."

print_info "Creating data directories..."
mkdir -p librenms db backups logs

print_info "Pulling Docker images..."
docker compose pull

print_info "Starting containers..."
docker compose up -d

print_info "Waiting for containers to start..."
sleep 10

print_info "Validating container status..."
REQUIRED_CONTAINERS=("librenms" "librenms_db" "librenms_redis" "librenms_dispatcher")
ALL_RUNNING=true

for container in "${REQUIRED_CONTAINERS[@]}"; do
    if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        print_info "✓ Container ${container} is running"
    else
        print_error "✗ Container ${container} is not running"
        ALL_RUNNING=false
    fi
done

if [ "$ALL_RUNNING" = false ]; then
    print_error "Some containers failed to start. Check logs with: docker compose logs"
    exit 1
fi

print_info "Waiting for database to be ready..."
MAX_RETRIES=30
RETRY_COUNT=0
DB_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-root_password}"

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if docker exec librenms_db mysqladmin ping -h localhost -u root -p${DB_ROOT_PASSWORD} &> /dev/null; then
        print_info "✓ Database is ready"
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo -n "."
    sleep 2
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    print_error "Database failed to become ready"
    exit 1
fi

print_info "Setting up LibreNMS initial configuration..."

sleep 15

print_info "Checking LibreNMS accessibility..."
if curl -f http://localhost:80 &> /dev/null; then
    print_info "✓ LibreNMS web interface is accessible"
else
    print_warning "LibreNMS web interface may not be ready yet. You can check manually at http://localhost:80"
fi

echo ""
print_info "=========================================="
print_info "Deployment completed successfully!"
print_info "=========================================="
echo ""
print_info "LibreNMS Web Interface: http://localhost:80"
print_info "Default credentials will be set during first access"
echo ""
print_info "Container Status:"
docker compose ps
echo ""
print_info "To view logs: docker compose logs -f"
print_info "To stop: docker compose down"
print_info "To restart: docker compose restart"
echo ""
