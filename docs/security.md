# Security

The project is a lab setup, but it follows sensible baseline practices.

## MQTT authentication

The broker requires a username and password (`allow_anonymous false`). The
password file is generated from credentials in the environment and is never
committed. Clients (exporter, sensors) authenticate with the configured user.

## MQTT over TLS

The containerised broker exposes two listeners:

| Port   | Transport | Intended for                                  |
|--------|-----------|-----------------------------------------------|
| `1883` | plaintext | trusted internal services (Docker network)    |
| `8883` | **TLS**   | external clients / sensors                     |

A local CA and a server certificate are generated automatically on first start
(`monitoring/tls/gen-certs.sh`). Publishing over TLS:

```bash
mosquitto_pub -h <host> -p 8883 --cafile ca.crt -u iot -P '***' \
  -t sensor/esp32_01/bme280 -m '{"temp":23.5,"hum":45.2,"press":1013.2,"rssi":-57}'
```

The exporter and the ESP32 firmware can both use TLS:

- **Exporter** — set `MQTT_TLS=true` and `MQTT_CA_CERT=/path/to/ca.crt`.
- **ESP32** — use `WiFiClientSecure` with the CA certificate and port `8883`.

## Secrets handling

- No real credentials in version control. Wi-Fi passphrases and broker passwords
  are placeholders in the templates and are injected at deploy time
  (Docker `.env`, Ansible Vault, hardware `secrets/`).
- A `.gitignore` excludes generated secrets (`.env`, password files, TLS keys,
  `ansible/secrets.yml`).

## Container hardening

- The exporter image runs as a **non-root** user.
- Images are pinned to specific versions for reproducibility.
- Grafana sign-up and anonymous analytics are disabled.

## Network segmentation

The sensor network (`192.168.166.0/24`) is isolated behind the edge gateway and
reaches the backbone only through NAT, so sensor devices are not directly exposed
to the backbone or its services.
