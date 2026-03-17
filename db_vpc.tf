# Resources:
# aws_vpc
# aws_subnet
# aws_subnet

#db vpc
resource "aws_vpc" "db_vpc" {
  cidr_block = var.db_vpc_cidr

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "Database VPC"
  }
}

#db private subnets 
resource "aws_subnet" "db_private_subnet_1a" {
  vpc_id            = aws_vpc.db_vpc.id
  cidr_block        = var.db_private_subnets_cidr[0]
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "DB private subnet 1a"
  }
}

resource "aws_subnet" "db_private_subnet_1b" {
  vpc_id            = aws_vpc.db_vpc.id
  cidr_block        = var.db_private_subnets_cidr[1]
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "DB private subnet 1b"
  }
}