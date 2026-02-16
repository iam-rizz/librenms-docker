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

print_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Add a network device to LibreNMS monitoring system.
Supports all SNMP-enabled devices (OLT, Router, Switch, Server, etc.)

OPTIONS:
    -h, --hostname HOSTNAME     Device hostname or IP address (required)
    -v, --version VERSION       SNMP version: v2c or v3 (required)
    -c, --community STRING      SNMP community string (required for v2c)
    -u, --username STRING       SNMP v3 username (required for v3)
    -p, --password STRING       SNMP v3 auth password (required for v3)
    -a, --auth-protocol PROTO   SNMP v3 auth protocol: MD5 or SHA (default: SHA)
    -P, --priv-password STRING  SNMP v3 privacy password (optional for v3)
    -A, --priv-protocol PROTO   SNMP v3 privacy protocol: AES or DES (default: AES)
    --help                      Display this help message

EXAMPLES:
    # Add ZTE C300 OLT with SNMP v2c
    $0 -h 192.168.1.1 -v v2c -c public

    # Add Mikrotik Router with SNMP v2c
    $0 -h 192.168.1.254 -v v2c -c public

    # Add Cisco Switch with SNMP v3 (auth only)
    $0 -h 10.0.0.1 -v v3 -u admin -p password123 -a SHA

    # Add Huawei OLT with SNMP v3 (auth + privacy)
    $0 -h 192.168.1.1 -v v3 -u admin -p password123 -a SHA -P privpass456 -A AES

EOF
}

HOSTNAME=""
SNMP_VERSION=""
COMMUNITY=""
AUTH_USERNAME=""
AUTH_PASSWORD=""
AUTH_PROTOCOL="SHA"
PRIV_PASSWORD=""
PRIV_PROTOCOL="AES"

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--hostname)
            HOSTNAME="$2"
            shift 2
            ;;
        -v|--version)
            SNMP_VERSION="$2"
            shift 2
            ;;
        -c|--community)
            COMMUNITY="$2"
            shift 2
            ;;
        -u|--username)
            AUTH_USERNAME="$2"
            shift 2
            ;;
        -p|--password)
            AUTH_PASSWORD="$2"
            shift 2
            ;;
        -a|--auth-protocol)
            AUTH_PROTOCOL="$2"
            shift 2
            ;;
        -P|--priv-password)
            PRIV_PASSWORD="$2"
            shift 2
            ;;
        -A|--priv-protocol)
            PRIV_PROTOCOL="$2"
            shift 2
            ;;
        --help)
            print_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            print_usage
            exit 1
            ;;
    esac
done

if [ -z "$HOSTNAME" ]; then
    print_error "Hostname is required"
    print_usage
    exit 1
fi

if [ -z "$SNMP_VERSION" ]; then
    print_error "SNMP version is required"
    print_usage
    exit 1
fi

if [ "$SNMP_VERSION" != "v2c" ] && [ "$SNMP_VERSION" != "v3" ]; then
    print_error "Invalid SNMP version. Must be 'v2c' or 'v3'"
    exit 1
fi

if [ "$SNMP_VERSION" = "v2c" ]; then
    if [ -z "$COMMUNITY" ]; then
        print_error "Community string is required for SNMP v2c"
        exit 1
    fi
elif [ "$SNMP_VERSION" = "v3" ]; then
    if [ -z "$AUTH_USERNAME" ] || [ -z "$AUTH_PASSWORD" ]; then
        print_error "Username and auth password are required for SNMP v3"
        exit 1
    fi
    
    if [ "$AUTH_PROTOCOL" != "MD5" ] && [ "$AUTH_PROTOCOL" != "SHA" ]; then
        print_error "Invalid auth protocol. Must be 'MD5' or 'SHA'"
        exit 1
    fi
    
    if [ -n "$PRIV_PASSWORD" ]; then
        if [ "$PRIV_PROTOCOL" != "AES" ] && [ "$PRIV_PROTOCOL" != "DES" ]; then
            print_error "Invalid privacy protocol. Must be 'AES' or 'DES'"
            exit 1
        fi
    fi
fi

if ! docker ps --format '{{.Names}}' | grep -q "^librenms$"; then
    print_error "LibreNMS container is not running. Please start the system first."
    exit 1
fi

print_info "=========================================="
print_info "Adding Network Device to LibreNMS"
print_info "=========================================="
print_info "Hostname: $HOSTNAME"
print_info "SNMP Version: $SNMP_VERSION"

print_info "Step 1: Validating SNMP connectivity..."

# Temporarily disable exit on error for SNMP test
set +e

if [ "$SNMP_VERSION" = "v2c" ]; then
    SNMP_TEST=$(docker exec librenms snmpget -v2c -c "$COMMUNITY" "$HOSTNAME" sysDescr.0 2>&1)
    SNMP_EXIT_CODE=$?
else
    if [ -n "$PRIV_PASSWORD" ]; then
        SNMP_TEST=$(docker exec librenms snmpget -v3 -l authPriv \
            -u "$AUTH_USERNAME" \
            -a "$AUTH_PROTOCOL" -A "$AUTH_PASSWORD" \
            -x "$PRIV_PROTOCOL" -X "$PRIV_PASSWORD" \
            "$HOSTNAME" sysDescr.0 2>&1)
    else
        SNMP_TEST=$(docker exec librenms snmpget -v3 -l authNoPriv \
            -u "$AUTH_USERNAME" \
            -a "$AUTH_PROTOCOL" -A "$AUTH_PASSWORD" \
            "$HOSTNAME" sysDescr.0 2>&1)
    fi
    SNMP_EXIT_CODE=$?
fi

# Re-enable exit on error
set -e

if [ $SNMP_EXIT_CODE -ne 0 ]; then
    print_error "SNMP connectivity validation failed"
    print_error "Details: $SNMP_TEST"
    
    if echo "$SNMP_TEST" | grep -qi "timeout"; then
        print_error "Device is unreachable or not responding to SNMP requests"
        print_error "Please check:"
        print_error "  - Device IP address is correct"
        print_error "  - Device is powered on and reachable"
        print_error "  - Firewall allows SNMP traffic (UDP port 161)"
    elif echo "$SNMP_TEST" | grep -qi "authentication"; then
        print_error "SNMP authentication failed"
        print_error "Please check:"
        print_error "  - Community string is correct (for v2c)"
        print_error "  - Username and password are correct (for v3)"
        print_error "  - Auth protocol matches device configuration"
    elif echo "$SNMP_TEST" | grep -qi "no response"; then
        print_error "Device did not respond to SNMP request"
        print_error "Please check:"
        print_error "  - SNMP is enabled on the device"
        print_error "  - SNMP version matches device configuration"
    else
        print_error "Unknown SNMP error occurred"
    fi
    
    exit 1
fi

print_info "✓ SNMP connectivity validated successfully"
print_info "Device info: $(echo "$SNMP_TEST" | grep -oP 'STRING: \K.*' || echo "$SNMP_TEST")"

print_info "Step 2: Adding device to LibreNMS..."

if [ "$SNMP_VERSION" = "v2c" ]; then
    ADD_CMD="lnms device:add $HOSTNAME --v2c -c \"$COMMUNITY\""
else
    if [ -n "$PRIV_PASSWORD" ]; then
        ADD_CMD="lnms device:add $HOSTNAME --v3 \
            --security-name \"$AUTH_USERNAME\" \
            --auth-protocol \"$AUTH_PROTOCOL\" --auth-password \"$AUTH_PASSWORD\" \
            --privacy-protocol \"$PRIV_PROTOCOL\" --privacy-password \"$PRIV_PASSWORD\""
    else
        ADD_CMD="lnms device:add $HOSTNAME --v3 \
            --security-name \"$AUTH_USERNAME\" \
            --auth-protocol \"$AUTH_PROTOCOL\" --auth-password \"$AUTH_PASSWORD\""
    fi
fi

ADD_RESULT=$(docker exec librenms bash -c "$ADD_CMD" 2>&1)
ADD_EXIT_CODE=$?

if [ $ADD_EXIT_CODE -ne 0 ]; then
    if echo "$ADD_RESULT" | grep -qi "already exists"; then
        print_warning "Device already exists in LibreNMS"
        DEVICE_ID=$(docker exec librenms lnms device:list | grep "$HOSTNAME" | awk '{print $1}')
    else
        print_error "Failed to add device to LibreNMS"
        print_error "Details: $ADD_RESULT"
        exit 1
    fi
else
    print_info "✓ Device added successfully"
    DEVICE_ID=$(echo "$ADD_RESULT" | grep -oP 'device_id: \K\d+' || echo "")
fi

print_info "Step 3: Triggering automatic discovery..."

if [ -n "$DEVICE_ID" ]; then
    DISCOVERY_RESULT=$(docker exec librenms lnms device:poll "$DEVICE_ID" -m discovery 2>&1)
    print_info "✓ Discovery triggered for device ID: $DEVICE_ID"
else
    DISCOVERY_RESULT=$(docker exec librenms lnms device:poll "$HOSTNAME" -m discovery 2>&1)
    print_info "✓ Discovery triggered for hostname: $HOSTNAME"
fi

print_info "Step 4: Discovery results..."
sleep 5  

DEVICE_INFO=$(docker exec librenms lnms report:devices | grep "$HOSTNAME" || echo "")

if [ -n "$DEVICE_INFO" ]; then
    print_info "✓ Device discovered successfully"
    echo ""
    print_info "Device Information:"
    echo "$DEVICE_INFO"
    echo ""
    
    if [ -n "$DEVICE_ID" ]; then
        PORT_COUNT=$(docker exec librenms mysql -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" \
            -se "SELECT COUNT(*) FROM ports WHERE device_id = $DEVICE_ID" 2>/dev/null || echo "0")
        print_info "Discovered ports: $PORT_COUNT"
        
        SENSOR_COUNT=$(docker exec librenms mysql -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" \
            -se "SELECT COUNT(*) FROM sensors WHERE device_id = $DEVICE_ID" 2>/dev/null || echo "0")
        print_info "Discovered sensors: $SENSOR_COUNT"
    fi
else
    print_warning "Could not retrieve device information"
fi

echo ""
print_info "=========================================="
print_info "Device addition completed!"
print_info "=========================================="
print_info "You can view the device in LibreNMS web interface at:"
print_info "http://localhost:80/device/$HOSTNAME"
echo ""

