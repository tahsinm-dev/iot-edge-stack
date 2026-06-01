# Deploy-Map: welche Datei wohin auf den Pis

**Platzhalter zuerst ersetzen** (nur beim Schreiben auf den Pi, NICHT in diese Repo-Dateien zurückschreiben):
- `EDGE-IOT-XX` / `SERVER-IOT-XX` → echte SSID (Nummer aus Moodle `Labor_IP_Teilnehmer.xlsx`)
- `__WPA_EDGE__` / `__WPA_SERVER__` → echte Passphrasen aus `../secrets/credentials.md`

**Reihenfolge:** zuerst **SERVER** komplett, dann **EDGE**.
⚠️ Sobald ein Pi zum Access Point wird, bricht die SSH-Verbindung über das alte WLAN ab — danach über die neue IP / das neue WLAN weiterarbeiten.

---

## SERVER (serverpi)

**Pakete:**
```
sudo apt update
sudo apt install -y hostapd dnsmasq mosquitto mosquitto-clients prometheus tshark python3-venv python3-pip
sudo systemctl unmask hostapd
```

**Dateien:**
| Quelle (Repo) | Ziel auf dem Pi |
|---|---|
| `configs/server/dhcpcd-wlan0.conf` | an `/etc/dhcpcd.conf` **anhängen** |
| `configs/server/hostapd.conf` | `/etc/hostapd/hostapd.conf` |
| `configs/server/dnsmasq.conf` | `/etc/dnsmasq.conf` (vorher: `sudo mv /etc/dnsmasq.conf /etc/dnsmasq.conf.backup`) |
| `configs/server/mosquitto-lab.conf` | `/etc/mosquitto/conf.d/lab.conf` |
| `configs/server/prometheus.yml` | `/etc/prometheus/prometheus.yml` |
| `exporter/mqtt_exporter.py` | `~/mqtt_exporter.py` |

**`/etc/default/hostapd`** — diese Zeile setzen:
```
DAEMON_CONF="/etc/hostapd/hostapd.conf"
```

**Exporter (venv):**
```
python3 -m venv ~/mqtt_exporter_venv
~/mqtt_exporter_venv/bin/pip install paho-mqtt prometheus-client
# Test-Start:  ~/mqtt_exporter_venv/bin/python ~/mqtt_exporter.py
# Optional als systemd-Dienst einrichten, damit er Neustarts überlebt.
```

**Dienste:**
```
sudo systemctl enable hostapd dnsmasq mosquitto prometheus
sudo systemctl restart hostapd dnsmasq mosquitto prometheus
```

**Test (auf dem SERVER):** `sudo bash server_check.sh`

---

## EDGE (edgepi) — Single-Radio AP + STA

**Pakete:**
```
sudo apt update
sudo apt install -y hostapd dnsmasq tshark iw iptables-persistent
sudo systemctl unmask hostapd
```

**Dateien:**
| Quelle (Repo) | Ziel auf dem Pi |
|---|---|
| `configs/edge/uap0.service` | `/etc/systemd/system/uap0.service` |
| `configs/edge/dhcpcd-uap0.conf` | an `/etc/dhcpcd.conf` **anhängen** |
| `configs/edge/hostapd.conf` | `/etc/hostapd/hostapd.conf` |
| `configs/edge/dnsmasq.conf` | `/etc/dnsmasq.conf` (vorher Backup wie oben) |
| `configs/edge/wpa_supplicant.conf` | `/etc/wpa_supplicant/wpa_supplicant.conf` |

**`/etc/default/hostapd`:**
```
DAEMON_CONF="/etc/hostapd/hostapd.conf"
```

**IP-Forwarding** — `/etc/sysctl.d/99-ipforward.conf`:
```
net.ipv4.ip_forward=1
```
danach: `sudo sysctl --system`

**NAT (uap0 → wlan0):**
```
sudo iptables -t nat -A POSTROUTING -o wlan0 -j MASQUERADE
sudo iptables -A FORWARD -i uap0 -o wlan0 -j ACCEPT
sudo iptables -A FORWARD -i wlan0 -o uap0 -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo netfilter-persistent save
```

**Reihenfolge-Drop-ins (uap0 vor hostapd/dnsmasq):**
```
sudo mkdir -p /etc/systemd/system/hostapd.service.d /etc/systemd/system/dnsmasq.service.d
printf '[Unit]\nAfter=uap0.service\nRequires=uap0.service\n' | sudo tee /etc/systemd/system/hostapd.service.d/after-uap0.conf
printf '[Unit]\nAfter=uap0.service\n' | sudo tee /etc/systemd/system/dnsmasq.service.d/after-uap0.conf
```

**Dienste:**
```
sudo systemctl daemon-reload
sudo systemctl enable uap0 hostapd dnsmasq
sudo reboot
```

**Test (nach Reboot, auf dem EDGE):** `sudo bash edge_apsta_check.sh`
