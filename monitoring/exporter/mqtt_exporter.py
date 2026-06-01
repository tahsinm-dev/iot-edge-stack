#!/usr/bin/env python3
"""MQTT-to-Prometheus exporter for BME280 sensor nodes.

Subscribes to an MQTT topic, parses the JSON payloads published by the ESP32
nodes and exposes them as Prometheus metrics. All connection parameters are
read from environment variables, so the exact same code runs inside the Docker
stack and natively on the Raspberry Pi server.

Expected payload (topic ``sensor/<device>/bme280``)::

    {"temp": 23.5, "hum": 45.2, "press": 1013.2, "rssi": -57}
"""
from __future__ import annotations

import json
import logging
import os
import signal
import sys

import paho.mqtt.client as mqtt
from prometheus_client import Counter, Gauge, start_http_server

LOG = logging.getLogger("mqtt_exporter")

MQTT_HOST = os.getenv("MQTT_HOST", "localhost")
MQTT_PORT = int(os.getenv("MQTT_PORT", "1883"))
MQTT_USER = os.getenv("MQTT_USER") or None
MQTT_PASSWORD = os.getenv("MQTT_PASSWORD") or None
MQTT_TOPIC = os.getenv("MQTT_TOPIC", "sensor/#")
EXPORTER_PORT = int(os.getenv("EXPORTER_PORT", "9101"))

TEMPERATURE = Gauge("bme280_temperature_celsius", "Temperature in degrees Celsius", ["device"])
HUMIDITY = Gauge("bme280_humidity_percent", "Relative humidity in percent", ["device"])
PRESSURE = Gauge("bme280_pressure_hpa", "Barometric pressure in hPa", ["device"])
RSSI = Gauge("esp32_wifi_rssi_dbm", "ESP32 Wi-Fi signal strength in dBm", ["device"])
MESSAGES = Counter("mqtt_messages_total", "MQTT messages processed", ["device", "status"])

_FIELDS = {"temp": TEMPERATURE, "hum": HUMIDITY, "press": PRESSURE, "rssi": RSSI}


def on_connect(client, userdata, flags, reason_code, properties=None):
    if reason_code == 0:
        LOG.info("Connected to %s:%s, subscribing to '%s'", MQTT_HOST, MQTT_PORT, MQTT_TOPIC)
        client.subscribe(MQTT_TOPIC)
    else:
        LOG.error("MQTT connection refused (reason_code=%s)", reason_code)


def on_message(client, userdata, msg):
    parts = msg.topic.split("/")
    device = parts[1] if len(parts) > 1 else "unknown"
    try:
        data = json.loads(msg.payload.decode())
        for key, metric in _FIELDS.items():
            if key in data:
                metric.labels(device).set(float(data[key]))
        MESSAGES.labels(device, "ok").inc()
    except (ValueError, TypeError) as exc:
        LOG.warning("Discarding malformed message on '%s': %s", msg.topic, exc)
        MESSAGES.labels(device, "error").inc()


def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")

    # paho-mqtt 2.x requires an explicit callback API version.
    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
    if MQTT_USER:
        client.username_pw_set(MQTT_USER, MQTT_PASSWORD)
    client.on_connect = on_connect
    client.on_message = on_message
    client.reconnect_delay_set(min_delay=1, max_delay=30)

    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))

    start_http_server(EXPORTER_PORT)
    LOG.info("Prometheus metrics available on :%s", EXPORTER_PORT)

    client.connect(MQTT_HOST, MQTT_PORT, keepalive=60)
    client.loop_forever()


if __name__ == "__main__":
    main()
