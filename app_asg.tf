# # Resources:
# # aws_launch_template
# # aws_autoscaling_group

resource "aws_launch_template" "web_server_lt" {
  name_prefix   = "web-lt-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"

  vpc_security_group_ids = [aws_security_group.web_server_security_group.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.web_server_profile.name
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -euxo pipefail

    REGION="eu-central-1"
    ACCOUNT_ID="145887419711"
    REPO="caste-study-1/web-server"
    REGISTRY="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"

    # ── 1. Install Docker and jq ─────────────────────────────────────
    dnf install -y docker jq libicu
    systemctl enable docker
    systemctl start docker
  

    # ── 2. Authenticate Docker to ECR ────────────────────────────────
    aws ecr get-login-password --region $REGION \
      | docker login --username AWS --password-stdin $REGISTRY

    # ── 3. Fetch DB password from Secrets Manager ─────────────────────
    DB_PASSWORD=$(aws secretsmanager get-secret-value \
      --region $REGION \
      --secret-id db_password \
      --query SecretString \
      --output text)

    # ── 4. Pull and run the container ────────────────────────────────
    docker pull $REGISTRY/$REPO:latest

    docker run -d \
      --name web-server \
      --restart unless-stopped \
      -p 80:5000 \
      -e DB_HOST="${aws_db_instance.postgres.address}" \
      -e DB_USER="postgres" \
      -e DB_NAME="notesdb" \
      -e DB_PORT="5432" \
      -e DB_PASSWORD="$DB_PASSWORD" \
      $REGISTRY/$REPO:latest

    # ── 5. Install GitHub Actions runner ─────────────────────────────
    useradd -m github-runner
    usermod -aG docker github-runner
    mkdir -p /home/github-runner/actions-runner
    cd /home/github-runner/actions-runner

    curl -o actions-runner-linux-x64-2.332.0.tar.gz -L \
      https://github.com/actions/runner/releases/download/v2.332.0/actions-runner-linux-x64-2.332.0.tar.gz

    tar xzf actions-runner-linux-x64-2.332.0.tar.gz
    chown -R github-runner:github-runner /home/github-runner/actions-runner

    # ── 6. Fetch PAT from Secrets Manager ────────────────────────────
    PAT=$(aws secretsmanager get-secret-value \
      --region $REGION \
      --secret-id github_pat_viki \
      --query SecretString \
      --output text)

    # ── 7. Exchange PAT for a registration token ──────────────────────
    REG_TOKEN=$(curl -s -X POST \
      -H "Authorization: token $PAT" \
      -H "Accept: application/vnd.github+json" \
      https://api.github.com/repos/ViktoriaStefanova-fontys/Case-Study-1-web-pipeline/actions/runners/registration-token \
      | jq -r '.token')

    # ── 8. Register the runner ────────────────────────────────────────
    sudo -u github-runner ./config.sh \
      --url https://github.com/ViktoriaStefanova-fontys/Case-Study-1-web-pipeline \
      --token $REG_TOKEN \
      --name "ec2-runner-$(hostname)" \
      --labels self-hosted,ec2 \
      --unattended \
      --replace

    # ── 9. Install as a systemd service ──────────────────────────────
    ./svc.sh install github-runner
    ./svc.sh start
  EOF
  )
}

resource "aws_autoscaling_group" "web_asg" {
  name                = "web-asg"
  desired_capacity    = 2
  min_size            = 2
  max_size            = 2
  vpc_zone_identifier = [
    aws_subnet.app_private_subnet_1a.id,
    aws_subnet.app_private_subnet_1b.id
  ]

  target_group_arns = [aws_lb_target_group.web_tg.arn]

  launch_template {
    id      = aws_launch_template.web_server_lt.id
    version = "$Latest"
  }

  health_check_type = "ELB"
  default_instance_warmup = 30

  tag {
    key                 = "Name"
    value               = "web-server"
    propagate_at_launch = true
  }
}