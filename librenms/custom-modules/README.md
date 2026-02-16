# ZTE C300 Custom Polling Modules

This directory contains custom polling and discovery modules for ZTE C300 OLT devices in LibreNMS.

## Overview

The custom modules provide enhanced monitoring capabilities for ZTE C300 OLT devices:

1. **Optical Power Monitoring** - Monitors TX/RX optical power on PON ports
2. **ONT Status Monitoring** - Tracks all connected ONTs with status and identity information

## Requirements

- LibreNMS installation
- ZTE C300 OLT device with SNMP enabled
- ZTE proprietary MIB files (ZTE-AN-PON-MIB)
- SNMP v2c or v3 access to the OLT

## Installation

### 1. Copy Module Files

The module files should be placed in the LibreNMS installation directory:

```bash
# Optical Power Polling Module
cp includes/polling/zte-optical-power.inc.php /opt/librenms/includes/polling/

# Optical Power Discovery Module
cp includes/discovery/sensors/optical-power/zte-c300.inc.php /opt/librenms/includes/discovery/sensors/optical-power/

# ONT Status Polling Module
cp includes/polling/zte-ont-status.inc.php /opt/librenms/includes/polling/

# ONT Discovery Module
cp includes/discovery/zte-ont-discovery.inc.php /opt/librenms/includes/discovery/

# Configuration File
cp config/zte-c300-config.php /opt/librenms/config.d/
```

### 2. Create Database Table

Run the migration script to create the ONT table:

```bash
docker exec -it librenms mysql -u librenms -p librenms < database/migrations/create_onts_table.sql
```

Or manually execute the SQL:

```sql
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
    CONSTRAINT `onts_device_id_fk` FOREIGN KEY (`device_id`) 
        REFERENCES `devices` (`device_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### 3. Enable Modules in LibreNMS

Edit your LibreNMS configuration file (`/opt/librenms/config.php` or create a new file in `/opt/librenms/config.d/`):

```php
// Enable ZTE custom polling modules
$config['os']['zte']['polling_modules']['zte-optical-power'] = true;
$config['os']['zte']['polling_modules']['zte-ont-status'] = true;
```

### 4. Add ZTE MIB Files

Download and install ZTE proprietary MIB files:

```bash
# Copy ZTE MIB files to LibreNMS mibs directory
cp ZTE-AN-PON-MIB.mib /opt/librenms/mibs/zte/
```

### 5. Restart LibreNMS Services

```bash
docker restart librenms
docker restart librenms_dispatcher
```

## Usage

### Adding a ZTE C300 Device

Use the LibreNMS web interface or CLI to add the device:

```bash
# Using CLI
docker exec -it librenms lnms device:add <hostname> \
    --v2c \
    --community <community_string>

# Or with SNMP v3
docker exec -it librenms lnms device:add <hostname> \
    --v3 \
    --authlevel authPriv \
    --authname <username> \
    --authpass <password> \
    --authalgo SHA \
    --cryptopass <priv_password> \
    --cryptoalgo AES
```

### Running Discovery

After adding the device, run discovery to detect optical power sensors and ONTs:

```bash
# Full discovery
docker exec -it librenms lnms device:poll <device_id> -m discovery

# Discover only sensors
docker exec -it librenms lnms device:poll <device_id> -m sensors
```

### Viewing Data

#### Optical Power Data

Optical power data is stored in the `sensors` table and can be viewed:

- Web UI: Navigate to Device → Health → Sensors → Optical Power
- Graphs: Device → Graphs → Sensor Graphs

#### ONT Status Data

ONT data is stored in the custom `onts` table:

```sql
-- View all ONTs for a device
SELECT * FROM onts WHERE device_id = <device_id>;

-- View online ONTs
SELECT * FROM onts WHERE device_id = <device_id> AND status = 'online';

-- View ONT count by status
SELECT status, COUNT(*) as count 
FROM onts 
WHERE device_id = <device_id> 
GROUP BY status;
```

## Module Details

### Optical Power Monitoring

**OIDs Used:**
- TX Power: `.1.3.6.1.4.1.3902.1082.500.10.2.1.1.1` (zxAnPonOltOpticalDdmTxPower)
- RX Power: `.1.3.6.1.4.1.3902.1082.500.10.2.1.1.2` (zxAnPonOltOpticalDdmRxPower)

**Thresholds:**
- TX Power: -10 to +3 dBm (warning: -8 to +2 dBm)
- RX Power: -30 to -6 dBm (warning: -28 to -8 dBm)

**Polling Interval:** 5 minutes (default LibreNMS polling interval)

### ONT Status Monitoring

**OIDs Used:**
- ONT Table: `.1.3.6.1.4.1.3902.1082.500.11.2.1` (zxAnPonOnuTable)
- ONT Serial: `.1.3.6.1.4.1.3902.1082.500.11.2.1.1.3` (zxAnPonOnuSerialNumber)
- ONT Status: `.1.3.6.1.4.1.3902.1082.500.11.2.1.1.1` (zxAnPonOnuStatus)
- ONT Model: `.1.3.6.1.4.1.3902.1082.500.11.2.1.1.4` (zxAnPonOnuModel)
- ONT Firmware: `.1.3.6.1.4.1.3902.1082.500.11.2.1.1.5` (zxAnPonOnuFirmwareVersion)
- ONT RX Power: `.1.3.6.1.4.1.3902.1082.500.11.2.1.1.6` (zxAnPonOnuRxPower)

**Status Codes:**
- 1: Online
- 2: Offline
- 3: Dying-gasp (power failure)

**Data Stored:**
- Serial number
- Model/hardware type
- Firmware version
- Current status
- RX optical power
- Last seen timestamp

**Polling Interval:** 5 minutes (default LibreNMS polling interval)

## Troubleshooting

### Modules Not Running

Check if modules are enabled:

```bash
docker exec -it librenms lnms config:get os.zte.polling_modules
```

### No Data Collected

1. Verify SNMP connectivity:
```bash
docker exec -it librenms snmpwalk -v2c -c <community> <hostname> .1.3.6.1.4.1.3902
```

2. Check polling logs:
```bash
docker exec -it librenms tail -f /opt/librenms/logs/librenms.log
```

3. Run manual poll with debug:
```bash
docker exec -it librenms lnms device:poll <device_id> -v
```

### ONT Table Not Created

Manually create the table using the SQL in the migration file, or check database permissions.

### MIB Files Not Found

Ensure ZTE MIB files are in `/opt/librenms/mibs/zte/` and readable by the LibreNMS user.

## Alert Rules

You can create alert rules for optical power and ONT status:

### Optical Power Out of Range

```
Rule: %sensors.sensor_class = "optical-power" && (%sensors.sensor_current < -28 || %sensors.sensor_current > -8)
Severity: Warning
Delay: 5 minutes
```

### ONT Offline

```sql
-- Custom SQL alert rule
SELECT * FROM onts 
WHERE status = 'offline' 
AND last_seen > DATE_SUB(NOW(), INTERVAL 10 MINUTE)
```

## Performance Considerations

- Polling 100 ONTs takes approximately 10-15 seconds
- Database inserts/updates are batched for efficiency
- RRD files are created per PON port for optical power graphs
- ONT statistics are aggregated and stored in RRD for trending


## License

These custom modules are provided as-is for use with LibreNMS monitoring of ZTE C300 OLT devices.
