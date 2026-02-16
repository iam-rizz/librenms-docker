<?php
/**
 * ZTE C300 Optical Power Polling Module
 * 
 * This module polls optical power (tx/rx) from ZTE C300 OLT PON ports
 * and stores the data in the sensors table.
 * 
 */

use LibreNMS\RRD\RrdDefinition;

// ZTE C300 Optical Power OIDs
// These are ZTE proprietary MIB OIDs for optical power monitoring
$zte_optical_power_oids = [
    'tx_power' => '.1.3.6.1.4.1.3902.1082.500.10.2.1.1.1',  // zxAnPonOltOpticalDdmTxPower
    'rx_power' => '.1.3.6.1.4.1.3902.1082.500.10.2.1.1.2',  // zxAnPonOltOpticalDdmRxPower
    'pon_port_table' => '.1.3.6.1.4.1.3902.1082.500.10.2.1',  // zxAnPonOltOpticalDdmTable
];

// Only run for ZTE devices
if (stristr($device['sysDescr'], 'ZTE') || stristr($device['hardware'], 'C300')) {
    echo "ZTE Optical Power: ";
    
    // Walk the optical power table to get all PON ports
    $optical_data = snmpwalk_cache_oid($device, 'zxAnPonOltOpticalDdmTable', [], 'ZTE-AN-PON-MIB');
    
    if (!empty($optical_data)) {
        foreach ($optical_data as $index => $entry) {
            // Parse PON port identifier from index
            // Index format: shelf.slot.port (e.g., 1.1.1 for gpon-olt_1/1/1)
            $port_parts = explode('.', $index);
            if (count($port_parts) >= 3) {
                $shelf = $port_parts[0];
                $slot = $port_parts[1];
                $port = $port_parts[2];
                $port_name = "gpon-olt_{$shelf}/{$slot}/{$port}";
            } else {
                $port_name = "pon-port-{$index}";
            }
            
            // Get TX power (in 0.01 dBm, need to convert to dBm)
            if (isset($entry['zxAnPonOltOpticalDdmTxPower'])) {
                $tx_power_raw = $entry['zxAnPonOltOpticalDdmTxPower'];
                $tx_power = $tx_power_raw / 100;  // Convert to dBm
                
                // Define sensor for TX power
                $sensor_index = "tx-{$index}";
                $sensor_type = 'zte-optical-tx';
                $sensor_descr = "{$port_name} TX Power";
                
                // Normal range for TX power: -8 to +2 dBm
                $limit_low = -10;
                $limit_high = 3;
                $limit_low_warn = -8;
                $limit_high_warn = 2;
                
                discover_sensor(
                    $valid['sensor'],
                    'optical-power',
                    $device,
                    $zte_optical_power_oids['tx_power'] . '.' . $index,
                    $sensor_index,
                    $sensor_type,
                    $sensor_descr,
                    1,  // divisor
                    1,  // multiplier
                    $limit_low,
                    $limit_low_warn,
                    $limit_high_warn,
                    $limit_high,
                    $tx_power
                );
                
                echo "TX:{$port_name}={$tx_power}dBm ";
            }
            
            // Get RX power (in 0.01 dBm, need to convert to dBm)
            if (isset($entry['zxAnPonOltOpticalDdmRxPower'])) {
                $rx_power_raw = $entry['zxAnPonOltOpticalDdmRxPower'];
                $rx_power = $rx_power_raw / 100;  // Convert to dBm
                
                // Define sensor for RX power
                $sensor_index = "rx-{$index}";
                $sensor_type = 'zte-optical-rx';
                $sensor_descr = "{$port_name} RX Power";
                
                // Normal range for RX power: -28 to -8 dBm (per requirements)
                $limit_low = -30;
                $limit_high = -6;
                $limit_low_warn = -28;
                $limit_high_warn = -8;
                
                discover_sensor(
                    $valid['sensor'],
                    'optical-power',
                    $device,
                    $zte_optical_power_oids['rx_power'] . '.' . $index,
                    $sensor_index,
                    $sensor_type,
                    $sensor_descr,
                    1,  // divisor
                    1,  // multiplier
                    $limit_low,
                    $limit_low_warn,
                    $limit_high_warn,
                    $limit_high,
                    $rx_power
                );
                
                echo "RX:{$port_name}={$rx_power}dBm ";
            }
        }
        echo "\n";
    } else {
        echo "No optical power data available\n";
    }
}

unset($optical_data, $port_parts, $tx_power_raw, $rx_power_raw, $tx_power, $rx_power);
