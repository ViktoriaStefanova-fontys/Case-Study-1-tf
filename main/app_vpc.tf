# Resources:
# aws_vpc
# aws_internet_gateway
# aws_subnet
# aws_subnet
# aws_subnet
# aws_subnet
# aws_ec2_transit_gateway_vpc_attachment
# app vpc

resource "aws_vpc" "app_vpc" {
  cidr_block           = var.app_vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "App VPC"
  }
}

#Internet Gateway
resource "aws_internet_gateway" "igw_app" {
  vpc_id = aws_vpc.app_vpc.id

  tags = {
    Name = "Internet Gateway App"
  }
}


# app vpc public subnets
resource "aws_subnet" "app_public_subnet_1a" {
  vpc_id                  = aws_vpc.app_vpc.id
  cidr_block              = var.app_public_subnets_cidr[0]
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "App public subnet 1a"
  }
}

resource "aws_subnet" "app_public_subnet_1b" {
  vpc_id                  = aws_vpc.app_vpc.id
  cidr_block              = var.app_public_subnets_cidr[1]
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "App public subnet 1b"
  }
}

# app vpc private subnets
resource "aws_subnet" "app_private_subnet_1a" {
  vpc_id                  = aws_vpc.app_vpc.id
  cidr_block              = var.app_private_subnets_cidr[0]
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = false

  tags = {
    Name = "App private subnet 1a"
  }
}

resource "aws_subnet" "app_private_subnet_1b" {
  vpc_id                  = aws_vpc.app_vpc.id
  cidr_block              = var.app_private_subnets_cidr[1]
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = false

  tags = {
    Name = "App private subnet 1b"
  }
}


# transit gw attatchment 
resource "aws_ec2_transit_gateway_vpc_attachment" "app_tgw_attatchment" {
  subnet_ids         = [aws_subnet.app_private_subnet_1a.id, aws_subnet.app_private_subnet_1b.id]
  transit_gateway_id = aws_ec2_transit_gateway.transit_gateway.id
  vpc_id             = aws_vpc.app_vpc.id

  appliance_mode_support = "enable"

  tags = {
    Name = "tgw-attach-app"
  }
}

### SSM Endpoints
resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = aws_vpc.app_vpc.id
  service_name        = "com.amazonaws.eu-central-1.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.app_private_subnet_1a.id, aws_subnet.app_private_subnet_1b.id]
  security_group_ids  = [aws_security_group.vpc_endpoints_sg.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id              = aws_vpc.app_vpc.id
  service_name        = "com.amazonaws.eu-central-1.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.app_private_subnet_1a.id, aws_subnet.app_private_subnet_1b.id]
  security_group_ids  = [aws_security_group.vpc_endpoints_sg.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id              = aws_vpc.app_vpc.id
  service_name        = "com.amazonaws.eu-central-1.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.app_private_subnet_1a.id, aws_subnet.app_private_subnet_1b.id]
  security_group_ids  = [aws_security_group.vpc_endpoints_sg.id]
  private_dns_enabled = true
}

# Endpoints security group
resource "aws_security_group" "vpc_endpoints_sg" {
  name        = "vpc-endpoints-sg"
  description = "Allow HTTPS from VPC for SSM endpoints"
  vpc_id      = aws_vpc.app_vpc.id
}



# *** molq te razberi kakvo the fuck e tova
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = aws_vpc.app_vpc.id
  service_name        = "com.amazonaws.eu-central-1.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.app_private_subnet_1a.id, aws_subnet.app_private_subnet_1b.id]
  security_group_ids  = [aws_security_group.vpc_endpoints_sg.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = aws_vpc.app_vpc.id
  service_name        = "com.amazonaws.eu-central-1.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.app_private_subnet_1a.id, aws_subnet.app_private_subnet_1b.id]
  security_group_ids  = [aws_security_group.vpc_endpoints_sg.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.app_vpc.id
  service_name      = "com.amazonaws.eu-central-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.app_private_subnet_rt.id]
}

resource "aws_vpc_security_group_ingress_rule" "endpoints_https" {
  security_group_id = aws_security_group.vpc_endpoints_sg.id
  cidr_ipv4         = var.app_vpc_cidr
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "endpoints_egress" {
  security_group_id = aws_security_group.vpc_endpoints_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

