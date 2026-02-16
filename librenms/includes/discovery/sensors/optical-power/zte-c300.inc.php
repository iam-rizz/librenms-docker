<?php
/**
 * ZTE C300 Optical Power Discovery Module
 * 
 * This module discovers optical power sensors (tx/rx) on ZTE C300 OLT PON ports
 * during device discovery phase.
 * 
 * Requirements: 4.1, 4.2
 */

// ZTE C300 Optical Power OIDs
$zte_optical_power_oids = [
    'tx_power' => '.1.3.6.1.4.1.3902.1082.500.10.2.1.1.1',  // zxAnPonOltOpticalDdmTxPower
    'rx_power' => '.1.3.6.1.4.1.3902.1082.500.10.2.1.1.2',  // zxAnPonOltOpticalDdmRxPower
];

// Only discover for ZTE devices
if (stristr($device['sysDescr'], 'ZTE') || stristr($device['hardware'], 'C300')) {
    echo "Discovering ZTE C300 Optical Power Sensors: ";
    
    // Discover TX Power sensors
    $tx_power_data = snmpwalk_cache_oid($device, 'zxAnPonOltOpticalDdmTxPower', [], 'ZTE-AN-PON-MIB');
    
    if (!empty($tx_power_data)) {
        foreach ($tx_power_data as $index => $entry) {
            // Parse PON port identifier
            $port_parts = explode('.', $index);
            if (count($port_parts) >= 3) {
                $shelf = $port_parts[0];
                $slot = $port_parts[1];
                $port = $port_parts[2];
                $port_name = "gpon-olt_{$shelf}/{$slot}/{$port}";
            } else {
                $port_name = "pon-port-{$index}";
            }
            
            $tx_power_raw = $entry['zxAnPonOltOpticalDdmTxPower'];
            $tx_power = $tx_power_raw / 100;  // Convert from 0.01 dBm to dBm
            
            $oid = $zte_optical_power_oids['tx_power'] . '.' . $index;
            $sensor_index = "tx-{$index}";
            $sensor_type = 'zte-optical-tx';
            $sensor_descr = "{$port_name} TX Power";
            
            // Normal TX power range: -8 to +2 dBm
            $limit_low = -10;
            $limit_high = 3;
            $limit_low_warn = -8;
            $limit_high_warn = 2;
            
            discover_sensor(
                $valid['sensor'],
                'optical-power',
                $device,
                $oid,
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
        }
    }
    
    // Discover RX Power sensors
    $rx_power_data = snmpwalk_cache_oid($device, 'zxAnPonOltOpticalDdmRxPower', [], 'ZTE-AN-PON-MIB');
    
    if (!empty($rx_power_data)) {
        foreach ($rx_power_data as $index => $entry) {
            // Parse PON port identifier
            $port_parts = explode('.', $index);
            if (count($port_parts) >= 3) {
                $shelf = $port_parts[0];
                $slot = $port_parts[1];
                $port = $port_parts[2];
                $port_name = "gpon-olt_{$shelf}/{$slot}/{$port}";
            } else {
                $port_name = "pon-port-{$index}";
            }
            
            $rx_power_raw = $entry['zxAnPonOltOpticalDdmRxPower'];
            $rx_power = $rx_power_raw / 100;  // Convert from 0.01 dBm to dBm
            
            $oid = $zte_optical_power_oids['rx_power'] . '.' . $index;
            $sensor_index = "rx-{$index}";
            $sensor_type = 'zte-optical-rx';
            $sensor_descr = "{$port_name} RX Power";
            
            // Normal RX power range: -28 to -8 dBm (per requirements)
            $limit_low = -30;
            $limit_high = -6;
            $limit_low_warn = -28;
            $limit_high_warn = -8;
            
            discover_sensor(
                $valid['sensor'],
                'optical-power',
                $device,
                $oid,
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
        }
    }
    
    echo "Found " . count($tx_power_data) . " TX and " . count($rx_power_data) . " RX power sensors\n";
}

unset($tx_power_data, $rx_power_data, $port_parts, $tx_power_raw, $rx_power_raw);
