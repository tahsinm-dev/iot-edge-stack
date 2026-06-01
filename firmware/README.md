# ESP32 Firmware

Arduino sketch for the ESP32 sensor nodes. It reads a BME280 over I2C and
publishes temperature, humidity, pressure and Wi-Fi signal strength as JSON over
MQTT.

## Topics & payload

```
sensor/<device>/bme280   {"temp":23.50,"hum":45.20,"press":1013.20,"rssi":-57}
sensor/<device>/status   "online" | "offline"   (retained, MQTT Last-Will)
```

## Wiring (I2C)

| BME280 | ESP32   |
|--------|---------|
| VIN    | 3V3     |
| GND    | GND     |
| SDA    | GPIO21  |
| SCL    | GPIO22  |

## Build & flash (Arduino IDE)

1. Install the **ESP32 board package** (Boards Manager).
2. Install libraries (Library Manager): **PubSubClient**, **Adafruit BME280
   Library** and **Adafruit Unified Sensor**.
3. Open [`esp32_bme280_mqtt/esp32_bme280_mqtt.ino`](esp32_bme280_mqtt/esp32_bme280_mqtt.ino)
   and adjust the configuration block:
   - `WIFI_SSID` / `WIFI_PASSWORD` — the edge access point,
   - `MQTT_HOST` — the broker (`192.168.176.1` in the hardware setup, or your
     Docker host for the containerised stack),
   - `DEVICE_ID` — a unique id per node (`esp32_01`, `esp32_02`, …).
4. Select the board and port, then upload. Open the serial monitor at
   **115200 baud** to watch the published payloads.

## Notes

- The sketch reconnects automatically if Wi-Fi or MQTT drops.
- A retained Last-Will message flips the node's `status` topic to `offline` if it
  disappears, so the broker always reflects node availability.
