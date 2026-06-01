# Abgabe — Vernetzte IoT Systeme (Variante 1)

> Gliederungshilfe für die Screenshots. Die FINALE Word/PDF-Abgabe enthält **nur Screenshots** (kein Text).
> Nutze diese Überschriften als Reihenfolge; ersetze jede „[Screenshot …]"-Zeile durch dein Bild.

Name: __________   Datum: __________   SSID-Nr (XX): ______

## 1. EDGE-WLAN „EDGE-IOT-XX" sichtbar
[Screenshot: WLAN-Liste mit EDGE-IOT-XX  /  `systemctl status hostapd`]

## 2. ESP32 erhält DHCP aus 192.168.166.0/24
[Screenshot: `cat /var/lib/misc/dnsmasq.leases` am EDGE]

## 3. SERVER-WLAN „SERVER-IOT-XX" sichtbar
[Screenshot: WLAN-Liste  /  `systemctl status hostapd` am SERVER]

## 4. EDGE erhält DHCP aus 192.168.176.0/24
[Screenshot: `ip -4 addr show wlan0` am EDGE]

## 5. EDGE kann 192.168.176.1 anpingen
[Screenshot: `ping -c4 192.168.176.1`]

## 6. Mosquitto lauscht auf Port 1883
[Screenshot: `sudo ss -tulpn | grep 1883` am SERVER]

## 7. ESP32 publiziert unter sensor/#
[Screenshot: `mosquitto_sub -h localhost -t 'sensor/#' -v`]

## 8. Prometheus erreichbar (http://192.168.176.1:9090)
[Screenshot: Prometheus-UI im Browser]

## 9. Grafana nutzt Prometheus als Datenquelle
[Screenshot: Grafana „Save & test"  /  Panel mit bme280-Metrik]

## 10. tshark zeigt MQTT-/DHCP-Verkehr
[Screenshot a: EDGE `sudo tshark -i uap0 -Y mqtt`]
[Screenshot b: SERVER `sudo tshark -i wlan0 -f "tcp port 1883"`]
