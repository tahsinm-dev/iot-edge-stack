/*
 * ESP32 + BME280  ->  MQTT sensor node
 * ---------------------------------------------------------------------------
 * Reads temperature, humidity and pressure from a BME280 and publishes them
 * together with the Wi-Fi signal strength as a JSON payload over MQTT.
 *
 * In the IoT Edge Stack the node joins the edge access point and publishes to
 * the broker on the backbone, reached through the edge gateway's NAT.
 *
 *   Data topic    : sensor/<DEVICE_ID>/bme280
 *   Status topic  : sensor/<DEVICE_ID>/status   (retained, MQTT Last-Will)
 *   Payload       : {"temp":23.50,"hum":45.20,"press":1013.20,"rssi":-57}
 *
 * Use a unique DEVICE_ID per node (e.g. "esp32_01", "esp32_02").
 *
 * Libraries (Arduino Library Manager):
 *   - PubSubClient                 by Nick O'Leary
 *   - Adafruit BME280 Library      (+ Adafruit Unified Sensor)
 * Wiring (I2C): VIN->3V3, GND->GND, SDA->GPIO21, SCL->GPIO22
 */
#include <WiFi.h>
#include <Wire.h>
#include <PubSubClient.h>
#include <Adafruit_BME280.h>

// ----------------------------- Configuration -----------------------------
static const char*    WIFI_SSID     = "EDGE-IOT-XX";       // edge access point
static const char*    WIFI_PASSWORD = "__EDGE_WIFI_PW__";  // edge Wi-Fi passphrase
static const char*    MQTT_HOST     = "192.168.176.1";     // broker on the server
static const uint16_t MQTT_PORT     = 1883;
static const char*    MQTT_USER     = "";                  // set if broker requires auth
static const char*    MQTT_PASSWORD = "";
static const char*    DEVICE_ID     = "esp32_01";          // unique per node
// -------------------------------------------------------------------------

static const uint8_t  SDA_PIN = 21;
static const uint8_t  SCL_PIN = 22;
static const unsigned long PUBLISH_INTERVAL_MS = 5000;

char dataTopic[48];
char statusTopic[48];

WiFiClient   wifiClient;
PubSubClient mqtt(wifiClient);
Adafruit_BME280 bme;
unsigned long lastPublish = 0;

void connectWiFi() {
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Wi-Fi: connecting");
  while (WiFi.status() != WL_CONNECTED) { delay(500); Serial.print('.'); }
  Serial.print(" connected, IP="); Serial.println(WiFi.localIP());
}

void connectMQTT() {
  while (!mqtt.connected()) {
    Serial.print("MQTT: connecting... ");
    // Last-Will: the broker publishes "offline" if this node drops unexpectedly.
    bool ok = mqtt.connect(DEVICE_ID, MQTT_USER, MQTT_PASSWORD,
                           statusTopic, /*willQoS=*/1, /*willRetain=*/true, "offline");
    if (ok) {
      Serial.println("connected");
      mqtt.publish(statusTopic, "online", /*retain=*/true);
    } else {
      Serial.print("failed, rc="); Serial.print(mqtt.state());
      Serial.println(" - retrying in 2 s");
      delay(2000);
    }
  }
}

void setup() {
  Serial.begin(115200);
  snprintf(dataTopic,   sizeof(dataTopic),   "sensor/%s/bme280", DEVICE_ID);
  snprintf(statusTopic, sizeof(statusTopic), "sensor/%s/status", DEVICE_ID);

  Wire.begin(SDA_PIN, SCL_PIN);
  // The BME280 answers on 0x76 or 0x77 depending on the SDO pin.
  if (!bme.begin(0x76) && !bme.begin(0x77)) {
    Serial.println("BME280 not found - check wiring and I2C address (0x76/0x77).");
  }

  connectWiFi();
  mqtt.setServer(MQTT_HOST, MQTT_PORT);
}

void loop() {
  if (WiFi.status() != WL_CONNECTED) connectWiFi();
  if (!mqtt.connected()) connectMQTT();
  mqtt.loop();

  const unsigned long now = millis();
  if (now - lastPublish >= PUBLISH_INTERVAL_MS) {
    lastPublish = now;
    char payload[128];
    snprintf(payload, sizeof(payload),
             "{\"temp\":%.2f,\"hum\":%.2f,\"press\":%.2f,\"rssi\":%d}",
             bme.readTemperature(), bme.readHumidity(),
             bme.readPressure() / 100.0, WiFi.RSSI());
    mqtt.publish(dataTopic, payload);
    Serial.println(payload);
  }
}
