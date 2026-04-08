# Resources:
# aws_ami (ubuntu 24.04)
# aws_security_group
# aws_vpc_security_group_ingress_rule
# aws_vpc_security_group_egress_rule
# aws_iam_role
# aws_iam_role_policy_attachment
# aws_iam_instance_profile

data "aws_ami" "ubuntu_web" { #ubuntu ami
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}


resource "aws_security_group" "web_server_security_group" {
  name        = "web_server_security_group"
  description = "Web Server SG"
  vpc_id      = aws_vpc.app_vpc.id
}

resource "aws_vpc_security_group_ingress_rule" "web_server_from_alb_http" {
  security_group_id = aws_security_group.web_server_security_group.id

  referenced_security_group_id = aws_security_group.alb_security_group.id

  ip_protocol = "tcp"
  from_port   = 80
  to_port     = 80
}

resource "aws_vpc_security_group_ingress_rule" "web_server_from_alb_https" {
  security_group_id = aws_security_group.web_server_security_group.id

  referenced_security_group_id = aws_security_group.alb_security_group.id

  ip_protocol = "tcp"
  from_port   = 443
  to_port     = 443
}

resource "aws_vpc_security_group_ingress_rule" "web_server_node_exporter_from_monitoring" {
  security_group_id = aws_security_group.web_server_security_group.id
  cidr_ipv4         = var.hub_vpc_cidr
  ip_protocol       = "tcp"
  from_port         = 9100
  to_port           = 9100
}

resource "aws_vpc_security_group_ingress_rule" "web_server_cadvisor_from_monitoring" {
  security_group_id = aws_security_group.web_server_security_group.id
  cidr_ipv4         = var.hub_vpc_cidr # *** smeni na security groupata na monitoring ili na subneta
  ip_protocol       = "tcp"
  from_port         = 8080
  to_port           = 8080
}

resource "aws_vpc_security_group_egress_rule" "web_allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.web_server_security_group.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
}

###### IAM ROLE
resource "aws_iam_role" "web_server_role" {
  name = "web_server_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Name = "Web Server Role"
  }
}

##### IAM ROLE POLICIES ATTACHMENTS
# ECR read permissions
resource "aws_iam_role_policy_attachment" "ecr_access" {
  role       = aws_iam_role.web_server_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# SSM permissions
resource "aws_iam_role_policy_attachment" "ssm_access" {
  role       = aws_iam_role.web_server_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# CloudWatch
resource "aws_iam_role_policy_attachment" "cloudwatch_access" {
  role       = aws_iam_role.web_server_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Read db_password from Secrets Manager 
data "aws_secretsmanager_secret" "db_password" {
  name = "db_password"
}

data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = data.aws_secretsmanager_secret.db_password.id
}

resource "aws_iam_policy" "web_read_secrets" {
  name = "secrets-read"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "secretsmanager:GetSecretValue"
      Resource = [
        data.aws_secretsmanager_secret.db_password.arn
      ]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "web_read_secrets" {
  role       = aws_iam_role.web_server_role.name
  policy_arn = aws_iam_policy.web_read_secrets.arn
}

##### INSTANCE PROFILE
resource "aws_iam_instance_profile" "web_server_profile" {
  name = "web_server_profile"
  role = aws_iam_role.web_server_role.name
}

