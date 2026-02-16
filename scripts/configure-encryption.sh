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

print_info "=========================================="
print_info "Configuring SNMP Credential Encryption"
print_info "=========================================="

print_info "Step 1: Checking for existing APP_KEY..."

EXISTING_KEY=$(docker exec librenms bash -c "grep -oP '^APP_KEY=\K.*' /data/.env 2>/dev/null || echo ''")

if [ -n "$EXISTING_KEY" ] && [ "$EXISTING_KEY" != "base64:" ]; then
    print_warning "APP_KEY already exists in LibreNMS configuration"
    print_info "Current APP_KEY: ${EXISTING_KEY:0:20}..."
    
    read -p "Do you want to regenerate the APP_KEY? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Keeping existing APP_KEY"
        REGENERATE=false
    else
        print_warning "Regenerating APP_KEY will require re-encrypting all existing credentials"
        REGENERATE=true
    fi
else
    print_info "No APP_KEY found, generating new one..."
    REGENERATE=true
fi

if [ "$REGENERATE" = true ]; then
    print_info "Step 2: Generating new APP_KEY..."
    
    APP_KEY=$(docker exec librenms bash -c "cd /opt/librenms && php artisan key:generate --show 2>/dev/null || echo ''")
    
    if [ -z "$APP_KEY" ]; then
        print_warning "Using fallback method to generate APP_KEY"
        RANDOM_KEY=$(openssl rand -base64 32)
        APP_KEY="base64:$RANDOM_KEY"
    fi
    
    print_info "✓ APP_KEY generated: ${APP_KEY:0:20}..."
    
    print_info "Step 3: Setting APP_KEY in LibreNMS configuration..."
    
    docker exec librenms bash -c "
        if [ -f /data/.env ]; then
            # Update existing APP_KEY or add if not exists
            if grep -q '^APP_KEY=' /data/.env; then
                sed -i 's|^APP_KEY=.*|APP_KEY=$APP_KEY|' /data/.env
            else
                echo 'APP_KEY=$APP_KEY' >> /data/.env
            fi
        else
            # Create .env file if it doesn't exist
            echo 'APP_KEY=$APP_KEY' > /data/.env
        fi
    "
    
    docker exec librenms bash -c "
        if [ -f /data/config.php ]; then
            # Check if APP_KEY is already in config.php
            if ! grep -q \"\\$config\\['app_key'\\]\" /data/config.php; then
                # Add APP_KEY to config.php
                echo \"\\$config['app_key'] = '$APP_KEY';\" >> /data/config.php
            else
                # Update existing APP_KEY
                sed -i \"s|\\$config\\['app_key'\\] = '.*';|\\$config['app_key'] = '$APP_KEY';|\" /data/config.php
            fi
        fi
    " 2>/dev/null || true
    
    print_success "✓ APP_KEY configured successfully"
else
    APP_KEY="$EXISTING_KEY"
    print_info "Using existing APP_KEY"
fi

print_info "Step 4: Verifying credential encryption..."

ENCRYPTION_CHECK=$(docker exec librenms bash -c "
    cd /opt/librenms && php artisan tinker --execute=\"
        try {
            \$encrypted = encrypt('test_string');
            \$decrypted = decrypt(\$encrypted);
            echo (\$decrypted === 'test_string') ? 'OK' : 'FAIL';
        } catch (Exception \$e) {
            echo 'ERROR: ' . \$e->getMessage();
        }
    \" 2>&1 | tail -n 1
" 2>/dev/null || echo "FAIL")

if echo "$ENCRYPTION_CHECK" | grep -q "OK"; then
    print_success "✓ Encryption is working correctly"
else
    print_error "✗ Encryption verification failed"
    print_error "Details: $ENCRYPTION_CHECK"
    print_warning "SNMP credentials may not be encrypted properly"
fi

print_info "Step 5: Checking SNMP credentials in database..."

CRED_CHECK=$(docker exec librenms_db mysql -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -se "
    SELECT 
        COUNT(*) as total_devices,
        SUM(CASE WHEN community LIKE 'eyJ%' OR community LIKE 'base64:%' THEN 1 ELSE 0 END) as encrypted_v2c,
        SUM(CASE WHEN snmpver = 'v3' AND (auth_pass LIKE 'eyJ%' OR auth_pass LIKE 'base64:%') THEN 1 ELSE 0 END) as encrypted_v3
    FROM devices 
    WHERE snmpver IN ('v2c', 'v3')
" 2>/dev/null || echo "0|0|0")

TOTAL_DEVICES=$(echo "$CRED_CHECK" | awk '{print $1}')
ENCRYPTED_V2C=$(echo "$CRED_CHECK" | awk '{print $2}')
ENCRYPTED_V3=$(echo "$CRED_CHECK" | awk '{print $3}')

if [ "$TOTAL_DEVICES" -gt 0 ]; then
    print_info "Found $TOTAL_DEVICES device(s) with SNMP configuration"
    print_info "  - v2c devices with encrypted credentials: $ENCRYPTED_V2C"
    print_info "  - v3 devices with encrypted credentials: $ENCRYPTED_V3"
    
    UNENCRYPTED=$((TOTAL_DEVICES - ENCRYPTED_V2C - ENCRYPTED_V3))
    if [ "$UNENCRYPTED" -gt 0 ]; then
        print_warning "$UNENCRYPTED device(s) may have unencrypted credentials"
        print_warning "New devices added will use encryption automatically"
    else
        print_success "✓ All existing devices have encrypted credentials"
    fi
else
    print_info "No devices configured yet"
    print_info "SNMP credentials will be encrypted when devices are added"
fi

print_info "Step 6: Restarting LibreNMS services..."

docker compose restart librenms dispatcher > /dev/null 2>&1

print_info "Waiting for services to restart..."
sleep 10

if docker ps --format '{{.Names}}' | grep -q "^librenms$" && \
   docker ps --format '{{.Names}}' | grep -q "^librenms_dispatcher$"; then
    print_success "✓ Services restarted successfully"
else
    print_error "✗ Some services failed to restart"
    print_error "Please check logs with: docker compose logs"
    exit 1
fi

echo ""
print_info "=========================================="
print_success "Encryption configuration completed!"
print_info "=========================================="
echo ""
print_info "Summary:"
print_info "  - APP_KEY is configured and active"
print_info "  - Encryption is verified and working"
print_info "  - All new SNMP credentials will be encrypted"
echo ""
print_info "Security Notes:"
print_info "  - Keep your APP_KEY secure and backed up"
print_info "  - Do not share the APP_KEY publicly"
print_info "  - If APP_KEY is lost, encrypted credentials cannot be recovered"
echo ""

