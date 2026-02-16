# Task 5: ZTE C300 Custom Modules Troubleshooting

## Problem
Custom ZTE modules were not executing during device polling. The ONT table was empty and no optical power sensors were discovered.

## Root Cause
The `install-zte-modules.sh` script was copying files to `/data` instead of `/opt/librenms` inside the container. LibreNMS looks for custom modules in `/opt/librenms/includes/`.

## Solution

### 1. Run the Verification Script
```bash
./scripts/verify-zte-modules.sh
```

This script will:
- Check if modules exist in the correct location
- Copy modules to `/opt/librenms/includes/` if needed
- Set proper permissions
- Verify PHP syntax

### 2. Trigger Discovery on ZTE Device
```bash
# Run discovery for device_id=1 (ZTE C300 at 10.10.10.100)
docker exec -u librenms librenms /opt/librenms/lnms device:poll 1 -m discovery -v
```

Look for these outputs in the discovery log:
- "Discovering ZTE C300 ONTs:"
- "ZTE Optical Power:"
- "ZTE ONT Status:"

### 3. Verify Data Collection

Check ONT table:
```bash
docker compose exec db mysql -u librenms -p'librenms_password' librenms -e "SELECT COUNT(*) FROM onts WHERE device_id=1;"
```

Check optical power sensors:
```bash
docker compose exec db mysql -u librenms -p'librenms_password' librenms -e "SELECT sensor_descr, sensor_current FROM sensors WHERE device_id=1 AND sensor_class='optical-power' LIMIT 10;"
```

Check ONT details:
```bash
docker compose exec db mysql -u librenms -p'librenms_password' librenms -e "SELECT pon_port, ont_index, serial_number, status FROM onts WHERE device_id=1 LIMIT 10;"
```

## Module Locations

Correct locations inside the container:
- `/opt/librenms/includes/polling/zte-optical-power.inc.php`
- `/opt/librenms/includes/polling/zte-ont-status.inc.php`
- `/opt/librenms/includes/discovery/zte-ont-discovery.inc.php`
- `/opt/librenms/includes/discovery/sensors/optical-power/zte-c300.inc.php`
- `/opt/librenms/config.d/zte-c300-config.php`

## Expected Behavior

### During Discovery
```
Discovering ZTE C300 ONTs: Discovered X new ONTs (Total: Y)
```

### During Polling
```
ZTE Optical Power: TX:gpon-olt_1/3/1=-2.5dBm RX:gpon-olt_1/3/1=-18.2dBm ...
ZTE ONT Status: gpon-olt_1/3/1:1=online gpon-olt_1/3/1:2=online ...
Total: X ONTs (Online: Y, Offline: Z)
```

## Common Issues

### Issue: "No ONTs found" or "No optical power data available"
**Cause**: Device might not be responding to SNMP queries for ZTE-specific OIDs

**Solution**:
1. Verify SNMP connectivity:
   ```bash
   docker exec librenms snmpwalk -v2c -c sidomro 10.10.10.100 .1.3.6.1.4.1.3902
   ```

2. Check if device is detected as ZTE:
   ```bash
   docker compose exec db mysql -u librenms -p'librenms_password' librenms -e "SELECT hostname, sysDescr, hardware, os FROM devices WHERE device_id=1;"
   ```

### Issue: Modules not executing
**Cause**: Files in wrong location or wrong permissions

**Solution**: Run `./scripts/verify-zte-modules.sh`

### Issue: PHP errors in modules
**Cause**: Syntax errors or missing LibreNMS functions

**Solution**: Check PHP syntax:
```bash
docker exec librenms php -l /opt/librenms/includes/polling/zte-optical-power.inc.php
```

## Manual Verification Commands

Check if modules are loaded:
```bash
# List all polling modules
docker exec librenms ls -la /opt/librenms/includes/polling/*.inc.php | grep zte

# List all discovery modules
docker exec librenms ls -la /opt/librenms/includes/discovery/*.inc.php | grep zte
```

Check LibreNMS logs:
```bash
docker logs librenms --tail 100 | grep -i "zte\|optical\|ont"
```

## Device Information
- Device ID: 1
- Hostname: 10.10.10.100
- Model: ZTE C300 Version V2.1.0
- SNMP Community: sidomro
- SNMP Version: v2c
