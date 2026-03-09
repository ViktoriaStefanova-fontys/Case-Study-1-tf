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
  vpc_id            = aws_vpc.app_vpc.id
  cidr_block        = var.app_private_subnets_cidr[0]
  availability_zone = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = false

  tags = {
    Name = "App private subnet 1a"
  }
}

resource "aws_subnet" "app_private_subnet_1b" {
  vpc_id            = aws_vpc.app_vpc.id
  cidr_block        = var.app_private_subnets_cidr[1]
  availability_zone = data.aws_availability_zones.available.names[1]
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