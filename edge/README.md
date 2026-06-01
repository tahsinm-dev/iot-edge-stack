# EDGE node (Raspberry Pi + USB Wi-Fi adapter)

The edge gateway. It hosts the sensor-network access point on the **on-board** radio
and connects upstream to the backbone on the **USB** radio, routing between the two
with NAT. Using one radio per role keeps the setup reliable (see
[`../docs/architecture.md`](../docs/architecture.md)).

> Apply with the [Ansible playbook](../ansible); the steps below document what it does.

## Role

```
wlan0 (on-board)  ──  AP "EDGE-IOT-XX"      ──  192.168.166.1/24   (sensor net)
wlan1 (USB)       ──  STA "SERVER-IOT-XX"   ──  DHCP from server    (backbone)
NAT               ──  192.168.166.0/24  ->  wlan1 (MASQUERADE)
```

## Files

| File                        | Target on the Pi                                  |
|-----------------------------|---------------------------------------------------|
| `hostapd.conf`              | `/etc/hostapd/hostapd.conf`                       |
| `dnsmasq.conf`              | `/etc/dnsmasq.conf`                               |
| `ap-ip.service`             | `/etc/systemd/system/ap-ip.service`               |
| `wpa_supplicant-wlan1.conf` | `/etc/wpa_supplicant/wpa_supplicant-wlan1.conf`   |
| `20-wlan1.network`          | `/etc/systemd/network/20-wlan1.network`           |
| `sysctl-ip-forward.conf`    | `/etc/sysctl.d/99-ip-forward.conf`                |
| `iptables-rules.v4`         | `/etc/iptables/rules.v4`                          |

## Manual deployment (summary)

```bash
sudo apt install -y hostapd dnsmasq wpasupplicant iptables-persistent
sudo systemctl unmask hostapd

# copy the files above, set DAEMON_CONF in /etc/default/hostapd,
# disable NetworkManager, then:
sudo sysctl --system
sudo systemctl enable --now ap-ip hostapd dnsmasq wpa_supplicant@wlan1 systemd-networkd netfilter-persistent
```

## Notes

- **Interface names:** the on-board radio is `wlan0`, the USB adapter `wlan1`. If the
  order is not stable on your hardware, pin them with a udev rule by MAC address.
- The AP (`wlan0`) and the uplink (`wlan1`) are independent radios, so they can use
  **different channels** and the uplink uses normal DHCP — none of the single-radio
  limitations apply.
- The uplink gets its address from **systemd-networkd**, not dhcpcd: dhcpcd's
  seccomp privilege separation is killed (SIGSYS) on Raspberry Pi OS Bookworm
  (armhf). networkd is built in and matches only `wlan1`, leaving the AP untouched.
