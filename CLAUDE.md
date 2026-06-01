# CLAUDE.md — Steuerdatei für Claude Code

> Diese Datei liest Claude Code zu Beginn **jeder** Session automatisch ein. Sie ist die oberste Regel dieses Projekts. Antworte und dokumentiere auf **Deutsch**.

## Projekt
Aufbau, Inbetriebnahme und professionelle Dokumentation der Laborübung „Vernetzte IoT Systeme – Variante 1" (FH Technikum Wien), reproduzierbar als GitHub-Repo.
Datenfluss: **ESP32 + BME280 → (WLAN1) → EDGE (Raspberry Pi Zero 2 W) → (WLAN2) → SERVER (Raspberry Pi Zero 2 W: Mosquitto + Prometheus) → Grafana (Windows-Laptop)**.

## Deine Rolle & Autonomie
- Arbeite **so weit wie möglich autonom**: Erledige alles selbst, was per SSH/Shell und im Repo machbar ist (Konfigs schreiben, deployen, Dienste einrichten, testen, Doku/Git pflegen).
- **Halte nur dort an und frag den Menschen**, wo eine Aktion physisch/manuell ist oder echten Schaden anrichten könnte (Listen unten). Sag dann *präzise*, was zu tun ist, und warte auf Bestätigung.
- Führe **fortlaufend** ein professionelles Protokoll in `PROTOKOLL.md` (Regeln unten) — nicht erst am Ende.
- Plane größere Schritte kurz, bevor du sie ausführst.

## Annahmen zum Setup (zu Beginn bestätigen lassen)
- Claude Code läuft auf dem **Windows-Laptop** und hat **SSH-Zugang** zu `edgepi` und `serverpi`. **SSH-Benutzer: `tahsin`** → Verbindung immer als `ssh tahsin@edgepi.local` bzw. `ssh tahsin@serverpi.local` (oder `tahsin@<IP>`). Prüfe das als **allererste Aktion**: `ssh tahsin@edgepi.local 'hostname'`, `ssh tahsin@serverpi.local 'hostname'`. Fehlt der Zugang, erkläre dem Menschen, wie er ihn herstellt (Imager: OS + SSH + User + Hostname), und warte.
- **SSH-Key Pflicht für autonomes Arbeiten:** Mit reinem Passwort-SSH kannst du das Passwort nicht in den interaktiven Prompt eingeben. Der Mensch richtet daher **vorab einmalig** einen SSH-Key ein und kopiert ihn auf beide Pis (`ssh-keygen` + `ssh-copy-id tahsin@edgepi.local` / `…@serverpi.local`). Danach läuft SSH passwortlos. Prüfe, dass der key-basierte Login ohne Passwortabfrage klappt; wenn nicht, weise den Menschen darauf hin.
- **Echte Zugangsdaten** (Pi-Passwort, Erstzugang-WLAN) stehen in **`secrets/credentials.md`** — diese Datei ist per `.gitignore` ausgeschlossen und wird **NIE committet**. Lies sie bei Bedarf lokal, aber schreibe **keine** dieser Werte in versionierte Dateien.
- **Erstzugang-WLAN** (nur damit die Pis beim ersten Start erreichbar sind, nicht Teil der Lab-Topologie): SSID `Hotspot` (Passwort in `secrets/credentials.md`).
- Beide Pis: **Raspberry Pi OS (Legacy, 32-bit) Lite = Debian 12 „Bookworm"**.

## ⚠️ Kritische Randbedingungen (nicht verletzen)
1. **Kein NetworkManager:** Bookworm ignoriert sonst `/etc/dhcpcd.conf`. Wir nutzen **dhcpcd**. Erster Konfigschritt je Pi: `dhcpcd5` installieren/aktivieren, NetworkManager deaktivieren.
2. **Nur EIN Funkchip pro Pi (kein USB-WLAN-Adapter):** Der EDGE macht AP **und** STA auf einem Chip über ein virtuelles Interface **`uap0`** (hostapd auf `uap0`; `wlan0` = Client zum SERVER).
3. **Ein Funkchip = ein Kanal:** EDGE-AP und SERVER-AP MÜSSEN auf **Kanal 11** laufen. `uap0` muss **vor** hostapd/dnsmasq existieren (systemd: `uap0.service` mit `Before=hostapd.service dnsmasq.service`).
4. **Netzwerk-Umschaltung trennt SSH:** Sobald ein Pi seine WLAN-Rolle/IP ändert (EDGE wird AP+STA im 166/176-Netz), bricht die SSH-Verbindung ab. Vor solchen Schritten: dem Menschen ankündigen, über welche IP/welches WLAN danach weitergearbeitet wird; ggf. auf Reconnect warten.
5. **Single-Radio-AP+STA ist offiziell „unsupported"** und kann mit dem brcmfmac-Treiber instabil werden. Wenn es nach mehreren Versuchen nicht stabil läuft (Funk bricht ab, brcmfmac-Fehler im `dmesg`, Firmware-Crash beim ESP32-Connect): klar melden und einen zweiten USB-WLAN-Adapter als robuste Alternative empfehlen.
6. **Keine echten Passwörter ins Repo:** In versionierten Konfigs Platzhalter verwenden (`__WPA_EDGE__`, `__WPA_SERVER__`); echte Werte stehen **nur** in `secrets/credentials.md` (git-ignoriert). Vor jedem Commit prüfen, dass keine echten Zugangsdaten in getrackten Dateien stehen.

## Netzwerkplan (verbindliche Werte)
- WLAN1 Sensornetz (EDGE↔ESP32): **192.168.166.0/24**, EDGE/`uap0` = **192.168.166.1**, DHCP .100–.200, SSID **EDGE-IOT-XX**, Kanal 11.
- WLAN2 Backbone (EDGE↔SERVER): **192.168.176.0/24**, SERVER/`wlan0` = **192.168.176.1**, DHCP .100–.200, SSID **SERVER-IOT-XX**, Kanal 11.
- Mosquitto **192.168.176.1:1883**, Prometheus **192.168.176.1:9090**, Grafana-Datenquelle `http://192.168.176.1:9090`.
- **`XX`** in den SSIDs: aus `Labor_IP_Teilnehmer.xlsx` (Moodle) — beim Menschen erfragen, bevor SSIDs final geschrieben werden.

## Was du AUTOMATISCH machst (per SSH / im Repo)
- **System (beide Pis):** `apt update/full-upgrade`, Hostnamen, Grundwerkzeuge (net-tools, iw, wireless-tools, curl, nano), `rfkill unblock wlan`.
- **EDGE-Netz:** `uap0.service`, dhcpcd-Statik für `uap0` (192.168.166.1/24, `nohook wpa_supplicant`), hostapd auf `uap0` (`channel=11`, `country_code=AT`), dnsmasq (`bind-dynamic`, `no-dhcp-interface=wlan0`, Range .100–.200), `wlan0`-STA via Standard-`wpa_supplicant.conf`, IP-Forwarding, NAT (`-o wlan0`, FORWARD `uap0`↔`wlan0`), `iptables-persistent`, Service-Reihenfolge (`After=uap0.service`).
- **SERVER-Netz:** hostapd `wlan0` (SSID SERVER-IOT-XX, **Kanal 11**), dhcpcd-Statik (192.168.176.1/24), dnsmasq (Range .100–.200).
- **SERVER-Dienste:** Mosquitto (`listener 1883 0.0.0.0`, `allow_anonymous true`), Prometheus (`apt install prometheus` — in Bookworm/armhf verfügbar), Python-MQTT-Exporter (venv; **`mqtt.Client(mqtt.CallbackAPIVersion.VERSION1)`**; optional als systemd-Dienst), `prometheus.yml`-Scrape-Job (korrekte YAML-Einrückung).
- **Verifikation:** alle Prüfliste-Kommandos (unten) ausführen, Ergebnisse ins Protokoll schreiben.
- **Repo:** Struktur anlegen, Konfigs versionieren (mit Passwort-Platzhaltern), `README.md`/`PROTOKOLL.md` pflegen, kleinschrittige Commits.

## Was der MENSCH macht (anhalten & präzise anleiten)
- Pis mit **Raspberry Pi Imager** flashen (OS, SSH, User, Hostname `edgepi`/`serverpi`), verkabeln, Strom.
- **SSH-Zugang** bereitstellen/bestätigen.
- **BME280 verdrahten** (VIN→3V3, GND→GND, SDA→GPIO21, SCL→GPIO22), USB anstecken.
- **ESP32 flashen** in der **Arduino IDE (Windows)**: Boardpaket + Bibliotheken installieren, Sketch hochladen, seriellen Monitor öffnen. (Du lieferst den fertigen Sketch im Repo.)
- **Grafana + Wireshark** auf Windows installieren; Grafana-Datenquelle/Panel in der GUI einrichten.
- **WLAN beitreten** (Laptop/Handy) für Tests/Screenshots.
- **Screenshots** für die Abgabe-Datei machen.
- **Reconnect** nach Netzwerk-Umschaltschritten.

## Protokoll (`PROTOKOLL.md`) — fortlaufend führen
- Nach **jedem** sinnvollen Schritt einen Eintrag anhängen: Datum/Uhrzeit · Schritt/Ziel · durchgeführte Befehle/Konfig (Kurzfassung, Code-Blöcke erlaubt) · Ergebnis/Verifikation · Probleme & Lösung · Status (✅/⚠️/❌). Bei manuellen Schritten: „Aktion durch Mensch" + welcher Screenshot erstellt wurde.
- Ziel: ein **außenstehender Leser** versteht später lückenlos, *was* getan wurde und *warum*. Sachlich, professionell, reproduzierbar.
- **Wichtig:** `PROTOKOLL.md` ist Repo-Doku (Text/Code erlaubt). Die **Abgabe-Datei** ist etwas anderes (nur Screenshots, kein Text) — nicht verwechseln.

## Abgabe-Datei (Word/PDF) — Pflicht der Lehrveranstaltung
- Endprodukt: **Word/PDF mit ausschließlich Screenshots, KEIN Copy&Paste von Text**, in der Reihenfolge der Prüfliste.
- Du kannst sie nicht mit echten Screenshots füllen. Erinnere den Menschen an jedem überprüfbaren Schritt an den passenden Screenshot und lege optional eine leere Vorlage (`abgabe/Vorlage.md`) mit beschrifteten Platzhaltern an.

## Prüfliste / Inbetriebnahme (Punkt 10) — ausführen + protokollieren + je 1 Screenshot
1. EDGE-WLAN „EDGE-IOT-XX" sichtbar — WLAN-Liste / `systemctl status hostapd --no-pager`.
2. ESP32 bekommt DHCP aus 192.168.166.0/24 — `cat /var/lib/misc/dnsmasq.leases`.
3. SERVER-WLAN „SERVER-IOT-XX" sichtbar — WLAN-Liste / SERVER `systemctl status hostapd --no-pager`.
4. EDGE bekommt DHCP aus 192.168.176.0/24 — EDGE `ip -4 addr show wlan0`.
5. EDGE kann 192.168.176.1 anpingen — EDGE `ping -c4 192.168.176.1`.
6. Mosquitto lauscht auf 1883 — SERVER `sudo ss -tulpn | grep 1883`.
7. ESP32 publiziert unter sensor/# — SERVER `mosquitto_sub -h localhost -t 'sensor/#' -v`.
8. Prometheus unter http://192.168.176.1:9090 erreichbar — Browser am Laptop.
9. Grafana nutzt Prometheus als Datenquelle — „Save & test" / Panel mit `bme280_*`-Metrik.
10. tshark zeigt MQTT-/DHCP-Verkehr — EDGE `sudo tshark -i uap0 -Y mqtt` UND SERVER `sudo tshark -i wlan0 -f "tcp port 1883"` (DHCP: Filter `bootp`). → **2 Screenshots**.

## ESP32-Sketch (den du im Repo erzeugst)
- `mqtt_server="192.168.176.1"`, WLAN = EDGE-IOT-XX, Passwort = EDGE-Passphrase.
- **Beide Boards eindeutig:** Board 1 `esp32-bme280-01` / `sensor/esp32_01/bme280`, Board 2 `esp32-bme280-02` / `sensor/esp32_02/bme280`.
- BME280-Adresse 0x76 ODER 0x77 (je nach SDO-Pin) — Fallback einbauen/dokumentieren; sicherstellen, dass es ein echter BME280 (mit Feuchte) ist.

## Repo-Struktur (so anlegen/pflegen)
```
<repo>/
├── CLAUDE.md            # diese Datei
├── README.md
├── PROTOKOLL.md
├── .gitignore
├── .claude/settings.json
├── configs/edge/        # uap0.service, dhcpcd-Snippet, hostapd.conf, dnsmasq.conf, wpa_supplicant.conf, sysctl, iptables.rules
├── configs/server/      # dhcpcd-Snippet, hostapd.conf, dnsmasq.conf, mosquitto lab.conf, prometheus.yml
├── esp32/               # esp32_bme280_mqtt.ino
├── exporter/            # mqtt_exporter.py
├── scripts/             # edge_apsta_check.sh, deploy-Helfer
├── docs/                # architektur.png (vom Menschen), netzwerkplan.md
└── abgabe/              # Screenshot-Vorlage + (optional) fertige Abgabe
```

## Deployment / Platzhalter ersetzen
Die fertigen Konfigs liegen unter `configs/` (Deploy-Map mit Zielpfaden in `configs/README.md`). Beim Schreiben auf die Pis ersetzt du **erst dort** die Platzhalter: `EDGE-IOT-XX`/`SERVER-IOT-XX` → echte SSID (Nummer vom Menschen erfragen), `__WPA_EDGE__`/`__WPA_SERVER__` → echte Passphrasen aus `secrets/credentials.md`. Diese Werte **niemals** in die Repo-Dateien zurückschreiben.

## Git / GitHub
- Kleinschrittige Commits mit klaren Messages (z. B. „SERVER: hostapd+dnsmasq für WLAN2 (Kanal 11)").
- **Keine echten Secrets committen** (Platzhalter; `.gitignore` beachten). Vor jedem Commit gegenprüfen.
- GitHub-Repo via `gh repo create` anlegen und pushen **nur nach Bestätigung** des Menschen (Name + public/private klären).

## Offene Platzhalter — aktiv erfragen
SSID-Nummer **XX** · Plan A oder Plan B (MikroTik) · echte WLAN-Passwörter · Bestätigung 166=WLAN1 / 176=WLAN2 · GitHub-Repo-Name + public/private.

---
**Starte so:** (1) SSH-Zugang zu beiden Pis prüfen → (2) offene Platzhalter erfragen → (3) Repo-Grundgerüst + `PROTOKOLL.md` anlegen und ersten Commit machen → (4) mit dem SERVER beginnen. Halte an, sobald ein Schritt aus „Was der Mensch macht" nötig ist.
