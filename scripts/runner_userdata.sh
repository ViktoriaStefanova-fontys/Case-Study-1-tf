#!/bin/bash
set -euxo pipefail

exec > >(tee /var/log/runner-userdata.log | logger -t user-data -s 2>/dev/console) 2>&1

REGION="${region}"
GITHUB_ORG="${github_org}"

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

# ── 6. Download GitHub Actions runner ────────────────────────────────
mkdir -p /home/github-runner/actions-runner
cd /home/github-runner/actions-runner

curl -o actions-runner-linux-x64-2.332.0.tar.gz -L \
  https://github.com/actions/runner/releases/download/v2.332.0/actions-runner-linux-x64-2.332.0.tar.gz

tar xzf actions-runner-linux-x64-2.332.0.tar.gz
chown -R github-runner:github-runner /home/github-runner/actions-runner

# ── 7. Fetch GitHub PAT from Secrets Manager ─────────────────────────
set +x
PAT=$(aws secretsmanager get-secret-value \
  --region "$REGION" \
  --secret-id github_pat_viki \
  --query SecretString \
  --output text)

# ── 8. Exchange PAT for an org-level registration token ──────────────
REG_TOKEN=$(curl -s -X POST \
  -H "Authorization: token $PAT" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/orgs/$GITHUB_ORG/actions/runners/registration-token" \
  | jq -r '.token')
set -x

# ── 9. Register the runner ────────────────────────────────────────────
sudo -u github-runner ./config.sh \
  --url "https://github.com/$GITHUB_ORG" \
  --token "$REG_TOKEN" \
  --name "ec2-runner-$(hostname)" \
  --labels "self-hosted,linux,runner,web,infra" \
  --unattended \
  --replace

# ── 10. Install as a systemd service ─────────────────────────────────
./svc.sh install github-runner
./svc.sh start
