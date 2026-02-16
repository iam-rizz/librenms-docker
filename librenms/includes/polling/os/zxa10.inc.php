<?php
/**
 * ZTE ZXA10 (C300) OS-Specific Polling
 * 
 * This file is automatically loaded when polling devices with os='zxa10'
 */

use LibreNMS\RRD\RrdDefinition;

// ============================================================================
// ZTE ONT Status Polling
// ============================================================================

echo "ZTE ONT Status: ";

$zte_ont_oids = [
    'ont_table' => '.1.3.6.1.4.1.3902.1082.500.11.2.1',
];

// Walk the ONT table to get all ONTs
$ont_data = snmpwalk_cache_oid($device, 'zxAnPonOnuTable', [], 'ZTE-AN-PON-MIB');

if (!empty($ont_data)) {
    $ont_count = 0;
    $online_count = 0;
    $offline_count = 0;
    
    foreach ($ont_data as $index => $entry) {
        // Parse ONT identifier from index
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
        
        // Get ONT status
        $status_code = isset($entry['zxAnPonOnuStatus']) ? $entry['zxAnPonOnuStatus'] : 0;
        $status_map = [1 => 'online', 2 => 'offline', 3 => 'dying-gasp'];
        $status = isset($status_map[$status_code]) ? $status_map[$status_code] : 'unknown';
        
        $serial_number = isset($entry['zxAnPonOnuSerialNumber']) ? $entry['zxAnPonOnuSerialNumber'] : '';
        $model = isset($entry['zxAnPonOnuModel']) ? $entry['zxAnPonOnuModel'] : '';
        $firmware = isset($entry['zxAnPonOnuFirmwareVersion']) ? $entry['zxAnPonOnuFirmwareVersion'] : '';
        
        $rx_power = 0;
        if (isset($entry['zxAnPonOnuRxPower'])) {
            $rx_power = $entry['zxAnPonOnuRxPower'] / 100;
        }
        
        // Store ONT data in database
        $ont_exists = dbFetchCell(
            'SELECT COUNT(*) FROM onts WHERE device_id = ? AND pon_port = ? AND ont_index = ?',
            [$device['device_id'], $pon_port, $ont_id]
        );
        
        $current_time = date('Y-m-d H:i:s');
        
        if ($ont_exists) {
            dbUpdate(
                [
                    'serial_number' => $serial_number,
                    'model' => $model,
                    'firmware_version' => $firmware,
                    'status' => $status,
                    'rx_power' => $rx_power,
                    'last_seen' => $current_time,
                ],
                'onts',
                'device_id = ? AND pon_port = ? AND ont_index = ?',
                [$device['device_id'], $pon_port, $ont_id]
            );
        } else {
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
                    'last_seen' => $current_time,
                ],
                'onts'
            );
        }
        
        $ont_count++;
        if ($status === 'online') {
            $online_count++;
        } elseif ($status === 'offline') {
            $offline_count++;
        }
        
        echo "{$pon_port}:{$ont_id}={$status} ";
    }
    
    echo "\nTotal: {$ont_count} ONTs (Online: {$online_count}, Offline: {$offline_count})\n";
    
    // Store ONT statistics as RRD data
    $rrd_def = RrdDefinition::make()
        ->addDataset('total', 'GAUGE', 0)
        ->addDataset('online', 'GAUGE', 0)
        ->addDataset('offline', 'GAUGE', 0);
    
    $fields = [
        'total' => $ont_count,
        'online' => $online_count,
        'offline' => $offline_count,
    ];
    
    $tags = ['rrd_def' => $rrd_def, 'rrd_name' => ['ont-stats']];
    data_update($device, 'ont-stats', $tags, $fields);
    
} else {
    echo "No ONT data available\n";
}

// ============================================================================
// ZTE Optical Power Polling
// ============================================================================

echo "ZTE Optical Power: ";

$zte_optical_power_oids = [
    'tx_power' => '.1.3.6.1.4.1.3902.1082.500.10.2.1.1.1',
    'rx_power' => '.1.3.6.1.4.1.3902.1082.500.10.2.1.1.2',
    'pon_port_table' => '.1.3.6.1.4.1.3902.1082.500.10.2.1',
];

// Walk the optical power table
$optical_data = snmpwalk_cache_oid($device, 'zxAnPonOltOpticalDdmTable', [], 'ZTE-AN-PON-MIB');

if (!empty($optical_data)) {
    foreach ($optical_data as $index => $entry) {
        $port_parts = explode('.', $index);
        if (count($port_parts) >= 3) {
            $shelf = $port_parts[0];
            $slot = $port_parts[1];
            $port = $port_parts[2];
            $port_name = "gpon-olt_{$shelf}/{$slot}/{$port}";
        } else {
            $port_name = "pon-port-{$index}";
        }
        
        // Get TX power
        if (isset($entry['zxAnPonOltOpticalDdmTxPower'])) {
            $tx_power = $entry['zxAnPonOltOpticalDdmTxPower'] / 100;
            
            $sensor_index = "tx-{$index}";
            $sensor_type = 'zte-optical-tx';
            $sensor_descr = "{$port_name} TX Power";
            
            discover_sensor(
                $valid['sensor'],
                'optical-power',
                $device,
                $zte_optical_power_oids['tx_power'] . '.' . $index,
                $sensor_index,
                $sensor_type,
                $sensor_descr,
                1, 1, -10, -8, 2, 3, $tx_power
            );
            
            echo "TX:{$port_name}={$tx_power}dBm ";
        }
        
        // Get RX power
        if (isset($entry['zxAnPonOltOpticalDdmRxPower'])) {
            $rx_power = $entry['zxAnPonOltOpticalDdmRxPower'] / 100;
            
            $sensor_index = "rx-{$index}";
            $sensor_type = 'zte-optical-rx';
            $sensor_descr = "{$port_name} RX Power";
            
            discover_sensor(
                $valid['sensor'],
                'optical-power',
                $device,
                $zte_optical_power_oids['rx_power'] . '.' . $index,
                $sensor_index,
                $sensor_type,
                $sensor_descr,
                1, 1, -30, -28, -8, -6, $rx_power
            );
            
            echo "RX:{$port_name}={$rx_power}dBm ";
        }
    }
    echo "\n";
} else {
    echo "No optical power data available\n";
}

unset($ont_data, $optical_data, $ont_parts, $port_parts, $status_code, $status_map, $ont_exists);
