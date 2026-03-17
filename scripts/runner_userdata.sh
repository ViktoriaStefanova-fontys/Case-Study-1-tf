#!/bin/bash
set -euxo pipefail

exec > >(tee /var/log/runner-userdata.log | logger -t user-data -s 2>/dev/console) 2>&1

REGION="${region}"
GITHUB_REPO_WEB="${github_repo_web}"
GITHUB_REPO_INFRA="${github_repo_infra}"

export DEBIAN_FRONTEND=noninteractive

# ── 1. System packages ────────────────────────────────────────────────
apt-get update -y
apt-get install -y \
  curl wget git jq unzip tar gzip gnupg \
  software-properties-common ca-certificates lsb-release

# ── 2. Install AWS CLI v2 ─────────────────────────────────────────────
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
unzip -q /tmp/awscliv2.zip -d /tmp
/tmp/aws/install

# ── 3. Install Docker ─────────────────────────────────────────────────
apt-get install -y docker.io
systemctl enable docker
systemctl start docker

# ── 4. Install Terraform ──────────────────────────────────────────────
wget -O- https://apt.releases.hashicorp.com/gpg | \
  gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
  https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
  > /etc/apt/sources.list.d/hashicorp.list

apt-get update -y
apt-get install -y terraform

# ── 5. Create runner user ─────────────────────────────────────────────
id -u github-runner >/dev/null 2>&1 || useradd -m github-runner
usermod -aG docker github-runner

# ── 6. Fetch PATs from Secrets Manager ───────────────────────────────
set +x
PAT_WEB=$(aws secretsmanager get-secret-value \
  --region "$REGION" \
  --secret-id github_pat_viki \
  --query SecretString \
  --output text)

PAT_INFRA=$(aws secretsmanager get-secret-value \
  --region "$REGION" \
  --secret-id github_pat_infra \
  --query SecretString \
  --output text)
set -x

# ── 7. Set up runner for web pipeline ────────────────────────────────
mkdir -p /home/github-runner/runner-web
cd /home/github-runner/runner-web

curl -o actions-runner-linux-x64-2.332.0.tar.gz -L \
  https://github.com/actions/runner/releases/download/v2.332.0/actions-runner-linux-x64-2.332.0.tar.gz
tar xzf actions-runner-linux-x64-2.332.0.tar.gz
chown -R github-runner:github-runner /home/github-runner/runner-web

set +x
REG_TOKEN_WEB=$(curl -s -X POST \
  -H "Authorization: token $PAT_WEB" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/$GITHUB_REPO_WEB/actions/runners/registration-token" \
  | jq -r '.token')
set -x

sudo -u github-runner ./config.sh \
  --url "https://github.com/$GITHUB_REPO_WEB" \
  --token "$REG_TOKEN_WEB" \
  --name "ec2-runner-web-$(hostname)" \
  --labels "self-hosted,linux,runner,web" \
  --unattended \
  --replace

./svc.sh install github-runner
./svc.sh start

# ── 8. Set up runner for infra pipeline ──────────────────────────────
mkdir -p /home/github-runner/runner-infra
cd /home/github-runner/runner-infra

curl -o actions-runner-linux-x64-2.332.0.tar.gz -L \
  https://github.com/actions/runner/releases/download/v2.332.0/actions-runner-linux-x64-2.332.0.tar.gz
tar xzf actions-runner-linux-x64-2.332.0.tar.gz
chown -R github-runner:github-runner /home/github-runner/runner-infra

set +x
REG_TOKEN_INFRA=$(curl -s -X POST \
  -H "Authorization: token $PAT_INFRA" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/$GITHUB_REPO_INFRA/actions/runners/registration-token" \
  | jq -r '.token')
set -x

sudo -u github-runner ./config.sh \
  --url "https://github.com/$GITHUB_REPO_INFRA" \
  --token "$REG_TOKEN_INFRA" \
  --name "ec2-runner-infra-$(hostname)" \
  --labels "self-hosted,linux,runner,infra" \
  --unattended \
  --replace

./svc.sh install github-runner
./svc.sh start