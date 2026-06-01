---
marp: true
theme: default
paginate: true
header: "IoT Edge Stack"
---

<!--
Slide deck for the IoT Edge Stack project.
Render to PDF or PowerPoint with Marp CLI:
  npx @marp-team/marp-cli docs/slides.md --pdf
  npx @marp-team/marp-cli docs/slides.md --pptx
-->

# IoT Edge Stack

### End-to-end sensor telemetry on Raspberry Pi

ESP32 · MQTT · Prometheus · Grafana · Docker · Ansible

---

## The problem

- Collect environmental data (temperature, humidity, pressure) from distributed
  **ESP32 sensor nodes**.
- Keep the sensors on an **isolated network**, separate from the backbone.
- Deliver the data reliably to a **central monitoring backend**.
- Make the whole setup **reproducible and automatable**.

---

## Architecture

```
 ESP32 + BME280
      │  Wi-Fi (sensor net 192.168.166.0/24)
      ▼
 EDGE  Raspberry Pi      wlan0 = access point
      │                  wlan1 = uplink (USB)  + NAT / IP forwarding
      │  Wi-Fi (backbone 192.168.176.0/24)
      ▼
 SERVER  Raspberry Pi    Mosquitto · MQTT exporter · Prometheus
      │
      ▼
 Grafana  (laptop / Docker)
```

---

## Design decision: one radio per role

- The edge node must be an **access point _and_ an upstream client** at once.
- A single on-board Wi-Fi chip allows this only on **one shared channel** and was
  **unreliable for concurrent data traffic**.
- **Solution:** a second (USB) Wi-Fi adapter — **AP on-board, uplink on USB**.
- Result: independent channels, normal DHCP, standard tooling, reliable.

> Engineering trade-off documented as an architecture decision in the repo.

---

## Observability pipeline

```
MQTT  →  Mosquitto  →  MQTT exporter  →  Prometheus  →  Grafana
```

- **Custom Python exporter** turns sensor JSON into Prometheus metrics.
- **Alert rules**: sensor offline, exporter down, implausible readings.
- **Grafana dashboard provisioned as code** — no manual clicking.

---

## Results

![w:900](images/grafana-dashboard.png)

*Live dashboard: temperature, humidity, pressure and Wi-Fi signal for two nodes.*

---

## Infrastructure as code

- **Docker Compose** — the full backend (broker, exporter, Prometheus, Grafana)
  runs anywhere with one command.
- **Ansible** — idempotent provisioning of both Raspberry Pis.
- **GitHub Actions CI** — lints configs, validates the stack and **compiles the
  ESP32 firmware** on every push.

---

## Tech stack

| Layer       | Technology                                        |
|-------------|---------------------------------------------------|
| Embedded    | ESP32, BME280, Arduino/C++                         |
| Networking  | hostapd, wpa_supplicant, dnsmasq, iptables/NAT     |
| Messaging   | MQTT (Mosquitto)                                   |
| Monitoring  | Prometheus, Grafana                               |
| Automation  | Docker, Ansible, GitHub Actions                   |

---

## Summary

- A complete, **full-stack IoT pipeline** — from sensor firmware to dashboards.
- Runs on **real hardware** _and_ as a **containerised** backend.
- **Reproducible, documented and security-aware** (auth, no secrets in git).

**Thank you.**
