# Ansible provisioning

Automated, repeatable provisioning of both Raspberry Pi nodes — installs the
packages, deploys the configuration from [`../server`](../server) and
[`../edge`](../edge), fills in the secrets and enables the services.

## Prerequisites

- Ansible on your workstation (`pipx install ansible` or `apt install ansible`).
- Both Pis reachable over SSH as the `tahsin` user with key-based login
  (adjust [`inventory.ini`](inventory.ini) / `remote_user` in
  [`ansible.cfg`](ansible.cfg) for your setup).

## Secrets

Wi-Fi passphrases and the MQTT password are **never** committed. Create an
encrypted vault file:

```bash
cp secrets.example.yml secrets.yml
# edit secrets.yml, then:
ansible-vault encrypt secrets.yml
```

## Run

```bash
cd ansible

# both nodes
ansible-playbook site.yml --extra-vars @secrets.yml --ask-vault-pass

# or a single node
ansible-playbook server.yml --extra-vars @secrets.yml --ask-vault-pass
ansible-playbook edge.yml   --extra-vars @secrets.yml --ask-vault-pass
```

The playbooks are idempotent — re-running them only applies what has changed.

## What it configures

| Node   | Result                                                                 |
|--------|------------------------------------------------------------------------|
| server | Backbone access point + Mosquitto (auth), Prometheus, MQTT exporter.   |
| edge   | Sensor access point (`wlan0`) + USB uplink (`wlan1`) + NAT/forwarding.  |
