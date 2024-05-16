# VT-collab
A collection of tools for testing layers 2 and 3 with pSSID.

## Setup
- [Download][ubuntu] and install the Ubuntu 22.04 Raspberry Pi Generic
  (64-bit ARM) preinstalled server image
- Disable problematic services:
  ```bash
  systemctl --now disable \
    wpa_supplicant \
    unattended-upgrades \
    # systemd-networkd \
    # networkd-dispatcher
  ```
- Install additional dependencies: `apt install jq dhcpcd5`

## `pssid-80211`

This script handles the Wi-Fi connection.

This script must be run as root.

### Connect

Given a [configuration file](#wpa_supplicant-configuration-file) and interface,
it will connect to the Wi-Fi network and print some metrics to `stdout` in json
format.

The path `.wpa_log` in the json contains the whole `wpa_supplicant` log,
compressed with zstd and encoded in base64.

```bash
pssid-80211 -c wpa_supplicant.conf -i wlan0 > 80211.json
```

80211.json (pretty printed):
```json
{
  "80211_status": 0,
  "scan": {
    "status_code": 0,
    "status_string": "success",
    "scan_count": 1,
    "durations": [
      2.375121
    ]
  },
  "sme_auth": {
    "status_code": 0,
    "status_string": "success",
    "scan_count": 1,
    "durations": [
      0.523905
    ]
  },
  "associate": {
    "status_code": 0,
    "status_string": "success",
    "scan_count": 1,
    "durations": [
      0.015842
    ]
  },
  "wpa": {
    "status_code": 0,
    "status_string": "success",
    "scan_count": 1,
    "durations": [
      0.054491
    ]
  },
  "wpa_log": "KLUv/aTEfwEAfaQCSrvPmzHASMi2O..."
}
```

Reading the supplicant log:
```
$ jq -r .wpa_log 80211.json | base64 -d | zstd -d
1711650154.733833: wpa_supplicant v2.10
1711650154.733844: Successfully initialized wpa_supplicant
[...]
```

### Disconnect
To tear down the connection to cleanup and prepare for the next test, call the
command again with the `-d` flag.

Note that the configuration file and interface name are still required.

```bash
pssid-80211 -c wpa_supplicant.conf -i wlan0 -d
```

### wpa_supplicant configuration file
You must provide a file configuring wpa_supplicant for the wireless network you
want to test.
It can be named whatever you want, but the contents must conform to
[wpa_supplicant.conf][wpa_supplicant.conf].

Additionally, this **must** include a control interface directive.
Any suitable path will work, but the default is recommended.
```conf
ctrl_interface=/var/run/wpa_supplicant
```

Configuring more than one wireless network may produce unexpected/unpredictable
results.

[ubuntu]: https://cdimage.ubuntu.com/releases/22.04/release/ubuntu-22.04.4-preinstalled-server-arm64+raspi.img.xz
[wpa_supplicant.conf]: https://w1.fi/cgit/hostap/plain/wpa_supplicant/wpa_supplicant.conf
