# Architecture & Design Decisions

## Overview

The system collects environmental telemetry from ESP32 sensor nodes and delivers
it to a monitoring backend over two segmented Wi-Fi networks:

- a **sensor network** (`192.168.166.0/24`) that the sensor nodes join, and
- a **backbone network** (`192.168.176.0/24`) that carries the data to the server.

An **edge gateway** (Raspberry Pi) sits between the two: it hosts the sensor-network
access point, connects upstream to the backbone as a client, and routes traffic
between them with NAT. This keeps the sensor devices isolated from the backbone
while still letting their data reach the server.

```
ESP32 ──▶ EDGE (AP + uplink, NAT) ──▶ SERVER (MQTT + Prometheus) ──▶ Grafana
```

## Component responsibilities

| Node    | Role                                                                          |
|---------|-------------------------------------------------------------------------------|
| ESP32   | Reads the BME280 and publishes JSON over MQTT to the broker.                   |
| EDGE    | Sensor-network access point **and** backbone client; forwards/NATs traffic.   |
| SERVER  | Backbone access point; runs Mosquitto, the MQTT exporter and Prometheus.      |
| Grafana | Visualises the Prometheus metrics (laptop, or the containerised stack).        |

## Key decision: dedicated radio for the edge access point

### Context

The edge node must be an **access point** (for the sensors) **and** a **station /
client** (uplink to the server) at the same time.

### Problem with a single radio

The Raspberry Pi Zero 2 W has one on-board Wi-Fi chip (Broadcom, `brcmfmac`
driver). Running AP and station concurrently on it has two hard limitations:

1. **Single channel only.** The driver's interface combinations allow one AP plus
   one managed interface, but only on a *single shared channel*. The access point is
   therefore forced onto whatever channel the uplink uses.
2. **Unreliable concurrent data path.** In testing, the radio associated to both
   networks and broadcast traffic (ARP, DHCP) worked, but **unicast data between an
   access-point client and the gateway did not pass reliably**. Sensors could
   associate and obtain a DHCP lease, yet MQTT traffic to the broker stalled.

These limitations make a single-radio edge fragile and hard to operate.

### Decision

Use a **second Wi-Fi radio on the edge — a USB Wi-Fi adapter — with one radio per
role**:

- on-board `wlan0` → **access point** for the sensor network (`hostapd`, `dnsmasq`),
- USB `wlan1` → **station** uplink to the backbone (`wpa_supplicant`),
- IP forwarding + NAT (`iptables` MASQUERADE) between the two.

### Consequences

- **Reliable** — each radio does one job; no concurrency limitation, no shared
  channel, normal DHCP and unicast on both sides.
- **Standard tooling** — plain `hostapd` / `wpa_supplicant` / `dnsmasq`, no
  single-radio workarounds.
- **Cost** — one inexpensive USB Wi-Fi adapter that supports AP or station mode.

> The on-board chip is a perfectly good *single-role* radio: on the server it serves
> the backbone access point without issues. The constraint is specifically the
> *concurrent* AP+station use on one chip.

## Networking details

| Segment      | Subnet             | DHCP range            | Access point          |
|--------------|--------------------|-----------------------|-----------------------|
| Sensor net   | `192.168.166.0/24` | `…166.100 – …166.200` | EDGE `wlan0` `…166.1` |
| Backbone net | `192.168.176.0/24` | `…176.100 – …176.200` | SERVER `wlan0` `…176.1` |

- The edge enables `net.ipv4.ip_forward` and masquerades the sensor subnet behind
  its backbone address, so sensor nodes reach the broker at `192.168.176.1:1883`.
- Services are bound on the server: Mosquitto `:1883`, Prometheus `:9090`, the MQTT
  exporter `:9101`.

## Monitoring pipeline

```
MQTT (sensor/<device>/bme280)
  -> Mosquitto broker
  -> MQTT exporter   (subscribes, converts JSON payloads to Prometheus gauges)
  -> Prometheus      (scrapes :9101, stores time series, evaluates alert rules)
  -> Grafana         (provisioned data source + dashboard)
```

The same exporter, Prometheus configuration and Grafana dashboard run both natively
on the server and in the containerised stack under [`../monitoring`](../monitoring),
so the backend can be demonstrated with or without the Raspberry Pi hardware.
