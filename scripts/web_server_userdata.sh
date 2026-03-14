#!/bin/bash
set -euxo pipefail

REGION="${region}"
ACCOUNT_ID="${account_id}"
REPO="${repo}"
REGISTRY="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"
GITHUB_REPO="${github_repo}"

# ── 1. Install Docker, jq, curl and dependencies ─────────────────────
dnf install -y docker jq curl tar gzip libicu
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

# ── 6. Install GitHub Actions runner ─────────────────────────────────
id -u github-runner >/dev/null 2>&1 || useradd -m github-runner
usermod -aG docker github-runner
mkdir -p /home/github-runner/actions-runner
cd /home/github-runner/actions-runner

curl -o actions-runner-linux-x64-2.332.0.tar.gz -L \
  https://github.com/actions/runner/releases/download/v2.332.0/actions-runner-linux-x64-2.332.0.tar.gz

tar xzf actions-runner-linux-x64-2.332.0.tar.gz
chown -R github-runner:github-runner /home/github-runner/actions-runner

# ── 7. Fetch GitHub PAT from Secrets Manager ─────────────────────────
PAT=$(aws secretsmanager get-secret-value \
  --region "$REGION" \
  --secret-id github_pat_viki \
  --query SecretString \
  --output text)

# ── 8. Exchange PAT for a registration token ─────────────────────────
REG_TOKEN=$(curl -s -X POST \
  -H "Authorization: token $PAT" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/$GITHUB_REPO/actions/runners/registration-token" \
  | jq -r '.token')

# ── 9. Register the runner ───────────────────────────────────────────
sudo -u github-runner ./config.sh \
  --url "https://github.com/$GITHUB_REPO" \
  --token "$REG_TOKEN" \
  --name "ec2-runner-$(hostname)" \
  --labels self-hosted,ec2 \
  --unattended \
  --replace

# ── 10. Install as a systemd service ─────────────────────────────────
./svc.sh install github-runner
./svc.sh start