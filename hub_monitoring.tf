data "aws_ami" "ubuntu_2404" {
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


resource "aws_instance" "monitoring" {
  ami                         = data.aws_ami.ubuntu_2404.id
  instance_type               = "t3.medium"
  subnet_id                   = aws_subnet.hub_private_subnet_1a.id
  vpc_security_group_ids      = [aws_security_group.monitoring_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.monitoring_profile.name
  associate_public_ip_address = false

  user_data = file("${path.module}/scripts/monitoring-userdata.sh")

  root_block_device {
    volume_size = 60
    volume_type = "gp3"
  }

  tags = {
    Name = "monitoring-server"
    Role = "monitoring"
  }
}

resource "aws_iam_role" "monitoring_role" {
  name = "monitoring_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "Monitoring Role"
  }
}

resource "aws_iam_role_policy_attachment" "monitoring_ssm" {
  role       = aws_iam_role.monitoring_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_policy" "monitoring_ec2_discovery" {
  name = "monitoring-ec2-discovery"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ec2:DescribeInstances",
        "ec2:DescribeAvailabilityZones"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "monitoring_ec2_discovery_attach" {
  role       = aws_iam_role.monitoring_role.name
  policy_arn = aws_iam_policy.monitoring_ec2_discovery.arn
}

resource "aws_iam_instance_profile" "monitoring_profile" {
  name = "monitoring_profile"
  role = aws_iam_role.monitoring_role.name
}

resource "aws_security_group" "monitoring_sg" {
  name        = "monitoring_sg"
  description = "Monitoring server SG"
  vpc_id      = aws_vpc.hub_vpc.id

  tags = {
    Name = "Monitoring SG"
  }
}

resource "aws_vpc_security_group_egress_rule" "monitoring_egress_all" {
  security_group_id = aws_security_group.monitoring_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

