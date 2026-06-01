#!/usr/bin/env bash
# server_check.sh — auf serverpi ausfuehren:  sudo bash server_check.sh
pass=0; fail=0
ok(){ printf '  [ OK ] %s\n' "$1"; pass=$((pass+1)); }
no(){ printf '  [FAIL] %s\n' "$1"; fail=$((fail+1)); }
for s in hostapd dnsmasq mosquitto prometheus; do
  systemctl is-active --quiet "$s" && ok "$s aktiv" || no "$s nicht aktiv"
done
ip -4 addr show wlan0 2>/dev/null | grep -qw 192.168.176.1 && ok "wlan0 = 192.168.176.1" || no "wlan0 hat nicht 192.168.176.1"
ss -tulpn 2>/dev/null | grep -q ':1883' && ok "Port 1883 (Mosquitto) offen" || no "Port 1883 zu"
ss -tulpn 2>/dev/null | grep -q ':9090' && ok "Port 9090 (Prometheus) offen" || no "Port 9090 zu"
ss -tulpn 2>/dev/null | grep -q ':9100' && ok "Port 9100 (Exporter) offen" || no "Port 9100 zu (laeuft der Exporter?)"
printf '  ---\n  OK:%s  FAIL:%s\n' "$pass" "$fail"
