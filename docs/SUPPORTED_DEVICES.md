# Supported Devices

LibreNMS adalah platform monitoring universal yang mendukung ribuan jenis perangkat jaringan. Sistem ini **TIDAK terbatas hanya untuk ZTE C300 OLT** - Anda dapat memonitor semua perangkat yang support SNMP.

## Cara Kerja Auto-Detection

LibreNMS menggunakan SNMP untuk mendeteksi jenis perangkat secara otomatis:

1. **Query sysDescr** - Mendapatkan deskripsi sistem dari perangkat
2. **Query sysObjectID** - Mendapatkan vendor dan model identifier
3. **Apply Polling Modules** - Menerapkan module yang sesuai dengan jenis perangkat
4. **Discover Features** - Menemukan interface, sensor, dan fitur khusus

Anda tidak perlu konfigurasi manual - cukup tambahkan device dengan SNMP credentials yang benar, dan LibreNMS akan handle sisanya.

## Kategori Perangkat yang Didukung

### 1. OLT (Optical Line Terminal)

#### ZTE
- C300, C320, C600, C650
- Support: PON ports, ONT discovery, optical power monitoring
- SNMP: v2c dan v3
- Proprietary MIBs: Ya (untuk fitur advanced)

#### Huawei
- MA5608T, MA5680T, MA5800, MA5801
- Support: GPON/EPON, ONT management, optical power
- SNMP: v2c dan v3
- Proprietary MIBs: Ya

#### Fiberhome
- AN5516-01, AN5516-06, AN5506-04
- Support: PON monitoring, ONT status
- SNMP: v2c dan v3

#### Nokia/Alcatel-Lucent
- 7302, 7330, 7360, 7450
- Support: GPON/XGS-PON, comprehensive ONT management
- SNMP: v2c dan v3

#### Lainnya
- Zhone (MXK, MALC)
- Calix (E7, E9)
- Adtran
- Tellabs

### 2. Router

#### Cisco
- **IOS**: 800, 1900, 2900, 3900, 4000 series
- **IOS-XE**: ASR 1000, ISR 4000, Catalyst 9000
- **IOS-XR**: ASR 9000, NCS series
- **NX-OS**: Nexus 3000, 5000, 7000, 9000
- Support: Interfaces, BGP, OSPF, EIGRP, VRF, QoS
- SNMP: v2c dan v3

#### Mikrotik
- RouterOS (all versions)
- Support: Interfaces, routing, wireless, queues
- SNMP: v2c dan v3
- Default community: "public"

#### Juniper
- MX Series (MX5, MX10, MX40, MX80, MX240, MX480, MX960)
- SRX Series (firewall/router)
- Support: Interfaces, BGP, OSPF, IS-IS, MPLS
- SNMP: v2c dan v3

#### Ubiquiti
- EdgeRouter (ER-X, ER-4, ER-6P, ER-8, ER-12)
- Support: Interfaces, routing, PPPoE
- SNMP: v2c dan v3

#### Lainnya
- HP/Aruba (MSR, HSR series)
- Huawei (NE series, AR series)
- TP-Link (TL-R series)
- D-Link (DI series)

### 3. Switch

#### Cisco
- **Catalyst**: 2960, 3560, 3750, 3850, 9200, 9300, 9500
- **Nexus**: 3000, 5000, 7000, 9000 series
- Support: Interfaces, VLANs, STP, port-channels, MAC table
- SNMP: v2c dan v3

#### Mikrotik
- CRS series (Cloud Router Switch)
- SwOS devices
- Support: Interfaces, VLANs, STP
- SNMP: v2c dan v3

#### HP/Aruba
- ProCurve (2530, 2540, 2920, 2930, 5400)
- Aruba CX (6000, 8000 series)
- Support: Interfaces, VLANs, STP, stacking
- SNMP: v2c dan v3

#### Dell
- PowerConnect (3000, 5000, 6000, 7000 series)
- Force10 (S-series, Z-series)
- Support: Interfaces, VLANs, LAG
- SNMP: v2c dan v3

#### Ubiquiti
- EdgeSwitch (ES-8, ES-16, ES-24, ES-48)
- UniFi Switch (US-8, US-16, US-24, US-48)
- Support: Interfaces, VLANs, PoE monitoring
- SNMP: v2c dan v3

#### Lainnya
- Juniper EX series
- TP-Link (T1600G, T2600G, T3700G)
- D-Link (DGS, DES series)
- Netgear (GS, XS series)

### 4. Wireless

#### Ubiquiti
- UniFi AP (UAP, UAP-AC, UAP-nanoHD, UAP-6)
- AirMax (NanoStation, LiteBeam, PowerBeam)
- Support: Signal strength, client count, throughput
- SNMP: v2c dan v3

#### Mikrotik
- Wireless routers (hAP, cAP, SXTsq)
- Support: Signal, noise, CCQ, client count
- SNMP: v2c dan v3

#### Cambium Networks
- ePMP (Force 180, 200, 300)
- PMP 450, cnPilot
- Support: Signal, modulation, throughput
- SNMP: v2c dan v3

#### Ruckus
- ZoneDirector controllers
- SmartZone controllers
- Standalone APs
- Support: AP status, client count, RF metrics
- SNMP: v2c dan v3

#### Aruba
- Instant APs
- Controller-based APs
- Support: AP status, client count, RF health
- SNMP: v2c dan v3

### 5. Server & Virtualization

#### Linux
- Ubuntu, Debian, CentOS, RHEL, Fedora
- Requirement: net-snmp package installed
- Support: CPU, memory, disk, network, processes
- SNMP: v2c dan v3

#### Windows
- Server 2012, 2016, 2019, 2022
- Requirement: SNMP service enabled
- Support: CPU, memory, disk, network, services
- SNMP: v2c dan v3

#### VMware
- ESXi 6.x, 7.x, 8.x
- vCenter Server
- Support: Host resources, VM count, datastore
- SNMP: v2c dan v3

#### Proxmox
- Proxmox VE 6.x, 7.x, 8.x
- Support: Host resources, VM/CT count, storage
- SNMP: v2c dan v3

#### BSD & Firewall
- FreeBSD, pfSense, OPNsense
- Support: Interfaces, firewall states, resources
- SNMP: v2c dan v3

### 6. Storage

#### Network Attached Storage
- Synology DSM
- QNAP QTS
- TrueNAS (FreeNAS)
- Support: Disk status, RAID, temperature, capacity
- SNMP: v2c dan v3

#### Enterprise Storage
- NetApp (ONTAP)
- EMC (VNX, Unity)
- Dell Compellent
- Support: Volume status, performance, capacity
- SNMP: v2c dan v3

### 7. Power & Environmental

#### UPS (Uninterruptible Power Supply)
- APC (Smart-UPS, Back-UPS)
- Eaton (5P, 9PX)
- CyberPower
- Support: Battery status, load, runtime, voltage
- SNMP: v2c dan v3

#### PDU (Power Distribution Unit)
- APC (Rack PDU)
- Raritan
- ServerTech
- Support: Outlet status, current, power consumption
- SNMP: v2c dan v3

#### Environmental Sensors
- Temperature/Humidity sensors
- Smoke detectors
- Water leak detectors
- Support: Sensor readings, thresholds, alerts
- SNMP: v2c dan v3

### 8. Other Devices

#### IP Cameras
- Axis Communications
- Hikvision
- Dahua
- Support: Status, recording, motion detection
- SNMP: v2c (mostly)

#### Printers
- HP LaserJet, OfficeJet
- Canon imageRUNNER
- Xerox WorkCentre
- Support: Status, toner levels, page count
- SNMP: v2c dan v3

## Cara Menambahkan Device

Gunakan script `add-device.sh` yang sama untuk semua jenis perangkat:

```bash
# Generic syntax
./scripts/add-device.sh -h <hostname> -v <version> -c <community>

# Contoh berbagai perangkat
./scripts/add-device.sh -h 192.168.1.1 -v v2c -c public      # ZTE OLT
./scripts/add-device.sh -h 192.168.1.254 -v v2c -c public    # Mikrotik Router
./scripts/add-device.sh -h 10.0.0.10 -v v2c -c mycommunity   # Cisco Switch
./scripts/add-device.sh -h 192.168.1.100 -v v2c -c public    # Linux Server
./scripts/add-device.sh -h 192.168.1.50 -v v2c -c public     # UniFi AP
```

LibreNMS akan otomatis:
1. Detect jenis perangkat
2. Apply polling modules yang sesuai
3. Discover interfaces dan sensors
4. Mulai collecting metrics

## Verifikasi Device Support

Untuk mengecek apakah device Anda didukung:

1. **Cek SNMP di device**: Pastikan SNMP enabled dan accessible
2. **Test SNMP connectivity**:
   ```bash
   docker exec librenms snmpwalk -v2c -c public <device-ip> system
   ```
3. **Cek LibreNMS device list**: https://docs.librenms.org/Support/Device-Notes/
4. **Add device**: Jika SNMP works, LibreNMS kemungkinan besar akan support

## Tips untuk Device yang Tidak Umum

Jika device Anda tidak ada di list atau kurang umum:

1. **Pastikan SNMP enabled** - Ini requirement utama
2. **Gunakan SNMP v2c dulu** - Lebih mudah untuk testing
3. **Add device** - LibreNMS akan detect basic info (interfaces, CPU, memory)
4. **Check discovery log** - Lihat apa yang berhasil di-discover
5. **Custom polling** - Bisa ditambahkan jika perlu fitur spesifik

## Dokumentasi Lengkap

Untuk panduan lengkap menambahkan device, lihat:
- [SNMP Device Management Guide](SNMP_DEVICE_MANAGEMENT.md)

Untuk informasi device-specific, lihat:
- [LibreNMS Device Notes](https://docs.librenms.org/Support/Device-Notes/)

## Kesimpulan

Sistem ini **UNIVERSAL** dan tidak terbatas pada OLT saja. Selama device support SNMP, Anda bisa memonitornya dengan LibreNMS. Script `add-device.sh` dirancang untuk bekerja dengan semua jenis perangkat jaringan.

