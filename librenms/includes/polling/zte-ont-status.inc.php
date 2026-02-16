<?php
/**
 * ZTE C300 ONT Status Polling Module
 * 
 * This module polls ONT status (online/offline) from ZTE C300 OLT
 * and stores ONT data (serial number, model, firmware) in a custom table.
 * 
 */

use LibreNMS\RRD\RrdDefinition;

// ZTE C300 ONT Status OIDs
$zte_ont_oids = [
    'ont_table' => '.1.3.6.1.4.1.3902.1082.500.11.2.1',
    'ont_serial' => '.1.3.6.1.4.1.3902.1082.500.11.2.1.1.3',
    'ont_status' => '.1.3.6.1.4.1.3902.1082.500.11.2.1.1.1',
    'ont_model' => '.1.3.6.1.4.1.3902.1082.500.11.2.1.1.4',
    'ont_firmware' => '.1.3.6.1.4.1.3902.1082.500.11.2.1.1.5',
    'ont_rx_power' => '.1.3.6.1.4.1.3902.1082.500.11.2.1.1.6',
];

// Only run for ZTE devices
if (stristr($device['sysDescr'], 'ZTE') || stristr($device['hardware'], 'C300')) {
    echo "ZTE ONT Status: ";
    
    // Walk the ONT table to get all ONTs
    $ont_data = snmpwalk_cache_oid($device, 'zxAnPonOnuTable', [], 'ZTE-AN-PON-MIB');
    
    if (!empty($ont_data)) {
        $ont_count = 0;
        $online_count = 0;
        $offline_count = 0;
        
        foreach ($ont_data as $index => $entry) {
            // Parse ONT identifier from index
            // Index format: shelf.slot.port.ontid (e.g., 1.1.1.1 for first ONT on gpon-olt_1/1/1)
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
            
            // Get ONT status (1=online, 2=offline, 3=dying-gasp)
            $status_code = isset($entry['zxAnPonOnuStatus']) ? $entry['zxAnPonOnuStatus'] : 0;
            $status_map = [
                1 => 'online',
                2 => 'offline',
                3 => 'dying-gasp',
            ];
            $status = isset($status_map[$status_code]) ? $status_map[$status_code] : 'unknown';
            
            // Get ONT serial number
            $serial_number = isset($entry['zxAnPonOnuSerialNumber']) ? $entry['zxAnPonOnuSerialNumber'] : '';
            
            // Get ONT model
            $model = isset($entry['zxAnPonOnuModel']) ? $entry['zxAnPonOnuModel'] : '';
            
            // Get ONT firmware version
            $firmware = isset($entry['zxAnPonOnuFirmwareVersion']) ? $entry['zxAnPonOnuFirmwareVersion'] : '';
            
            // Get ONT RX power (in 0.01 dBm)
            $rx_power = 0;
            if (isset($entry['zxAnPonOnuRxPower'])) {
                $rx_power = $entry['zxAnPonOnuRxPower'] / 100;
            }
            
            // Store ONT data in database
            // Check if ONT already exists
            $ont_exists = dbFetchCell(
                'SELECT COUNT(*) FROM onts WHERE device_id = ? AND pon_port = ? AND ont_index = ?',
                [$device['device_id'], $pon_port, $ont_id]
            );
            
            $current_time = date('Y-m-d H:i:s');
            
            if ($ont_exists) {
                // Update existing ONT
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
        
        // Store ONT statistics as RRD data for graphing
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
}

unset($ont_data, $ont_parts, $status_code, $status_map, $ont_exists);
