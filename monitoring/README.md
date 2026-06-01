# Containerised Monitoring Stack

The complete server-side backend of the project — MQTT broker, metrics
exporter, time-series database and dashboards — packaged as a single
`docker compose` stack. It lets you run and demo the data pipeline on any
Docker host **without the Raspberry Pi hardware**.

```
ESP32 / mosquitto_pub ──MQTT──▶ Mosquitto ──▶ MQTT exporter ──▶ Prometheus ──▶ Grafana
```

## Quick start

```bash
cd monitoring
cp .env.example .env          # adjust credentials
docker compose up -d --build
```

| Service    | URL                      | Credentials              |
|------------|--------------------------|--------------------------|
| Grafana    | http://localhost:3000    | from `.env` (admin/…)    |
| Prometheus | http://localhost:9090    | —                        |
| MQTT       | `localhost:1883`         | from `.env` (auth)       |

The Grafana dashboard **IoT Sensors – BME280** and the Prometheus data source
are provisioned automatically.

## Send demo data

```bash
docker compose exec mosquitto mosquitto_pub \
  -u "$MQTT_USER" -P "$MQTT_PASSWORD" \
  -t sensor/esp32_01/bme280 \
  -m '{"temp":23.5,"hum":45.2,"press":1013.2,"rssi":-57}'
```

Within ~15 s the values appear in Prometheus and on the Grafana dashboard.

## What this demonstrates

- **Infrastructure as code** — broker, database and dashboards defined in version control, reproducible with one command.
- **Provisioning as code** — Grafana data source and dashboard, Prometheus scrape config and alert rules are all declarative.
- **Security** — the broker requires authentication (`allow_anonymous false`); the exporter runs as a non-root container.
- **Observability** — custom Prometheus exporter, alert rules (sensor offline, exporter down, implausible readings).

## Layout

```
monitoring/
├── docker-compose.yml
├── .env.example
├── mosquitto/config/mosquitto.conf
├── exporter/            # custom MQTT→Prometheus exporter (Dockerfile + Python)
├── prometheus/          # prometheus.yml + alerts.yml
└── grafana/             # provisioning/ + dashboards/
```

> The same exporter code (`exporter/mqtt_exporter.py`) runs natively on the
> Raspberry Pi server in the hardware deployment.
