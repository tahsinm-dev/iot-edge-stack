#include <WiFi.h>
#include <PubSubClient.h>
#include <Wire.h>
#include <Adafruit_BME280.h>

// ============ ANPASSEN (vor dem Flashen in der Arduino IDE) ============
const char* ssid        = "EDGE-IOT-XX";            // XX = deine Labornummer
const char* password    = "DEIN_EDGE_WLAN_PASSWORT"; // = WPA-Passphrase des EDGE (hostapd)
const char* mqtt_server = "192.168.176.1";           // SERVER / Mosquitto
const char* client_id   = "esp32-bme280-01";         // 2. Board: "esp32-bme280-02"
const char* topic       = "sensor/esp32_01/bme280";  // 2. Board: "sensor/esp32_02/bme280"
// ======================================================================

WiFiClient espClient;
PubSubClient client(espClient);
Adafruit_BME280 bme;

void connectWiFi() {
  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid, password);
  Serial.print("WLAN verbinden");
  while (WiFi.status() != WL_CONNECTED) { delay(500); Serial.print("."); }
  Serial.print(" OK, IP="); Serial.println(WiFi.localIP());
}

void reconnect() {
  while (!client.connected()) {
    Serial.print("MQTT verbinden...");
    if (client.connect(client_id)) { Serial.println(" OK"); }
    else { Serial.print(" Fehler rc="); Serial.print(client.state()); delay(1000); }
  }
}

void setup() {
  Serial.begin(115200);
  Wire.begin(21, 22);                 // SDA=GPIO21, SCL=GPIO22
  if (!bme.begin(0x76) && !bme.begin(0x77)) {
    Serial.println("BME280 nicht gefunden - Adresse 0x76/0x77 und Verkabelung pruefen!");
  }
  connectWiFi();
  client.setServer(mqtt_server, 1883);
}

void loop() {
  if (WiFi.status() != WL_CONNECTED) connectWiFi();
  if (!client.connected()) reconnect();
  client.loop();

  char payload[128];
  snprintf(payload, sizeof(payload),
           "{\"temp\":%.2f,\"hum\":%.2f,\"press\":%.2f}",
           bme.readTemperature(), bme.readHumidity(), bme.readPressure() / 100.0);
  client.publish(topic, payload);
  Serial.println(payload);
  delay(5000);
}
