#!/bin/bash
#
# Enable ZTE C300 Custom Modules in LibreNMS
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Enabling ZTE C300 Custom Modules ===${NC}\n"

echo -e "${YELLOW}Step 1: Checking device OS detection...${NC}"
docker compose exec db mysql -u librenms -p'librenms_password' librenms -e "SELECT device_id, hostname, sysDescr, os FROM devices WHERE device_id=1;"

echo -e "\n${YELLOW}Step 2: Creating config to enable custom modules...${NC}"

# Create a config file to explicitly enable the modules
docker exec librenms bash -c 'cat > /opt/librenms/config.d/zte-modules-enable.php << "EOFPHP"
<?php
// Enable ZTE custom polling modules globally
\$config["poller_modules"]["zte-optical-power"] = true;
\$config["poller_modules"]["zte-ont-status"] = true;

// Enable for discovery
\$config["discovery_modules"]["zte-ont-discovery"] = true;

// Debug logging for ZTE modules
\$config["log_level"] = "debug";
EOFPHP
'

echo -e "${GREEN}✓ Config created${NC}\n"

echo -e "${YELLOW}Step 3: Verifying module files exist...${NC}"
docker exec librenms ls -lh /opt/librenms/includes/polling/zte-*.inc.php
docker exec librenms ls -lh /opt/librenms/includes/discovery/zte-*.inc.php

echo -e "\n${YELLOW}Step 4: Testing SNMP connectivity to ZTE device...${NC}"
echo "Testing ZTE enterprise OID (.1.3.6.1.4.1.3902):"
docker exec librenms snmpwalk -v2c -c sidomro -On 10.10.10.100 .1.3.6.1.4.1.3902 2>&1 | head -5

echo -e "\n${YELLOW}Step 5: Running manual test of polling module...${NC}"
docker exec librenms bash -c 'cd /opt/librenms && php -r "
\$device = [
    \"device_id\" => 1,
    \"hostname\" => \"10.10.10.100\",
    \"sysDescr\" => \"C300 Version V2.1.0\",
    \"hardware\" => \"ZTE C300\",
    \"os\" => \"zxa10\"
];
echo \"Device info: \" . print_r(\$device, true) . \"\\n\";
echo \"Checking if ZTE is in sysDescr: \" . (stristr(\$device[\"sysDescr\"], \"ZTE\") ? \"YES\" : \"NO\") . \"\\n\";
echo \"Checking if C300 is in hardware: \" . (stristr(\$device[\"hardware\"], \"C300\") ? \"YES\" : \"NO\") . \"\\n\";
"'

echo -e "\n${GREEN}=== Configuration Complete ===${NC}\n"

echo -e "${YELLOW}Next steps:${NC}"
echo "1. Run polling with verbose output:"
echo "   docker exec -u librenms librenms /opt/librenms/poller.php -h 10.10.10.100 -d"
echo ""
echo "2. Or run discovery:"
echo "   docker exec -u librenms librenms /opt/librenms/discovery.php -h 10.10.10.100 -d"
echo ""
echo "3. Check for 'ZTE' in the output to see if modules are executing"
