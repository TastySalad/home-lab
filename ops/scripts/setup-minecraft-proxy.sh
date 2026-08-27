#!/bin/bash
# VPS Minecraft Reverse Proxy Setup
# Forwards mc.salad-playground.party:25565 → k8s ClusterIP 10.43.236.234:25565
# Run this on racknerd-vps (root) after it boots back up.

set -euo pipefail

echo "=== Installing socat ==="
apt-get update -qq && apt-get install -y -qq socat

echo "=== Creating systemd service ==="
cat > /etc/systemd/system/minecraft-proxy.service << 'SVC'
[Unit]
Description=Minecraft TCP Proxy → K3s ClusterIP
After=network-online.target k3s-agent.service
Wants=network-online.target

[Service]
Type=simple
Restart=always
RestartSec=5
ExecStart=/usr/bin/socat TCP-LISTEN:25565,reuseaddr,fork TCP:10.43.236.234:25565

[Install]
WantedBy=multi-user.target
SVC

systemctl daemon-reload
systemctl enable minecraft-proxy.service
systemctl start minecraft-proxy.service

echo "=== Verifying ==="
ss -tlnp | grep 25565
echo "=== minecraft-proxy is running ==="