resource "aws_security_group" "hub_vpc_endpoints_sg" {
  name        = "hub-vpc-endpoints-sg"
  description = "Allow HTTPS from Hub VPC resources to interface endpoints"
  vpc_id      = aws_vpc.hub_vpc.id

  tags = {
    Name = "Hub VPC Endpoints SG"
  }
}

resource "aws_vpc_security_group_ingress_rule" "hub_vpc_endpoints_https_from_hub" {
  security_group_id = aws_security_group.hub_vpc_endpoints_sg.id
  cidr_ipv4         = var.hub_vpc_cidr
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "hub_vpc_endpoints_egress_all" {
  security_group_id = aws_security_group.hub_vpc_endpoints_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_endpoint" "hub_ssm" {
  vpc_id            = aws_vpc.hub_vpc.id
  service_name      = "com.amazonaws.eu-central-1.ssm"
  vpc_endpoint_type = "Interface"
  subnet_ids = [
    aws_subnet.hub_private_subnet_1a.id,
    aws_subnet.hub_private_subnet_1b.id
  ]
  security_group_ids  = [aws_security_group.hub_vpc_endpoints_sg.id]
  private_dns_enabled = true

  tags = {
    Name = "Hub SSM Endpoint"
  }
}

resource "aws_vpc_endpoint" "hub_ssmmessages" {
  vpc_id            = aws_vpc.hub_vpc.id
  service_name      = "com.amazonaws.${var.aws_region}.ssmmessages"
  vpc_endpoint_type = "Interface"
  subnet_ids = [
    aws_subnet.hub_private_subnet_1a.id,
    aws_subnet.hub_private_subnet_1b.id
  ]
  security_group_ids  = [aws_security_group.hub_vpc_endpoints_sg.id]
  private_dns_enabled = true

  tags = {
    Name = "Hub SSMMessages Endpoint"
  }
}

resource "aws_vpc_endpoint" "hub_ec2messages" {
  vpc_id            = aws_vpc.hub_vpc.id
  service_name      = "com.amazonaws.${var.aws_region}.ec2messages"
  vpc_endpoint_type = "Interface"
  subnet_ids = [
    aws_subnet.hub_private_subnet_1a.id,
    aws_subnet.hub_private_subnet_1b.id
  ]
  security_group_ids  = [aws_security_group.hub_vpc_endpoints_sg.id]
  private_dns_enabled = true

  tags = {
    Name = "Hub EC2Messages Endpoint"
  }
}