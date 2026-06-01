# Build & Commissioning Log

A chronological record of how the IoT Edge Stack was built and commissioned, so
the setup can be understood and reproduced. High-level architecture and the key
engineering decision are in [`docs/architecture.md`](docs/architecture.md).

## Project parameters

- **Goal:** end-to-end environmental telemetry from ESP32 sensors to Grafana.
- **Hardware:** 2× Raspberry Pi Zero 2 W, USB Wi-Fi adapter (edge uplink), 2× ESP32
  + BME280.
- **Networks:** sensor `192.168.166.0/24`, backbone `192.168.176.0/24`.
- **Backend services:** Mosquitto (MQTT), Prometheus, MQTT exporter, Grafana.

---

## Phase 1 — Backend & tooling (software)

| # | Step | Result |
|---|------|--------|
| 1 | Containerised backend (`monitoring/`): Mosquitto, MQTT exporter, Prometheus, Grafana via `docker compose`. | Stack starts with one command; data source and dashboard provisioned as code. |
| 2 | End-to-end verification of the container stack. | Published MQTT test data, confirmed metrics in the exporter and Prometheus, dashboard rendering in Grafana (see [`docs/images/grafana-dashboard.png`](docs/images/grafana-dashboard.png)). |
| 3 | MQTT authentication and **TLS** listener (`8883`). | Verified an encrypted publish is received and exported; plaintext on the TLS port is rejected. |
| 4 | ESP32 firmware (`firmware/`): BME280 → MQTT with Last-Will, RSSI metric and auto-reconnect. | Compiles in CI. |
| 5 | Hardware deployment configs (`server/`, `edge/`) for the dual-radio architecture. | Reviewed; deployed by Ansible. |
| 6 | Ansible provisioning (`ansible/`) and GitHub Actions CI (`.github/`). | Idempotent playbooks; CI lints configs, validates the stack and compiles the firmware. |

---

## Phase 2 — Hardware commissioning (runbook)

To be completed on the physical setup. Each step has a verification check.

1. **Flash both Raspberry Pis** (Raspberry Pi OS Lite) with SSH key access; attach
   the USB Wi-Fi adapter to the edge.
2. **Provision with Ansible:** `ansible-playbook site.yml --extra-vars @secrets.yml --ask-vault-pass`.
3. **SERVER access point** `SERVER-IOT-XX` visible — `systemctl status hostapd`.
4. **EDGE access point** `EDGE-IOT-XX` visible — `systemctl status hostapd`.
5. **EDGE uplink** associated and addressed on the backbone — `ip -4 addr show wlan1`.
6. **Routing:** a sensor-network client reaches the broker — `nc -z 192.168.176.1 1883`.
7. **ESP32** publishes — `mosquitto_sub -t 'sensor/#' -v` on the server.
8. **Prometheus** scraping the exporter — targets `up` at `http://192.168.176.1:9090`.
9. **Grafana** shows live `bme280_*` metrics from the real sensors.

> Commissioning screenshots will be added under `docs/images/` as each check passes.
