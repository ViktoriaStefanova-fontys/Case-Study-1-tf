#!/bin/bash
set -euxo pipefail

exec > >(tee /var/log/monitoring-userdata.log | logger -t user-data -s 2>/dev/console) 2>&1

export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y curl wget tar gnupg adduser libfontconfig1 software-properties-common

# ---------- Prometheus ----------
id -u prometheus >/dev/null 2>&1 || useradd --no-create-home --shell /usr/sbin/nologin prometheus
mkdir -p /etc/prometheus /var/lib/prometheus

cd /tmp
curl -LO https://github.com/prometheus/prometheus/releases/download/v3.3.1/prometheus-3.3.1.linux-amd64.tar.gz
tar -xzf prometheus-3.3.1.linux-amd64.tar.gz

cp prometheus-3.3.1.linux-amd64/prometheus /usr/local/bin/
cp prometheus-3.3.1.linux-amd64/promtool /usr/local/bin/

cat >/etc/prometheus/prometheus.yml <<'EOF'
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'monitoring-server'
    static_configs:
      - targets: ['localhost:9100']

  - job_name: 'ec2-web'
    ec2_sd_configs:
      - region: eu-central-1
        port: 9100
        filters:
          - name: instance-state-name
            values: ['running']
    relabel_configs:
      - source_labels: [__meta_ec2_tag_Name]
        regex: web-server
        action: keep

      - source_labels: [__meta_ec2_private_ip]
        regex: (.*)
        target_label: __address__
        replacement: $1:9100
        
  - job_name: 'cadvisor'
    ec2_sd_configs:
      - region: eu-central-1
        port: 8080
        filters:
          - name: instance-state-name
            values: ['running']
    relabel_configs:
      - source_labels: [__meta_ec2_tag_Name]
        regex: web-server
        action: keep
      - source_labels: [__meta_ec2_private_ip]
        target_label: __address__
        replacement: $1:8080
EOF

chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus

cat >/etc/systemd/system/prometheus.service <<'EOF'
[Unit]
Description=Prometheus
After=network.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/var/lib/prometheus \
  --web.listen-address=0.0.0.0:9090

[Install]
WantedBy=multi-user.target
EOF

# ---------- Node Exporter ----------
id -u node_exporter >/dev/null 2>&1 || useradd --no-create-home --shell /usr/sbin/nologin node_exporter

cd /tmp
curl -LO https://github.com/prometheus/node_exporter/releases/download/v1.9.1/node_exporter-1.9.1.linux-amd64.tar.gz
tar -xzf node_exporter-1.9.1.linux-amd64.tar.gz
cp node_exporter-1.9.1.linux-amd64/node_exporter /usr/local/bin/
chown node_exporter:node_exporter /usr/local/bin/node_exporter

cat >/etc/systemd/system/node_exporter.service <<'EOF'
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF

# ---------- Grafana ----------
mkdir -p /etc/apt/keyrings
curl -fsSL https://apt.grafana.com/gpg.key | gpg --dearmor -o /etc/apt/keyrings/grafana.gpg

cat >/etc/apt/sources.list.d/grafana.list <<'EOF'
deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main
EOF

apt-get update -y
apt-get install -y grafana

systemctl daemon-reload
systemctl enable --now prometheus
systemctl enable --now node_exporter
systemctl enable --now grafana-server