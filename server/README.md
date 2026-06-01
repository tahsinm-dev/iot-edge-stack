# SERVER node (Raspberry Pi)

The backbone access point and monitoring host. It runs the Wi-Fi access point for
the backbone network and the native monitoring services (MQTT broker, exporter,
Prometheus). Grafana runs on the laptop or via the [containerised stack](../monitoring).

> The recommended way to apply this is the [Ansible playbook](../ansible); the steps
> below document what it does.

## Role

```
SERVER wlan0  ──  AP "SERVER-IOT-XX"  ──  192.168.176.1/24
services      ──  Mosquitto :1883 · MQTT exporter :9101 · Prometheus :9090
```

## Files

| File                  | Target on the Pi                          |
|-----------------------|-------------------------------------------|
| `hostapd.conf`        | `/etc/hostapd/hostapd.conf`               |
| `dnsmasq.conf`        | `/etc/dnsmasq.conf`                        |
| `ap-ip.service`       | `/etc/systemd/system/ap-ip.service`       |
| `mosquitto.conf`      | `/etc/mosquitto/conf.d/iot.conf`          |
| `prometheus.yml`      | `/etc/prometheus/prometheus.yml`          |
| `mqtt-exporter.service` | `/etc/systemd/system/mqtt-exporter.service` |
| `../monitoring/exporter/mqtt_exporter.py` | `/opt/mqtt-exporter/mqtt_exporter.py` |

## Manual deployment (summary)

```bash
sudo apt install -y hostapd dnsmasq mosquitto mosquitto-clients prometheus python3-venv
sudo systemctl unmask hostapd

# network + AP
#   - copy hostapd.conf, dnsmasq.conf, ap-ip.service
#   - set DAEMON_CONF="/etc/hostapd/hostapd.conf" in /etc/default/hostapd
#   - disable NetworkManager so it does not manage wlan0

# broker auth
sudo mosquitto_passwd -c /etc/mosquitto/passwd iot

# exporter
python3 -m venv /opt/mqtt-exporter/venv
/opt/mqtt-exporter/venv/bin/pip install paho-mqtt prometheus-client
echo 'MQTT_HOST=localhost\nMQTT_USER=iot\nMQTT_PASSWORD=...' | sudo tee /etc/mqtt-exporter.env

sudo systemctl enable --now ap-ip hostapd dnsmasq mosquitto prometheus mqtt-exporter
```

## Notes

- The static AP address is set by `ap-ip.service` rather than dhcpcd: on an
  access-point interface dhcpcd can race on "carrier" and leave `wlan0` without an
  address. The one-shot service assigns it deterministically after `hostapd`.
- `allow_anonymous false` requires the broker password. For a quick isolated lab
  demo it can be relaxed, but authentication is the default here.
