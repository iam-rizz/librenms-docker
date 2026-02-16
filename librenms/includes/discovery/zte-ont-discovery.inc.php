<?php
/**
 * ZTE C300 ONT Discovery Module
 * 
 * This module discovers all ONTs connected to ZTE C300 OLT
 * during device discovery phase.
 * 
 * 
 */

// Only discover for ZTE devices
if (stristr($device['sysDescr'], 'ZTE') || stristr($device['hardware'], 'C300')) {
    echo "Discovering ZTE C300 ONTs: ";
    
    // Create ONT table if it doesn't exist
    $ont_table_exists = dbFetchCell("SHOW TABLES LIKE 'onts'");
    
    if (!$ont_table_exists) {
        echo "Creating ONT table... ";
        dbQuery("
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
                CONSTRAINT `onts_device_id_fk` FOREIGN KEY (`device_id`) REFERENCES `devices` (`device_id`) ON DELETE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ");
        echo "Done. ";
    }
    
    // Walk the ONT table to discover all ONTs
    $ont_data = snmpwalk_cache_oid($device, 'zxAnPonOnuTable', [], 'ZTE-AN-PON-MIB');
    
    if (!empty($ont_data)) {
        $discovered_count = 0;
        
        foreach ($ont_data as $index => $entry) {
            // Parse ONT identifier
            $ont_parts = explode('.', $index);
            if (count($ont_parts) >= 4) {
                $shelf = $ont_parts[0];
                $slot = $ont_parts[1];
                $port = $ont_parts[2];
                $ont_id = $ont_parts[3];
                $pon_port = "gpon-olt_{$shelf}/{$slot}/{$port}";
            } else {
                $pon_port = "unknown";
                $ont_id = $index;
            }
            
            // Get ONT details
            $status_code = isset($entry['zxAnPonOnuStatus']) ? $entry['zxAnPonOnuStatus'] : 0;
            $status_map = [
                1 => 'online',
                2 => 'offline',
                3 => 'dying-gasp',
            ];
            $status = isset($status_map[$status_code]) ? $status_map[$status_code] : 'unknown';
            
            $serial_number = isset($entry['zxAnPonOnuSerialNumber']) ? $entry['zxAnPonOnuSerialNumber'] : '';
            $model = isset($entry['zxAnPonOnuModel']) ? $entry['zxAnPonOnuModel'] : '';
            $firmware = isset($entry['zxAnPonOnuFirmwareVersion']) ? $entry['zxAnPonOnuFirmwareVersion'] : '';
            
            $rx_power = 0;
            if (isset($entry['zxAnPonOnuRxPower'])) {
                $rx_power = $entry['zxAnPonOnuRxPower'] / 100;
            }
            
            // Check if ONT already exists
            $ont_exists = dbFetchCell(
                'SELECT COUNT(*) FROM onts WHERE device_id = ? AND pon_port = ? AND ont_index = ?',
                [$device['device_id'], $pon_port, $ont_id]
            );
            
            if (!$ont_exists) {
                // Insert new ONT
                dbInsert(
                    [
                        'device_id' => $device['device_id'],
                        'pon_port' => $pon_port,
                        'ont_index' => $ont_id,
                        'serial_number' => $serial_number,
                        'model' => $model,
                        'firmware_version' => $firmware,
                        'status' => $status,
                        'rx_power' => $rx_power,
                        'last_seen' => date('Y-m-d H:i:s'),
                    ],
                    'onts'
                );
                $discovered_count++;
            }
        }
        
        echo "Discovered {$discovered_count} new ONTs (Total: " . count($ont_data) . ")\n";
    } else {
        echo "No ONTs found\n";
    }
}

unset($ont_data, $ont_parts, $status_code, $status_map, $ont_exists);
