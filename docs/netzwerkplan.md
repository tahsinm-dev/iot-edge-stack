# Netzwerkplan

| Netz | Bereich | Gerät / IP | SSID | Kanal |
|---|---|---|---|---|
| WLAN1 (Sensornetz, EDGE↔ESP32) | 192.168.166.0/24 | EDGE `uap0` = 192.168.166.1 · DHCP .100–.200 | EDGE-IOT-XX | 11 |
| WLAN2 (Backbone, EDGE↔SERVER) | 192.168.176.0/24 | SERVER `wlan0` = 192.168.176.1 · DHCP .100–.200 | SERVER-IOT-XX | 11 |
| Dienste | — | Mosquitto 192.168.176.1:1883 · Prometheus 192.168.176.1:9090 · Exporter :9100 | — | — |

EDGE-Interfaces (ein Funkchip): `uap0` = AP (für die ESP32), `wlan0` = Client (zum SERVER). Beide zwingend auf **Kanal 11**.
