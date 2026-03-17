# Resources:
# aws_security_group
# aws_eip
# aws_nat_gateway

# fck-nat in AZ1 (public subnet 1a) updating Hub TGW subnet RT 1a
module "fck_nat_1a" {
  source = "git::https://github.com/ViktoriaStefanova-fontys/terraform-aws-fck-nat.git"

  name         = "hub-fck-nat-1a"
  vpc_id       = aws_vpc.hub_vpc.id
  subnet_id    = aws_subnet.hub_public_subnet_1a.id

  # update_route_tables = true
  route_tables_ids = {
    "hub-private-subnet-rt" = aws_route_table.hub_private_subnet_rt_1a.id
  }
  use_default_security_group    = true
  additional_security_group_ids = [aws_security_group.hub_nat_from_app.id]
}


# fck-nat in AZ2 (public subnet 1b) updating Hub TGW subnet RT 1b
module "fck_nat_1b" {
  source = "git::https://github.com/ViktoriaStefanova-fontys/terraform-aws-fck-nat.git"

  name         = "hub-fck-nat-1b"
  vpc_id       = aws_vpc.hub_vpc.id
  subnet_id    = aws_subnet.hub_public_subnet_1b.id

  # update_route_tables = true
  route_tables_ids = {
    "hub-tgw-rt-1b" = aws_route_table.hub_private_subnet_rt_1b.id
  }

  use_default_security_group    = true
  additional_security_group_ids = [aws_security_group.hub_nat_from_app.id]
}

## security groups for nat inst

resource "aws_security_group" "hub_nat_from_app" {
  name        = "hub-nat-from-spokes"
  description = "Allow spoke VPCs to use fck-nat"
  vpc_id      = aws_vpc.hub_vpc.id

  ingress {
    description = "Allow all from App VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.app_vpc_cidr, var.hub_vpc_cidr]
  }

  egress {
    description = "Allow all egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

















# # Elastic IP for NAT Gateway
# resource "aws_eip" "nat_eip" {
#   domain = "vpc"

#   tags = {
#     Name = "NAT Gateway EIP"
#   }
# }


# # *** nat gateway just for test, make nat inst

# # NAT Gateway in Hub public subnet 1a
# resource "aws_nat_gateway" "hub_nat_gw" {
#   allocation_id = aws_eip.nat_eip.id
#   subnet_id     = aws_subnet.hub_public_subnet_1a.id

#   tags = {
#     Name = "Hub NAT Gateway"
#   }

#   depends_on = [aws_internet_gateway.igw_hub]
# }