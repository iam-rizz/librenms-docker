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
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

if ! docker ps --format '{{.Names}}' | grep -q "^librenms$"; then
    print_error "LibreNMS container is not running. Please start the system first."
    exit 1
fi

if ! docker ps --format '{{.Names}}' | grep -q "^librenms_db$"; then
    print_error "Database container is not running. Please start the system first."
    exit 1
fi

print_info "=========================================="
print_info "SNMP Credential Encryption Verification"
print_info "=========================================="
echo ""

print_info "1. Checking APP_KEY configuration..."

APP_KEY_ENV=$(docker exec librenms bash -c "grep -oP '^APP_KEY=\K.*' /data/.env 2>/dev/null || echo ''")
APP_KEY_CONFIG=$(docker exec librenms bash -c "grep -oP \"\\$config\\['app_key'\\] = '\K[^']+\" /data/config.php 2>/dev/null || echo ''")

if [ -n "$APP_KEY_ENV" ] && [ "$APP_KEY_ENV" != "base64:" ]; then
    print_success "✓ APP_KEY found in .env: ${APP_KEY_ENV:0:20}..."
elif [ -n "$APP_KEY_CONFIG" ]; then
    print_success "✓ APP_KEY found in config.php: ${APP_KEY_CONFIG:0:20}..."
else
    print_error "✗ APP_KEY not configured"
    print_error "Please run: ./scripts/configure-encryption.sh"
    exit 1
fi

print_info "2. Testing encryption functionality..."

ENCRYPTION_TEST=$(docker exec librenms bash -c "
    cd /opt/librenms && php artisan tinker --execute=\"
        try {
            \$test_string = 'test_credential_12345';
            \$encrypted = encrypt(\$test_string);
            \$decrypted = decrypt(\$encrypted);
            if (\$decrypted === \$test_string) {
                echo 'PASS|' . strlen(\$encrypted) . '|' . substr(\$encrypted, 0, 10);
            } else {
                echo 'FAIL|Decryption mismatch';
            }
        } catch (Exception \$e) {
            echo 'ERROR|' . \$e->getMessage();
        }
    \" 2>&1 | tail -n 1
" 2>/dev/null || echo "ERROR|Command failed")

TEST_STATUS=$(echo "$ENCRYPTION_TEST" | cut -d'|' -f1)
TEST_DETAILS=$(echo "$ENCRYPTION_TEST" | cut -d'|' -f2-)

if [ "$TEST_STATUS" = "PASS" ]; then
    print_success "✓ Encryption/decryption working correctly"
    print_info "  Encrypted length: $(echo "$TEST_DETAILS" | cut -d'|' -f1) bytes"
else
    print_error "✗ Encryption test failed: $TEST_DETAILS"
    exit 1
fi

print_info "3. Checking SNMP credentials in database..."

DB_QUERY="
SELECT 
    COUNT(*) as total,
    SUM(CASE WHEN snmpver = 'v2c' THEN 1 ELSE 0 END) as v2c_count,
    SUM(CASE WHEN snmpver = 'v3' THEN 1 ELSE 0 END) as v3_count,
    SUM(CASE 
        WHEN snmpver = 'v2c' AND (
            community LIKE 'eyJ%' OR 
            community LIKE 'base64:%' OR
            LENGTH(community) > 50
        ) THEN 1 
        ELSE 0 
    END) as v2c_encrypted,
    SUM(CASE 
        WHEN snmpver = 'v3' AND (
            authlevel IN ('authPriv', 'authNoPriv') AND
            (authpass LIKE 'eyJ%' OR authpass LIKE 'base64:%' OR LENGTH(authpass) > 50)
        ) THEN 1 
        ELSE 0 
    END) as v3_encrypted
FROM devices 
WHERE snmpver IN ('v2c', 'v3') AND disabled = 0
"

DB_RESULT=$(docker exec librenms_db mysql -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -se "$DB_QUERY" 2>/dev/null || echo "0 0 0 0 0")

TOTAL=$(echo "$DB_RESULT" | awk '{print $1}')
V2C_COUNT=$(echo "$DB_RESULT" | awk '{print $2}')
V3_COUNT=$(echo "$DB_RESULT" | awk '{print $3}')
V2C_ENCRYPTED=$(echo "$DB_RESULT" | awk '{print $4}')
V3_ENCRYPTED=$(echo "$DB_RESULT" | awk '{print $5}')

if [ "$TOTAL" -eq 0 ]; then
    print_info "  No SNMP devices configured yet"
    print_info "  Credentials will be encrypted when devices are added"
else
    print_info "  Total SNMP devices: $TOTAL"
    echo ""
    
    if [ "$V2C_COUNT" -gt 0 ]; then
        print_info "  SNMP v2c devices:"
        print_info "    Total: $V2C_COUNT"
        print_info "    Encrypted: $V2C_ENCRYPTED"
        
        if [ "$V2C_ENCRYPTED" -eq "$V2C_COUNT" ]; then
            print_success "    ✓ All v2c credentials are encrypted"
        else
            UNENCRYPTED=$((V2C_COUNT - V2C_ENCRYPTED))
            print_warning "    ⚠ $UNENCRYPTED v2c device(s) may have unencrypted credentials"
        fi
    fi
    
    echo ""
    
    if [ "$V3_COUNT" -gt 0 ]; then
        print_info "  SNMP v3 devices:"
        print_info "    Total: $V3_COUNT"
        print_info "    Encrypted: $V3_ENCRYPTED"
        
        if [ "$V3_ENCRYPTED" -eq "$V3_COUNT" ]; then
            print_success "    ✓ All v3 credentials are encrypted"
        else
            UNENCRYPTED=$((V3_COUNT - V3_ENCRYPTED))
            print_warning "    ⚠ $UNENCRYPTED v3 device(s) may have unencrypted credentials"
        fi
    fi
fi

if [ "$TOTAL" -gt 0 ]; then
    echo ""
    print_info "4. Sample credential inspection..."
    
    SAMPLE=$(docker exec librenms_db mysql -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -se "
        SELECT 
            hostname,
            snmpver,
            SUBSTRING(community, 1, 20) as community_sample,
            SUBSTRING(authpass, 1, 20) as authpass_sample,
            LENGTH(community) as community_len,
            LENGTH(authpass) as authpass_len
        FROM devices 
        WHERE snmpver IN ('v2c', 'v3') AND disabled = 0
        LIMIT 1
    " 2>/dev/null || echo "")
    
    if [ -n "$SAMPLE" ]; then
        HOSTNAME=$(echo "$SAMPLE" | awk '{print $1}')
        SNMPVER=$(echo "$SAMPLE" | awk '{print $2}')
        
        print_info "  Sample device: $HOSTNAME (SNMP $SNMPVER)"
        
        if [ "$SNMPVER" = "v2c" ]; then
            COMM_SAMPLE=$(echo "$SAMPLE" | awk '{print $3}')
            COMM_LEN=$(echo "$SAMPLE" | awk '{print $5}')
            print_info "    Community string: ${COMM_SAMPLE}... (length: $COMM_LEN)"
            
            if [ "$COMM_LEN" -gt 50 ] || [[ "$COMM_SAMPLE" == eyJ* ]] || [[ "$COMM_SAMPLE" == base64:* ]]; then
                print_success "    ✓ Appears to be encrypted"
            else
                print_warning "    ⚠ May be plaintext (length: $COMM_LEN)"
            fi
        else
            AUTH_SAMPLE=$(echo "$SAMPLE" | awk '{print $4}')
            AUTH_LEN=$(echo "$SAMPLE" | awk '{print $6}')
            print_info "    Auth password: ${AUTH_SAMPLE}... (length: $AUTH_LEN)"
            
            if [ "$AUTH_LEN" -gt 50 ] || [[ "$AUTH_SAMPLE" == eyJ* ]] || [[ "$AUTH_SAMPLE" == base64:* ]]; then
                print_success "    ✓ Appears to be encrypted"
            else
                print_warning "    ⚠ May be plaintext (length: $AUTH_LEN)"
            fi
        fi
    fi
fi

echo ""
print_info "=========================================="

ENCRYPTED_TOTAL=$((V2C_ENCRYPTED + V3_ENCRYPTED))
if [ "$TOTAL" -eq 0 ]; then
    print_success "Encryption is configured and ready"
    print_info "New devices will have encrypted credentials"
elif [ "$ENCRYPTED_TOTAL" -eq "$TOTAL" ]; then
    print_success "All credentials are encrypted!"
else
    UNENCRYPTED_TOTAL=$((TOTAL - ENCRYPTED_TOTAL))
    print_warning "Encryption is configured but $UNENCRYPTED_TOTAL device(s) may have unencrypted credentials"
    print_info "Consider re-adding these devices to ensure encryption"
fi

print_info "=========================================="
echo ""

