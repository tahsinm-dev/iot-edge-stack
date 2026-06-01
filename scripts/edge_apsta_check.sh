#!/usr/bin/env bash
# edge_apsta_check.sh
# Prüfskript für den EDGE: AP+STA auf EINEM Funkchip
#   uap0 = Access Point (für die ESP32),  wlan0 = Client (STA) zum SERVER
#   dhcpcd-basiert, OHNE NetworkManager.
#
# AUF DEM EDGE-PI ausführen:   sudo bash edge_apsta_check.sh
# Dieses Skript ändert NICHTS, es prüft nur und gibt Hinweise.
# ---------------------------------------------------------------------------
# Werte an deinen Laborplan anpassen:
AP_IF="uap0"                 # virtuelles AP-Interface (für die ESP32)
STA_IF="wlan0"               # physisches Interface (Client zum SERVER)
AP_IP="192.168.166.1"        # EDGE-IP im Sensornetz (WLAN1)
AP_NET="192.168.166"         # /24-Praefix Sensornetz
SERVER_IP="192.168.176.1"    # SERVER-IP im Backbone (WLAN2)
STA_NET="192.168.176"        # /24-Praefix Backbone
SSID_STA="SERVER-IOT-XX"     # SSID des SERVERs (XX ersetzen!)
MQTT_PORT="1883"
# ---------------------------------------------------------------------------

pass=0; fail=0; warn=0
ok()   { printf '  [ OK ]  %s\n' "$1"; pass=$((pass+1)); }
no()   { printf '  [FAIL]  %s\n' "$1"; fail=$((fail+1)); }
wn()   { printf '  [WARN]  %s\n' "$1"; warn=$((warn+1)); }
info() { printf '  [INFO]  %s\n' "$1"; }
hint() { printf '          -> %s\n' "$1"; }
hdr()  { printf '\n=== %s ===\n' "$1"; }

if [ "$(id -u)" -ne 0 ]; then
  echo "Bitte mit sudo ausfuehren:  sudo bash $0"
  exit 1
fi

hdr "0) Netzwerk-Stack (dhcpcd statt NetworkManager)"
if systemctl is-active --quiet NetworkManager 2>/dev/null; then
  no "NetworkManager laeuft (soll AUS sein)"
  hint "sudo systemctl disable --now NetworkManager"
else
  ok "NetworkManager ist nicht aktiv"
fi
if systemctl is-active --quiet dhcpcd 2>/dev/null; then
  ok "dhcpcd ist aktiv"
else
  no "dhcpcd ist NICHT aktiv"
  hint "sudo apt install -y dhcpcd5 && sudo systemctl enable --now dhcpcd"
fi

hdr "1) Treiber: erlaubt der Chip AP+STA gleichzeitig?"
combos="$(iw list 2>/dev/null | sed -n '/valid interface combinations/,+8p')"
if echo "$combos" | grep -qi 'AP' && echo "$combos" | grep -qi 'managed'; then
  ok "iw list nennt eine Kombination mit AP UND managed"
  echo "$combos" | sed 's/^/          /'
  if echo "$combos" | grep -qiE '#channels:[[:space:]]*1'; then
    wn "Kombination erlaubt nur '#channels: 1' -> AP und STA MUESSEN denselben Kanal nutzen"
  fi
else
  no "Keine AP+managed-Kombination gefunden -> Adapter/Treiber kann AP+STA evtl. nicht"
  hint "Pruefen:  iw list | sed -n '/valid interface combinations/,+8p'"
fi

hdr "2) Virtuelles AP-Interface ($AP_IF)"
if ip link show "$AP_IF" >/dev/null 2>&1; then
  ok "$AP_IF existiert"
  if ip link show "$AP_IF" | grep -qw UP; then
    ok "$AP_IF ist UP"
  else
    no "$AP_IF ist nicht UP"
    hint "sudo ip link set $AP_IF up"
  fi
  iftype="$(iw dev "$AP_IF" info 2>/dev/null | awk '/type/{print $2}')"
  if [ "$iftype" = "AP" ]; then
    ok "$AP_IF Typ = AP"
  else
    wn "$AP_IF Typ = ${iftype:-unbekannt} (erwartet: AP)"
  fi
else
  no "$AP_IF existiert NICHT"
  hint "Einmalig:  sudo iw dev $STA_IF interface add $AP_IF type __ap && sudo ip link set $AP_IF up"
  hint "Dauerhaft: systemd-Unit uap0.service (siehe Anleitung, Schritt E2)"
fi

hdr "3) IP-Adressen"
if ip -4 addr show "$AP_IF" 2>/dev/null | grep -qw "$AP_IP"; then
  ok "$AP_IF hat $AP_IP"
else
  no "$AP_IF hat NICHT $AP_IP"
  hint "dhcpcd.conf:  interface $AP_IF / static ip_address=$AP_IP/24 / nohook wpa_supplicant"
fi
sta_ip="$(ip -4 addr show "$STA_IF" 2>/dev/null | awk '/inet /{print $2}' | cut -d/ -f1 | head -n1)"
if printf '%s' "$sta_ip" | grep -q "^${STA_NET}\."; then
  ok "$STA_IF hat eine DHCP-Adresse vom SERVER: $sta_ip"
else
  no "$STA_IF hat keine Adresse aus ${STA_NET}.0/24 (aktuell: ${sta_ip:-keine})"
  hint "Client-Verbindung (wpa_supplicant) und SERVER-DHCP pruefen"
fi

hdr "4) Funk-Status"
hostapd_state="$(systemctl is-active hostapd 2>/dev/null)"
if [ "$hostapd_state" = "active" ]; then
  ok "hostapd ist aktiv"
else
  no "hostapd ist '$hostapd_state'"
  hint "sudo journalctl -u hostapd -n 30 --no-pager   (typisch: 'could not configure driver mode' -> uap0 nicht vor hostapd da)"
fi
link="$(iw dev "$STA_IF" link 2>/dev/null)"
if printf '%s' "$link" | grep -qi 'Connected to'; then
  cur_ssid="$(printf '%s\n' "$link" | awk -F'SSID: ' '/SSID/{print $2}')"
  ok "$STA_IF ist verbunden (SSID: ${cur_ssid:-?})"
else
  no "$STA_IF ist mit keinem WLAN verbunden"
  hint "wpa_supplicant.conf (SSID=$SSID_STA) und SERVER-AP pruefen"
fi

hdr "5) KRITISCH: AP und STA auf demselben Kanal?"
freq_ap="$(iw dev "$AP_IF" info 2>/dev/null | grep -oE '[0-9]{4} MHz' | grep -oE '^[0-9]{4}' | head -n1)"
freq_sta="$(iw dev "$STA_IF" link 2>/dev/null | awk '/freq/{print $2}')"
if [ -n "$freq_ap" ] && [ -n "$freq_sta" ]; then
  if [ "$freq_ap" = "$freq_sta" ]; then
    ok "AP ($freq_ap MHz) und STA ($freq_sta MHz) auf derselben Frequenz"
  else
    no "AP=$freq_ap MHz  !=  STA=$freq_sta MHz  -> Ein-Funkchip-Konflikt!"
    hint "hostapd 'channel' MUSS dem SERVER-Kanal entsprechen (Anleitung: 11)"
  fi
else
  wn "Frequenz nicht ermittelbar (AP='${freq_ap:-?}', STA='${freq_sta:-?}') - laeuft hostapd & ist die STA verbunden?"
fi

hdr "6) Routing / NAT (uap0 -> wlan0)"
if [ "$(cat /proc/sys/net/ipv4/ip_forward 2>/dev/null)" = "1" ]; then
  ok "IP-Forwarding aktiv"
else
  no "IP-Forwarding AUS"
  hint "net.ipv4.ip_forward=1 in /etc/sysctl.conf + sudo sysctl -p"
fi
if iptables -t nat -C POSTROUTING -o "$STA_IF" -j MASQUERADE 2>/dev/null; then
  ok "NAT MASQUERADE ueber $STA_IF vorhanden"
else
  no "NAT-Regel (MASQUERADE) fehlt"
  hint "sudo iptables -t nat -A POSTROUTING -o $STA_IF -j MASQUERADE"
fi
if iptables -C FORWARD -i "$AP_IF" -o "$STA_IF" -j ACCEPT 2>/dev/null; then
  ok "FORWARD $AP_IF -> $STA_IF vorhanden"
else
  wn "FORWARD $AP_IF -> $STA_IF fehlt"
  hint "sudo iptables -A FORWARD -i $AP_IF -o $STA_IF -j ACCEPT"
fi

hdr "7) SERVER erreichbar?"
if ping -c2 -W2 "$SERVER_IP" >/dev/null 2>&1; then
  ok "SERVER $SERVER_IP antwortet auf ping"
else
  no "SERVER $SERVER_IP nicht erreichbar"
  hint "WLAN2/STA, SERVER-AP und SERVER-IP pruefen"
fi
if command -v nc >/dev/null 2>&1; then
  if nc -z -w3 "$SERVER_IP" "$MQTT_PORT" 2>/dev/null; then
    ok "MQTT-Port $SERVER_IP:$MQTT_PORT offen"
  else
    no "MQTT-Port $MQTT_PORT zu / keine Antwort"
    hint "Mosquitto am SERVER pruefen (listener 1883)"
  fi
else
  wn "nc nicht installiert -> Portcheck uebersprungen (sudo apt install -y netcat-openbsd)"
fi

hdr "8) DHCP fuer die ESP32 (dnsmasq auf $AP_IF)"
if systemctl is-active --quiet dnsmasq 2>/dev/null; then
  ok "dnsmasq aktiv"
else
  no "dnsmasq nicht aktiv"
  hint "sudo journalctl -u dnsmasq -n 30 --no-pager   (typisch: 'unknown interface uap0' -> Reihenfolge / bind-dynamic)"
fi
leases="/var/lib/misc/dnsmasq.leases"
if [ -s "$leases" ]; then
  n="$(grep -c "${AP_NET}\." "$leases" 2>/dev/null)"
  ok "DHCP-Leases vorhanden: ${n:-0} Geraet(e) im Sensornetz"
  grep "${AP_NET}\." "$leases" 2>/dev/null | awk '{printf "          %s  %s\n",$3,$4}'
else
  wn "Noch keine DHCP-Leases (noch kein ESP32 verbunden?)"
fi
stations="$(iw dev "$AP_IF" station dump 2>/dev/null | grep -c Station)"
info "Am AP ($AP_IF) assoziierte Clients: ${stations:-0}"

hdr "Zusammenfassung"
printf '  OK: %s   WARN: %s   FAIL: %s\n' "$pass" "$warn" "$fail"
if [ "$fail" -eq 0 ]; then
  echo "  -> Alle Pflichtpunkte bestanden: AP+STA auf EINEM Funkchip laeuft."
else
  echo "  -> Es gibt FAILs. Obige Hinweise abarbeiten und erneut pruefen."
fi
exit 0
