#!/bin/bash
#
# Install ZTE C300 Custom Polling Modules for LibreNMS
#
# This script installs custom polling and discovery modules for ZTE C300 OLT
# devices in the LibreNMS Docker container.
#


set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' 

CONTAINER_NAME="librenms"
LIBRENMS_PATH="/data"

echo -e "${GREEN}=== Installing ZTE C300 Custom Modules ===${NC}\n"

if ! docker ps | grep -q "$CONTAINER_NAME"; then
    echo -e "${RED}Error: LibreNMS container is not running${NC}"
    echo "Please start the container first: docker-compose up -d"
    exit 1
fi

echo -e "${YELLOW}Step 1: Creating module directories...${NC}"
docker exec "$CONTAINER_NAME" mkdir -p \
    "$LIBRENMS_PATH/includes/polling" \
    "$LIBRENMS_PATH/includes/discovery/sensors/optical-power" \
    "$LIBRENMS_PATH/includes/discovery" \
    "$LIBRENMS_PATH/config.d" \
    "$LIBRENMS_PATH/database/migrations"

echo -e "${GREEN}✓ Directories created${NC}\n"

echo -e "${YELLOW}Step 2: Copying polling modules...${NC}"

docker cp librenms/includes/polling/zte-optical-power.inc.php \
    "$CONTAINER_NAME:$LIBRENMS_PATH/includes/polling/"
echo "  - Optical power polling module"

docker cp librenms/includes/polling/zte-ont-status.inc.php \
    "$CONTAINER_NAME:$LIBRENMS_PATH/includes/polling/"
echo "  - ONT status polling module"

echo -e "${GREEN}✓ Polling modules copied${NC}\n"
echo -e "${YELLOW}Step 3: Copying discovery modules...${NC}"

docker cp librenms/includes/discovery/sensors/optical-power/zte-c300.inc.php \
    "$CONTAINER_NAME:$LIBRENMS_PATH/includes/discovery/sensors/optical-power/"
echo "  - Optical power discovery module"

docker cp librenms/includes/discovery/zte-ont-discovery.inc.php \
    "$CONTAINER_NAME:$LIBRENMS_PATH/includes/discovery/"
echo "  - ONT discovery module"

echo -e "${GREEN}✓ Discovery modules copied${NC}\n"

echo -e "${YELLOW}Step 4: Copying configuration...${NC}"
docker cp librenms/config/zte-c300-config.php \
    "$CONTAINER_NAME:$LIBRENMS_PATH/config.d/"
echo -e "${GREEN}✓ Configuration copied${NC}\n"

echo -e "${YELLOW}Step 5: Creating ONT database table...${NC}"

docker exec "$CONTAINER_NAME" mysql -h db -u librenms -p"${DB_PASSWORD:-librenms}" librenms <<'EOF'
CREATE TABLE IF NOT EXISTS `onts` (
    `ont_id` INT(11) NOT NULL AUTO_INCREMENT,
    `device_id` INT(11) NOT NULL,
    `pon_port` VARCHAR(32) NOT NULL,
    `ont_index` INT(11) NOT NULL,
    `serial_number` VARCHAR(64) DEFAULT NULL,
    `model` VARCHAR(64) DEFAULT NULL,
    `firmware_version` VARCHAR(64) DEFAULT NULL,
    `status` ENUM('online', 'offline', 'dying-gasp', 'unknown') DEFAULT 'unknown',
    `rx_power` DECIMAL(5,2) DEFAULT NULL,
    `last_seen` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`ont_id`),
    UNIQUE KEY `device_pon_ont` (`device_id`, `pon_port`, `ont_index`),
    KEY `device_id` (`device_id`),
    KEY `status` (`status`),
    KEY `idx_device_status` (`device_id`, `status`),
    KEY `idx_pon_port` (`pon_port`),
    CONSTRAINT `onts_device_id_fk` FOREIGN KEY (`device_id`) 
        REFERENCES `devices` (`device_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
EOF

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ ONT table created${NC}\n"
else
    echo -e "${YELLOW}⚠ Table may already exist or there was an error${NC}\n"
fi

echo -e "${YELLOW}Step 6: Setting file permissions...${NC}"
docker exec "$CONTAINER_NAME" chown -R librenms:librenms \
    "$LIBRENMS_PATH/includes/polling" \
    "$LIBRENMS_PATH/includes/discovery" \
    "$LIBRENMS_PATH/config.d"
echo -e "${GREEN}✓ Permissions set${NC}\n"

echo -e "${YELLOW}Step 7: Validating installation...${NC}"

FILES_TO_CHECK=(
    "$LIBRENMS_PATH/includes/polling/zte-optical-power.inc.php"
    "$LIBRENMS_PATH/includes/polling/zte-ont-status.inc.php"
    "$LIBRENMS_PATH/includes/discovery/sensors/optical-power/zte-c300.inc.php"
    "$LIBRENMS_PATH/includes/discovery/zte-ont-discovery.inc.php"
    "$LIBRENMS_PATH/config.d/zte-c300-config.php"
)

ALL_FILES_EXIST=true
for file in "${FILES_TO_CHECK[@]}"; do
    if docker exec "$CONTAINER_NAME" test -f "$file"; then
        echo -e "  ${GREEN}✓${NC} $file"
    else
        echo -e "  ${RED}✗${NC} $file"
        ALL_FILES_EXIST=false
    fi
done

if [ "$ALL_FILES_EXIST" = true ]; then
    echo -e "\n${GREEN}✓ All files installed successfully${NC}\n"
else
    echo -e "\n${RED}✗ Some files are missing${NC}\n"
    exit 1
fi

echo -e "${YELLOW}Step 8: Restarting LibreNMS services...${NC}"
docker restart "$CONTAINER_NAME"
docker restart librenms_dispatcher

echo -e "${GREEN}✓ Services restarted${NC}\n"

echo -e "${GREEN}=== Installation Complete ===${NC}\n"

echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Add your ZTE C300 device to LibreNMS:"
echo "   docker exec -it librenms lnms device:add <hostname> --v2c --community <community>"
echo ""
echo "2. Run discovery to detect sensors and ONTs:"
echo "   docker exec -it librenms lnms device:poll <device_id> -m discovery"
echo ""
echo "3. View optical power sensors:"
echo "   Navigate to Device → Health → Sensors → Optical Power"
echo ""
echo "4. Query ONT data:"
echo "   docker exec -it librenms mysql -h db -u librenms -p librenms -e 'SELECT * FROM onts;'"
echo ""
echo -e "${GREEN}For more information, see: librenms/custom-modules/README.md${NC}"
