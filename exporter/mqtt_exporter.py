#!/usr/bin/env python3
"""MQTT -> Prometheus Exporter: abonniert sensor/#, stellt BME280-Werte auf :9100 bereit."""
from prometheus_client import start_http_server, Gauge
import paho.mqtt.client as mqtt
import json

temperature = Gauge("bme280_temperature_celsius", "Temperatur in Celsius", ["device"])
humidity    = Gauge("bme280_humidity_percent",    "Luftfeuchtigkeit in Prozent", ["device"])
pressure    = Gauge("bme280_pressure_hpa",         "Luftdruck in hPa", ["device"])

def on_message(client, userdata, msg):
    try:
        data = json.loads(msg.payload.decode())
        parts = msg.topic.split("/")
        device = parts[1] if len(parts) > 1 else "unknown"
        temperature.labels(device).set(data.get("temp", 0))
        humidity.labels(device).set(data.get("hum", 0))
        pressure.labels(device).set(data.get("press", 0))
    except Exception as e:
        print("Fehler beim Verarbeiten:", e)

# WICHTIG (paho-mqtt 2.x): Callback-API-Version angeben, sonst ValueError.
client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION1)
client.on_message = on_message
client.connect("localhost", 1883, 60)
client.subscribe("sensor/#")

start_http_server(9100)
print("MQTT-Exporter laeuft auf :9100, abonniert sensor/#")
client.loop_forever()
