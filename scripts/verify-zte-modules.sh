#!/bin/bash
#
# Verify and Fix ZTE C300 Custom Modules Installation
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Verifying ZTE C300 Modules Installation ===${NC}\n"

# Check if container is running
if ! docker ps | grep -q "librenms"; then
    echo -e "${RED}Error: LibreNMS container is not running${NC}"
    exit 1
fi

echo -e "${YELLOW}Step 1: Checking module locations in container...${NC}"

# Check both possible locations
echo "Checking /opt/librenms (correct location):"
docker exec librenms ls -la /opt/librenms/includes/polling/zte-*.inc.php 2>/dev/null || echo "  Not found in /opt/librenms"

echo -e "\nChecking /data (wrong location):"
docker exec librenms ls -la /data/includes/polling/zte-*.inc.php 2>/dev/null || echo "  Not found in /data"

echo -e "\n${YELLOW}Step 2: Installing modules to correct location (/opt/librenms)...${NC}"

# Create directories
docker exec -u root librenms mkdir -p /opt/librenms/includes/polling
docker exec -u root librenms mkdir -p /opt/librenms/includes/discovery/sensors/optical-power
docker exec -u root librenms mkdir -p /opt/librenms/config.d

# Copy modules
echo "Copying polling modules..."
docker cp librenms/includes/polling/zte-optical-power.inc.php librenms:/opt/librenms/includes/polling/
docker cp librenms/includes/polling/zte-ont-status.inc.php librenms:/opt/librenms/includes/polling/

echo "Copying discovery modules..."
docker cp librenms/includes/discovery/zte-ont-discovery.inc.php librenms:/opt/librenms/includes/discovery/
docker cp librenms/includes/discovery/sensors/optical-power/zte-c300.inc.php librenms:/opt/librenms/includes/discovery/sensors/optical-power/

echo "Copying configuration..."
docker cp librenms/config/zte-c300-config.php librenms:/opt/librenms/config.d/

# Set permissions
echo "Setting permissions..."
docker exec -u root librenms chown -R librenms:librenms /opt/librenms/includes/polling/zte-*.inc.php 2>/dev/null || true
docker exec -u root librenms chown -R librenms:librenms /opt/librenms/includes/discovery/zte-*.inc.php 2>/dev/null || true
docker exec -u root librenms chown -R librenms:librenms /opt/librenms/includes/discovery/sensors/optical-power/zte-*.inc.php 2>/dev/null || true
docker exec -u root librenms chown -R librenms:librenms /opt/librenms/config.d/zte-*.php 2>/dev/null || true

echo -e "\n${YELLOW}Step 3: Verifying installation...${NC}"

FILES_OK=true

if docker exec librenms test -f /opt/librenms/includes/polling/zte-optical-power.inc.php; then
    echo -e "  ${GREEN}✓${NC} zte-optical-power.inc.php"
else
    echo -e "  ${RED}✗${NC} zte-optical-power.inc.php"
    FILES_OK=false
fi

if docker exec librenms test -f /opt/librenms/includes/polling/zte-ont-status.inc.php; then
    echo -e "  ${GREEN}✓${NC} zte-ont-status.inc.php"
else
    echo -e "  ${RED}✗${NC} zte-ont-status.inc.php"
    FILES_OK=false
fi

if docker exec librenms test -f /opt/librenms/includes/discovery/zte-ont-discovery.inc.php; then
    echo -e "  ${GREEN}✓${NC} zte-ont-discovery.inc.php"
else
    echo -e "  ${RED}✗${NC} zte-ont-discovery.inc.php"
    FILES_OK=false
fi

if docker exec librenms test -f /opt/librenms/includes/discovery/sensors/optical-power/zte-c300.inc.php; then
    echo -e "  ${GREEN}✓${NC} zte-c300.inc.php"
else
    echo -e "  ${RED}✗${NC} zte-c300.inc.php"
    FILES_OK=false
fi

if docker exec librenms test -f /opt/librenms/config.d/zte-c300-config.php; then
    echo -e "  ${GREEN}✓${NC} zte-c300-config.php"
else
    echo -e "  ${RED}✗${NC} zte-c300-config.php"
    FILES_OK=false
fi

if [ "$FILES_OK" = true ]; then
    echo -e "\n${GREEN}✓ All modules installed correctly${NC}\n"
else
    echo -e "\n${RED}✗ Some modules are missing${NC}\n"
    exit 1
fi

echo -e "${YELLOW}Step 4: Testing module syntax...${NC}"
docker exec librenms php -l /opt/librenms/includes/polling/zte-optical-power.inc.php
docker exec librenms php -l /opt/librenms/includes/polling/zte-ont-status.inc.php

echo -e "\n${GREEN}=== Verification Complete ===${NC}\n"

echo -e "${YELLOW}Next: Run discovery on your ZTE device:${NC}"
echo "  docker exec -u librenms librenms /opt/librenms/lnms device:poll 1 -m discovery -v"
echo ""
echo -e "${YELLOW}Then check for ONT data:${NC}"
echo "  docker compose exec db mysql -u librenms -p'librenms_password' librenms -e \"SELECT COUNT(*) FROM onts WHERE device_id=1;\""
