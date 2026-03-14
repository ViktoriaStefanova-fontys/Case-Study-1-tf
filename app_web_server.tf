# Resources:
# aws_ami (ubuntu 24.04)
# aws_security_group
# aws_vpc_security_group_ingress_rule
# aws_vpc_security_group_egress_rule
# aws_iam_role
# aws_iam_role_policy_attachment
# aws_iam_instance_profile

data "aws_ami" "ubuntu_web" {
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

resource "aws_vpc_security_group_ingress_rule" "web_server_from_alb" {
  security_group_id = aws_security_group.web_server_security_group.id

  referenced_security_group_id = aws_security_group.alb_security_group.id

  ip_protocol = "tcp"
  from_port   = 80
  to_port     = 80
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
  cidr_ipv4         = var.hub_vpc_cidr
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

# Attach SSM permissions so you can connect via Systems Manager
resource "aws_iam_role_policy_attachment" "ssm_access" {
  role       = aws_iam_role.web_server_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Attach CloudWatch logging permissions
resource "aws_iam_role_policy_attachment" "cloudwatch_access" {
  role       = aws_iam_role.web_server_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Read secrets from Secrets Manager (db_password only - github_pat moved to runner)
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


# resource "aws_security_group" "test_sg_app" { #*** remove in the end
#   name        = "web-test-sg"
#   description = "Connectivity test SG (ICMP + SSH) from allowed CIDR"
#   vpc_id      = aws_vpc.app_vpc.id

#   ingress {
#     description = "ICMP (ping) from allowed CIDR"
#     from_port   = -1
#     to_port     = -1
#     protocol    = "icmp"
#     cidr_blocks = [var.hub_vpc_cidr]
#   }

#   ingress {
#     description = "SSH from allowed CIDR"
#     from_port   = 22
#     to_port     = 22
#     protocol    = "tcp"
#     cidr_blocks = [var.hub_vpc_cidr]
#   }

#   egress {
#     description = "Allow all outbound"
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
# }


# resource "aws_instance" "test_app" { #*** remove in the end
#   ami                         = data.aws_ami.amazon_linux.id
#   instance_type               = var.instance_type
#   subnet_id                   = aws_subnet.app_private_subnet_1a.id
#   vpc_security_group_ids      = [aws_security_group.test_sg_app.id]
#   key_name                    = "web_server"
#   associate_public_ip_address = false

#   iam_instance_profile = data.aws_iam_instance_profile.ec2_profile.name

#   tags = {
#     Name = "app test"
#   }
# }



# *** redo security groups with the new recommended syntax by hashicorp
