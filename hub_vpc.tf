# Resources:
# aws_vpc
# aws_subnet
# aws_subnet
# aws_subnet
# aws_subnet
# aws_internet_gateway
# aws_ec2_transit_gateway_vpc_attachment

# hub vpc
resource "aws_vpc" "hub_vpc" {
  cidr_block           = var.hub_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "Hub VPC"
  }
}

#hub vpc public subnets
resource "aws_subnet" "hub_public_subnet_1a" {
  vpc_id                  = aws_vpc.hub_vpc.id
  cidr_block              = var.hub_public_subnets_cidr[0]
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "Hub public subnet 1a"
  }
}

resource "aws_subnet" "hub_public_subnet_1b" {
  vpc_id                  = aws_vpc.hub_vpc.id
  cidr_block              = var.hub_public_subnets_cidr[1]
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "Hub public subnet 1b"
  }
}

#hub vpc private subnets
resource "aws_subnet" "hub_private_subnet_1a" {
  vpc_id                  = aws_vpc.hub_vpc.id
  cidr_block              = var.hub_private_subnets_cidr[0]
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = false

  tags = {
    Name = "Hub private subnet 1a"
  }
}

resource "aws_subnet" "hub_private_subnet_1b" {
  vpc_id                  = aws_vpc.hub_vpc.id
  cidr_block              = var.hub_private_subnets_cidr[1]
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = false

  tags = {
    Name = "Hub private subnet 1b"
  }
}



#Internet Gateway
resource "aws_internet_gateway" "igw_hub" {
  vpc_id = aws_vpc.hub_vpc.id

  tags = {
    Name = "Internet Gateway Hub"
  }
}

# transit gw attatchment 
resource "aws_ec2_transit_gateway_vpc_attachment" "hub_tgw_attatchment" {
  subnet_ids         = [aws_subnet.hub_private_subnet_1a.id, aws_subnet.hub_private_subnet_1b.id]
  transit_gateway_id = aws_ec2_transit_gateway.transit_gateway.id
  vpc_id             = aws_vpc.hub_vpc.id

  appliance_mode_support = "enable"

  tags = {
    Name = "tgw-attach-hub"
  }
}