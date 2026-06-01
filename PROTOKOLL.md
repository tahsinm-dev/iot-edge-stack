# PROTOKOLL — Vernetzte IoT-Systeme (Variante 1)

Fortlaufendes Aufbau- und Inbetriebnahme-Protokoll. Zweck: lückenlose, reproduzierbare Dokumentation, damit Außenstehende Aufbau und Entscheidungen nachvollziehen können.
**Hinweis:** Dieses Protokoll ist Repo-Doku (Text/Code erlaubt) und **nicht** die Abgabe-Datei (diese enthält ausschließlich Screenshots).

## Eckdaten
- **Projekt:** Vernetzte IoT Systeme – Variante 1 (FH Technikum Wien)
- **Autor:** `<Name>`
- **Zeitraum:** `<Start>` – `<Ende>`
- **Hardware:** 2× Raspberry Pi Zero 2 W (edgepi, serverpi), 2× ESP32-DEV-30P + BME280, Windows-11-Laptop
- **OS:** Raspberry Pi OS Legacy (Debian 12 „Bookworm", 32-bit)
- **Besonderheit:** Single-Radio-AP+STA am EDGE (`uap0`), dhcpcd statt NetworkManager
- **Netz:** WLAN1 192.168.166.0/24 (EDGE-IOT-XX, Kanal 11) · WLAN2 192.168.176.0/24 (SERVER-IOT-XX, Kanal 11) · Mosquitto/Prometheus auf 192.168.176.1

---

## Vorlage für Einträge (kopieren)
```
### [JJJJ-MM-TT HH:MM] <Schritt-Nr> — <Kurztitel>
- Ziel: <warum dieser Schritt>
- Gerät: <edgepi | serverpi | ESP32 | Laptop>
- Durchgeführt:
    <Befehle / Konfig-Auszug>
- Ergebnis / Verifikation: <Beobachtung, Output-Kurzfassung>
- Probleme & Lösung: <falls vorhanden>
- Manuelle Aktion (Mensch): <falls zutreffend>  | Screenshot: <Dateiname.png | –>
- Status: ✅ / ⚠️ / ❌
```

---

## Einträge

### [2026-__-__ __:__] 0 — Setup & SSH-Zugang (Beispiel)
- Ziel: Erreichbarkeit beider Pis sicherstellen, bevor konfiguriert wird.
- Gerät: Laptop → edgepi, serverpi
- Durchgeführt:
    ```
    ssh edgepi 'hostname'      # -> edgepi
    ssh serverpi 'hostname'    # -> serverpi
    ```
- Ergebnis / Verifikation: beide Hosts antworten, SSH ok.
- Probleme & Lösung: –
- Manuelle Aktion (Mensch): Pis geflasht (OS+SSH+User), verkabelt. | Screenshot: –
- Status: ✅

<!-- Ab hier hängt Claude Code weitere Einträge an (chronologisch). -->

---

## Inbetriebnahme / Prüfliste (Endergebnis)
| # | Check | Befehl/Aktion | Ergebnis | Screenshot | Status |
|---|---|---|---|---|---|
| 1 | EDGE-WLAN EDGE-IOT-XX sichtbar | WLAN-Liste / `systemctl status hostapd` |  |  |  |
| 2 | ESP32 DHCP aus 192.168.166.0/24 | `cat /var/lib/misc/dnsmasq.leases` |  |  |  |
| 3 | SERVER-WLAN SERVER-IOT-XX sichtbar | WLAN-Liste / `systemctl status hostapd` |  |  |  |
| 4 | EDGE DHCP aus 192.168.176.0/24 | `ip -4 addr show wlan0` |  |  |  |
| 5 | EDGE pingt 192.168.176.1 | `ping -c4 192.168.176.1` |  |  |  |
| 6 | Mosquitto auf 1883 | `sudo ss -tulpn \| grep 1883` |  |  |  |
| 7 | ESP32 publiziert unter sensor/# | `mosquitto_sub -h localhost -t 'sensor/#' -v` |  |  |  |
| 8 | Prometheus erreichbar :9090 | Browser `http://192.168.176.1:9090` |  |  |  |
| 9 | Grafana ↔ Prometheus | Datenquelle „Save & test" / Panel |  |  |  |
| 10 | tshark MQTT/DHCP | EDGE `tshark -i uap0 -Y mqtt`; SERVER `tshark -i wlan0 -f "tcp port 1883"` |  |  |  |

## Bekannte Abweichungen / Lessons Learned
- `<hier dokumentieren, z. B. Kanal-Mismatch, brcmfmac-Stabilität, BME280-Adresse 0x76/0x77>`
