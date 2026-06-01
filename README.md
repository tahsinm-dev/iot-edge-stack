<!--
  TIPP: <PROJEKTNAME> oben durch deinen finalen Namen ersetzen (z. B. iot-edge-stack).
  Vorschläge: iot-edge-stack · esp32-mqtt-prometheus-grafana · sensormesh-pi
-->

# IoT-Edge-Stack — Vernetzte IoT-Systeme

**ESP32 + BME280 · Raspberry Pi Edge/Server · MQTT · Prometheus · Grafana**

Ende-zu-Ende-IoT-Monitoring auf zwei Raspberry Pi Zero 2 W: Umweltsensoren (Temperatur, Luftfeuchte, Luftdruck) auf ESP32 publizieren per MQTT über ein Edge-Gateway an einen zentralen Broker; Prometheus sammelt die Metriken, Grafana visualisiert sie. Aufgebaut im Rahmen der Lehrveranstaltung *Vernetzte IoT Systeme* (FH Technikum Wien), **Variante 1**.

> Besonderheit dieses Aufbaus: Der EDGE arbeitet **ohne zweiten WLAN-Adapter** — Access Point *und* Client laufen über ein virtuelles Interface (`uap0`) auf einem einzigen Funkchip, dhcpcd-basiert (ohne NetworkManager). Siehe Sicherheitshinweis.

## Architektur
```
[ESP32 + BME280] --WLAN1--> [EDGE  Pi Zero 2 W] --WLAN2--> [SERVER  Pi Zero 2 W] --(HTTP)--> [Laptop]
   MQTT-Publisher            AP(uap0)+STA(wlan0)            AP(wlan0)                          Grafana
                             DHCP, NAT/Routing, tshark      Mosquitto, Prometheus, tshark      Wireshark
```
Datenfluss (Monitoring): ESP32 → MQTT → Mosquitto (SERVER) → MQTT-Exporter → Prometheus → Grafana.
*(Architekturbild unter `docs/architektur.png` einfügen.)*

## Hardware (BOM)
| Komponente | Anzahl | Rolle |
|---|---|---|
| Raspberry Pi Zero 2 W | 2 | EDGE (edgepi), SERVER (serverpi) |
| ESP32-DEV-30P | 2 | Sensor-Nodes / MQTT-Publisher |
| BME280 (I2C) | 2 | Temperatur, Luftfeuchte, Luftdruck |
| microSD | 2 | OS der Pis |
| USB-Hub mit Netzteil, Kabel | — | Strom/Verkabelung |
| Windows-11-Laptop | 1 | Grafana, Wireshark, Claude Code, SSH |

## Software-Stack
Raspberry Pi OS Legacy (Debian 12 „Bookworm", 32-bit) · dhcpcd · hostapd · dnsmasq · wpa_supplicant · iptables · Mosquitto (MQTT) · Prometheus · paho-mqtt + prometheus-client (Exporter) · Grafana · Wireshark/tshark · Arduino IDE (ESP32, Adafruit BME280 / Unified Sensor / PubSubClient).

## Netzwerkplan
| Netz | Bereich | Gerät / IP | SSID | Kanal |
|---|---|---|---|---|
| WLAN1 (Sensornetz) | 192.168.166.0/24 | EDGE `uap0` = 192.168.166.1, DHCP .100–.200 | EDGE-IOT-XX | 11 |
| WLAN2 (Backbone) | 192.168.176.0/24 | SERVER `wlan0` = 192.168.176.1, DHCP .100–.200 | SERVER-IOT-XX | 11 |
| Dienste | — | Mosquitto :1883, Prometheus :9090 (beide auf 192.168.176.1) | — | — |

> `XX` = persönliche Labornummer (Moodle). In versionierten Konfigs stehen **Platzhalter** statt echter Passwörter.

## Voraussetzungen
- Zwei mit Raspberry Pi OS Legacy Lite geflashte Pi Zero 2 W (SSH + User gesetzt), erreichbar als `edgepi`/`serverpi`.
- Windows-Laptop mit SSH-Zugang zu beiden Pis, Arduino IDE, Grafana, Wireshark.
- Optional: GitHub CLI (`gh`) zum Veröffentlichen.

## Aufbau / Reproduktion
Der Aufbau wird (semi-)automatisch mit **Claude Code** durchgeführt; die Steuerdatei `CLAUDE.md` enthält den vollständigen Ablauf, alle verbindlichen Parameter und die Rollenverteilung Mensch/Agent. Der konkrete Verlauf jedes Aufbaus ist in `PROTOKOLL.md` dokumentiert. Reihenfolge in Kurzform:
1. Beide Pis: System aktualisieren, Grundwerkzeuge, **dhcpcd statt NetworkManager**.
2. SERVER: AP (Kanal 11), DHCP, Mosquitto, Prometheus, MQTT-Exporter.
3. EDGE: `uap0`-AP (Kanal 11) + `wlan0`-Client zum SERVER, DHCP, IP-Forwarding, NAT.
4. ESP32: Sketch mit BME280 + MQTT (pro Board eindeutige Client-ID/Topic) flashen.
5. Grafana am Laptop an Prometheus anbinden.
6. Prüfliste/Inbetriebnahme abarbeiten (siehe unten).

## Repo-Struktur
```
.
├── CLAUDE.md            # Steuerdatei für Claude Code
├── README.md
├── PROTOKOLL.md         # fortlaufendes Projektprotokoll
├── .claude/settings.json
├── configs/edge/        # uap0.service, dhcpcd, hostapd, dnsmasq, wpa_supplicant, sysctl, iptables
├── configs/server/      # dhcpcd, hostapd, dnsmasq, mosquitto, prometheus.yml
├── esp32/               # esp32_bme280_mqtt.ino
├── exporter/            # mqtt_exporter.py (MQTT → Prometheus)
├── scripts/             # edge_apsta_check.sh, Deploy-Helfer
├── docs/                # architektur.png, netzwerkplan.md
└── abgabe/              # Screenshot-Vorlage
```

## Verifikation / Inbetriebnahme (Prüfliste)
- [ ] EDGE-WLAN `EDGE-IOT-XX` sichtbar
- [ ] ESP32 erhält DHCP aus `192.168.166.0/24`
- [ ] SERVER-WLAN `SERVER-IOT-XX` sichtbar
- [ ] EDGE erhält DHCP aus `192.168.176.0/24`
- [ ] EDGE kann `192.168.176.1` anpingen
- [ ] Mosquitto lauscht auf Port `1883`
- [ ] ESP32 publiziert unter `sensor/#`
- [ ] Prometheus erreichbar unter `http://192.168.176.1:9090`
- [ ] Grafana nutzt Prometheus als Datenquelle
- [ ] tshark zeigt MQTT- bzw. DHCP-Verkehr (EDGE + SERVER)

## Sicherheitshinweis
- **Single-Radio-AP+STA** (AP und Client auf einem Funkchip) ist offiziell **nicht unterstützt** und kann mit dem brcmfmac-Treiber instabil sein. Funktioniert es nicht zuverlässig, ist ein zweiter USB-WLAN-Adapter am EDGE die robuste Lösung.
- `allow_anonymous true` bei Mosquitto ist **nur für ein isoliertes Labor** gedacht — nicht für produktive Netze.
- Dieses Repo enthält **keine echten Zugangsdaten**; WLAN-Passphrasen stehen als Platzhalter in den Konfigs.

## Lizenz & Kontext
Lehrprojekt FH Technikum Wien, *Vernetzte IoT Systeme* (Variante 1). Lizenz: `<z. B. MIT>` — `LICENSE`-Datei ergänzen. Autor: `<Name>`.
