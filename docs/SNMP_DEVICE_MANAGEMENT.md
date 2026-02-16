# SNMP Device Management Guide

This guide explains how to manage SNMP devices in the LibreNMS monitoring system. While this system was designed for OLT monitoring, it supports **all SNMP-enabled network devices** including routers, switches, servers, wireless access points, and more.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Supported Devices](#supported-devices)
3. [Configure Encryption](#configure-encryption)
4. [Add SNMP Devices](#add-snmp-devices)
5. [Verify Encryption](#verify-encryption)
6. [Troubleshooting](#troubleshooting)

## Prerequisites

Before adding SNMP devices, ensure:

1. LibreNMS system is deployed and running:
   ```bash
   docker compose ps
   ```

2. You have SNMP credentials for your network device

3. The device is reachable from the LibreNMS container

4. SNMP is enabled on the target device

## Supported Devices

LibreNMS supports thousands of network devices. The `add-device.sh` script works with any SNMP-enabled device:

### OLT (Optical Line Terminal)
- **ZTE**: C300, C320, C600, C650
- **Huawei**: MA5608T, MA5680T, MA5800, MA5801
- **Fiberhome**: AN5516-01, AN5516-06, AN5506-04
- **Nokia/Alcatel**: 7302, 7330, 7360, 7450
- **Zhone**: MXK, MALC
- And other OLT vendors

### Router & Switch
- **Cisco**: IOS, IOS-XE, NX-OS, ASA
- **Mikrotik**: RouterOS, SwOS
- **Juniper**: JunOS (MX, EX, SRX series)
- **HP/Aruba**: ProCurve, Comware
- **Dell**: PowerConnect, Force10
- **Ubiquiti**: EdgeRouter, EdgeSwitch
- **TP-Link**: Managed switches
- **D-Link**: Managed switches

### Wireless Equipment
- **Ubiquiti**: UniFi AP, AirMax
- **Mikrotik**: Wireless routers/APs
- **Cambium Networks**: ePMP, PMP
- **Ruckus**: ZoneDirector, SmartZone
- **Aruba**: Wireless controllers

### Servers & Virtualization
- **Linux**: Ubuntu, CentOS, Debian (with net-snmp)
- **Windows**: Server 2012/2016/2019/2022
- **VMware**: ESXi, vCenter
- **Proxmox**: VE
- **FreeBSD**, **pfSense**, **OPNsense**

### Other Equipment
- **UPS**: APC, Eaton, CyberPower
- **PDU**: APC, Raritan, ServerTech
- **Environmental**: Temperature/Humidity sensors
- **IP Cameras**: Axis, Hikvision
- **Printers**: HP, Canon, Xerox
- **Storage**: NetApp, EMC, Synology, QNAP

**Note**: LibreNMS will automatically detect the device type and apply appropriate polling modules based on the SNMP sysDescr and sysObjectID.

## Configure Encryption

SNMP credentials are stored encrypted in the database using Laravel's encryption system. Before adding devices, configure the encryption key:

```bash
./scripts/configure-encryption.sh
```

This script will:
- Generate a secure APP_KEY for encryption
- Configure LibreNMS to use the APP_KEY
- Verify encryption is working correctly
- Check existing credentials encryption status

**Important Security Notes:**
- The APP_KEY is critical for decrypting credentials
- Back up your APP_KEY securely
- If the APP_KEY is lost, encrypted credentials cannot be recovered
- Never share the APP_KEY publicly

## Add SNMP Devices

The `add-device.sh` script is universal and works with any SNMP-enabled device. LibreNMS will automatically detect the device type and discover available interfaces and sensors.

### Adding Device with SNMP v2c

For SNMP v2c, you need the community string (commonly "public" or "private"):

**Example 1: Add ZTE C300 OLT**
```bash
./scripts/add-device.sh -h 192.168.1.1 -v v2c -c public
```

**Example 2: Add Mikrotik Router**
```bash
./scripts/add-device.sh -h 192.168.1.254 -v v2c -c public
```

**Example 3: Add Cisco Switch**
```bash
./scripts/add-device.sh -h 10.0.0.10 -v v2c -c mycommunity
```

Parameters:
- `-h, --hostname`: Device IP address or hostname (required)
- `-v, --version`: SNMP version (v2c or v3) (required)
- `-c, --community`: SNMP community string (required for v2c)

### Adding Device with SNMP v3 (Auth Only)

For SNMP v3 with authentication only (more secure than v2c):

**Example 1: Add Huawei OLT**
```bash
./scripts/add-device.sh \
  -h 192.168.1.2 \
  -v v3 \
  -u admin \
  -p huawei123 \
  -a SHA
```

**Example 2: Add Linux Server**
```bash
./scripts/add-device.sh \
  -h 192.168.1.100 \
  -v v3 \
  -u snmpuser \
  -p mypassword \
  -a SHA
```

Parameters:
- `-u, --username`: SNMP v3 username (required for v3)
- `-p, --password`: SNMP v3 auth password (required for v3)
- `-a, --auth-protocol`: Auth protocol - MD5 or SHA (default: SHA)

### Adding Device with SNMP v3 (Auth + Privacy)

For SNMP v3 with authentication and privacy (most secure):

**Example 1: Add Cisco Router**
```bash
./scripts/add-device.sh \
  -h 10.0.0.1 \
  -v v3 \
  -u cisco_admin \
  -p authpass123 \
  -a SHA \
  -P privpass456 \
  -A AES
```

**Example 2: Add Juniper Switch**
```bash
./scripts/add-device.sh \
  -h 10.0.0.20 \
  -v v3 \
  -u juniper_user \
  -p myauthpass \
  -a SHA \
  -P myprivpass \
  -A AES
```

Additional parameters:
- `-P, --priv-password`: SNMP v3 privacy password (optional)
- `-A, --priv-protocol`: Privacy protocol - AES or DES (default: AES)

## What the Script Does

The `add-device.sh` script performs the following steps:

1. **Validates Parameters**: Checks that all required parameters are provided
2. **Tests SNMP Connectivity**: Validates that the device is reachable via SNMP and retrieves device information
3. **Adds Device**: Adds the device to LibreNMS database with encrypted credentials
4. **Triggers Discovery**: Automatically discovers interfaces, sensors, and device-specific features
5. **Displays Results**: Shows discovered ports, sensors count, and device information

**Device Auto-Detection**: LibreNMS automatically detects the device type (OLT, router, switch, server, etc.) based on SNMP sysDescr and sysObjectID, then applies appropriate polling modules.

### Script Output

Successful execution will show:

```
[INFO] ==========================================
[INFO] Adding Network Device to LibreNMS
[INFO] ==========================================
[INFO] Hostname: 192.168.1.1
[INFO] SNMP Version: v2c
[INFO] Step 1: Validating SNMP connectivity...
[INFO] ✓ SNMP connectivity validated successfully
[INFO] Device info: ZTE ZXA10 C300 (or detected device type)
[INFO] Step 2: Adding device to LibreNMS...
[INFO] ✓ Device added successfully
[INFO] Step 3: Triggering automatic discovery...
[INFO] ✓ Discovery triggered for device ID: 1
[INFO] Step 4: Discovery results...
[INFO] ✓ Device discovered successfully
[INFO] Discovered ports: 24
[INFO] Discovered sensors: 48
[INFO] ==========================================
[INFO] Device addition completed!
[INFO] ==========================================
[INFO] You can view the device in LibreNMS web interface at:
[INFO] http://localhost:80/device/192.168.1.1
```

**Note**: The number of discovered ports and sensors will vary depending on the device type. For example:
- OLT devices typically have 16-24 PON ports plus uplink ports
- Switches may have 24-48 ports
- Routers may have fewer physical ports but many virtual interfaces
- Servers may have only a few network interfaces but many system sensors

## Verify Encryption

After adding devices, verify that credentials are properly encrypted:

```bash
./scripts/verify-encryption.sh
```

This script will:
- Check APP_KEY configuration
- Test encryption/decryption functionality
- Inspect database credentials
- Report encryption status for all devices

### Expected Output

```
[INFO] ==========================================
[INFO] SNMP Credential Encryption Verification
[INFO] ==========================================

[INFO] 1. Checking APP_KEY configuration...
[SUCCESS] ✓ APP_KEY found in .env: base64:abcdefgh1234...

[INFO] 2. Testing encryption functionality...
[SUCCESS] ✓ Encryption/decryption working correctly
[INFO]   Encrypted length: 156 bytes

[INFO] 3. Checking SNMP credentials in database...
[INFO]   Total SNMP devices: 2

[INFO]   SNMP v2c devices:
[INFO]     Total: 1
[INFO]     Encrypted: 1
[SUCCESS]     ✓ All v2c credentials are encrypted

[INFO]   SNMP v3 devices:
[INFO]     Total: 1
[INFO]     Encrypted: 1
[SUCCESS]     ✓ All v3 credentials are encrypted

[INFO] 4. Sample credential inspection...
[INFO]   Sample device: 192.168.1.1 (SNMP v2c)
[INFO]     Community string: eyJpdiI6IlR... (length: 156)
[SUCCESS]     ✓ Appears to be encrypted

[INFO] ==========================================
[SUCCESS] All credentials are encrypted!
[INFO] ==========================================
```

## Troubleshooting

### SNMP Connectivity Issues

If you get "SNMP timeout" or "Device unreachable" errors:

1. **Check network connectivity**:
   ```bash
   docker exec librenms ping -c 3 192.168.1.1
   ```

2. **Verify SNMP is enabled on the device**:
   - Log into the OLT web interface
   - Check SNMP configuration
   - Ensure SNMP service is running

3. **Check firewall rules**:
   - SNMP uses UDP port 161
   - Ensure firewall allows traffic from LibreNMS container

4. **Test SNMP manually**:
   ```bash
   docker exec librenms snmpwalk -v2c -c public 192.168.1.1 system
   ```

### Authentication Failures

If you get "SNMP authentication failed" errors:

1. **For SNMP v2c**:
   - Verify the community string is correct
   - Check if the device restricts access by IP address

2. **For SNMP v3**:
   - Verify username and password are correct
   - Ensure auth protocol (MD5/SHA) matches device configuration
   - Check if privacy is required on the device

### Encryption Issues

If encryption verification fails:

1. **Regenerate APP_KEY**:
   ```bash
   ./scripts/configure-encryption.sh
   ```
   Answer "y" when asked to regenerate

2. **Check LibreNMS logs**:
   ```bash
   docker compose logs librenms | grep -i encrypt
   ```

3. **Verify APP_KEY is set**:
   ```bash
   docker exec librenms cat /data/.env | grep APP_KEY
   ```

### Device Already Exists

If you get "Device already exists" warning:

1. **List existing devices**:
   ```bash
   docker exec librenms lnms device:list
   ```

2. **Remove device if needed**:
   ```bash
   docker exec librenms lnms device:remove <hostname>
   ```

3. **Re-add the device** with correct credentials

## Device-Specific Notes

### OLT Devices (ZTE, Huawei, Fiberhome)
- Ensure ZTE/Huawei proprietary MIBs are loaded for full functionality
- PON ports and ONT discovery may take longer (5-10 minutes)
- Optical power monitoring requires specific OIDs

### Mikrotik Devices
- Default community is often "public"
- Enable SNMP in System > SNMP settings
- RouterOS v7+ has improved SNMP support

### Cisco Devices
- Use `snmp-server community <string> RO` for v2c
- Use `snmp-server group` and `snmp-server user` for v3
- Enable SNMP with `snmp-server enable`

### Linux Servers
- Install net-snmp: `apt install snmpd` or `yum install net-snmp`
- Configure `/etc/snmp/snmpd.conf`
- Restart service: `systemctl restart snmpd`

### Windows Servers
- Enable SNMP service in Windows Features
- Configure community strings in Services > SNMP Service
- Allow SNMP traffic in Windows Firewall

## Best Practices

1. **Always configure encryption first** before adding devices
2. **Use SNMP v3** when possible for better security (especially for production devices)
3. **Use strong passwords** for SNMP v3 credentials (minimum 8 characters)
4. **Backup your APP_KEY** securely - without it, encrypted credentials cannot be recovered
5. **Regularly verify encryption** status with verify-encryption.sh
6. **Document device credentials** in a secure password manager
7. **Test SNMP connectivity** before adding devices to avoid failed additions
8. **Monitor discovery results** to ensure all interfaces and sensors are found
9. **Use descriptive hostnames** or add devices by IP if DNS is not available
10. **Group similar devices** using LibreNMS device groups for easier management
11. **Set device location** in LibreNMS for better organization
12. **Enable alerting** after adding devices to get notified of issues

## Common Device Types and Their Metrics

### OLT Devices
- **Interfaces**: PON ports, uplink ports, management interface
- **Sensors**: Optical power (tx/rx), temperature, voltage, fan speed
- **Custom**: ONT status, ONT count, PON utilization

### Routers
- **Interfaces**: Physical ports, VLANs, tunnels, loopback
- **Sensors**: CPU, memory, temperature
- **Routing**: BGP peers, OSPF neighbors, routing table size

### Switches
- **Interfaces**: Access ports, trunk ports, LAG/port-channels
- **Sensors**: CPU, memory, temperature, fan, PSU
- **Switching**: MAC table, VLAN info, STP status

### Servers
- **Interfaces**: Network interfaces (eth0, eth1, etc.)
- **Sensors**: CPU load, memory usage, disk usage, temperature
- **Services**: Running processes, system uptime

### Wireless
- **Interfaces**: Radio interfaces, SSIDs
- **Sensors**: Signal strength, noise floor, client count
- **Wireless**: Channel utilization, connected clients

## Related Documentation

- [Quick Start Guide](QUICK_START_PRESETS.md)
- [Environment Variables](ENVIRONMENT_VARIABLES.md)
- [Database Optimization](DATABASE_OPTIMIZATION.md)

