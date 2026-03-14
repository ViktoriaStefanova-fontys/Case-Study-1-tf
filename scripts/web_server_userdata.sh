#!/bin/bash
set -euxo pipefail

exec > >(tee /var/log/web-server-userdata.log | logger -t user-data -s 2>/dev/console) 2>&1

REGION="${region}"
ACCOUNT_ID="${account_id}"
REPO="${repo}"
REGISTRY="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"

export DEBIAN_FRONTEND=noninteractive

# ── 1. Install Docker, jq, curl and dependencies ─────────────────────
apt-get update -y
apt-get install -y docker.io jq curl tar gzip unzip

# ── 1b. Install AWS CLI v2 ────────────────────────────────────────────
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
unzip -q /tmp/awscliv2.zip -d /tmp
/tmp/aws/install

systemctl enable docker
systemctl start docker

# ── 2. Authenticate Docker to ECR ────────────────────────────────────
aws ecr get-login-password --region "$REGION" \
  | docker login --username AWS --password-stdin "$REGISTRY"

# ── 3. Fetch DB password from Secrets Manager ────────────────────────
DB_PASSWORD=$(aws secretsmanager get-secret-value \
  --region "$REGION" \
  --secret-id db_password \
  --query SecretString \
  --output text)

# ── 4. Pull and run the application container ────────────────────────
docker pull "$REGISTRY/$REPO:latest"

docker run -d \
  --name web-server \
  --restart unless-stopped \
  -p 80:5000 \
  -e DB_HOST="${db_host}" \
  -e DB_USER="${db_user}" \
  -e DB_NAME="${db_name}" \
  -e DB_PORT="${db_port}" \
  -e DB_PASSWORD="$DB_PASSWORD" \
  "$REGISTRY/$REPO:latest"

# ── 4b. Run cAdvisor for container metrics ───────────────────────────
docker run -d \
  --name cadvisor \
  --restart unless-stopped \
  -p 8080:8080 \
  --volume=/:/rootfs:ro \
  --volume=/var/run:/var/run:ro \
  --volume=/sys:/sys:ro \
  --volume=/var/lib/docker/:/var/lib/docker:ro \
  --volume=/dev/disk/:/dev/disk:ro \
  --privileged \
  gcr.io/cadvisor/cadvisor:latest

# ── 5. Install node_exporter for Prometheus monitoring ───────────────
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

systemctl daemon-reload
systemctl enable node_exporter
systemctl start node_exporter
