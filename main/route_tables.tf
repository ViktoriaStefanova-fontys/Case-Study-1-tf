# Resources:
# aws_route_table
# aws_route
# aws_route_table_association


################## Route tables ##########################
# Hub VPC public subnets
resource "aws_route_table" "hub_public_subnet_rt" {
  vpc_id = aws_vpc.hub_vpc.id

  route {
    cidr_block = "0.0.0.0/0"                     # destination
    gateway_id = aws_internet_gateway.igw_hub.id # target
  }

  route {
    cidr_block         = var.app_vpc_cidr                           # destination
    transit_gateway_id = aws_ec2_transit_gateway.transit_gateway.id # target
  }

  tags = {
    Name = "Hub VPC public subnet RT "
  }
}

## Hub VPC private subnets 1a and 1b(because fck nat needs to add to each table each an entry for each nat instance in each az)
#1a
resource "aws_route_table" "hub_private_subnet_rt_1a" {
  vpc_id = aws_vpc.hub_vpc.id

  tags = {
    Name = "Hub VPC private subnet RT 1a "
  }
}

resource "aws_route" "hub_private_1a_to_app" {
  route_table_id         = aws_route_table.hub_private_subnet_rt_1a.id
  destination_cidr_block = var.app_vpc_cidr
  transit_gateway_id     = aws_ec2_transit_gateway.transit_gateway.id
}

resource "aws_route" "hub_tgw_1a_default" {
  route_table_id         = aws_route_table.hub_private_subnet_rt_1a.id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = module.fck_nat_1a.eni_id
}

#1b
resource "aws_route_table" "hub_private_subnet_rt_1b" {
  vpc_id = aws_vpc.hub_vpc.id

  tags = {
    Name = "Hub VPC private subnet RT 1b"
  }
}

resource "aws_route" "hub_private_1b_to_app" {
  route_table_id         = aws_route_table.hub_private_subnet_rt_1b.id
  destination_cidr_block = var.app_vpc_cidr
  transit_gateway_id     = aws_ec2_transit_gateway.transit_gateway.id
}

resource "aws_route" "hub_tgw_1b_default" {
  route_table_id         = aws_route_table.hub_private_subnet_rt_1b.id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = module.fck_nat_1b.eni_id
}

# App VPC public subnets
resource "aws_route_table" "app_public_subnet_rt" {
  vpc_id = aws_vpc.app_vpc.id

  route {
    cidr_block         = var.hub_vpc_cidr
    transit_gateway_id = aws_ec2_transit_gateway.transit_gateway.id
  }

  route {
    cidr_block = "0.0.0.0/0"                     # destination
    gateway_id = aws_internet_gateway.igw_app.id # target 
  }


  tags = {
    Name = "App VPC public subnet RT"
  }
}


# App VPC private subnets
resource "aws_route_table" "app_private_subnet_rt" {
  vpc_id = aws_vpc.app_vpc.id

  route {
    cidr_block         = var.hub_vpc_cidr                           #destination
    transit_gateway_id = aws_ec2_transit_gateway.transit_gateway.id #target
  }

  route {
    cidr_block                = var.db_vpc_cidr                                 # destination
    vpc_peering_connection_id = aws_vpc_peering_connection.app_to_db_peering.id # target
  }

  route {
    cidr_block         = "0.0.0.0/0"                                #destination
    transit_gateway_id = aws_ec2_transit_gateway.transit_gateway.id #target
  }

  tags = {
    Name = "App VPC private subnet RT"
  }
}

# DB VPC private subnets
resource "aws_route_table" "db_private_subnet_rt" {
  vpc_id = aws_vpc.db_vpc.id

  route {
    cidr_block                = var.app_vpc_cidr                                # destination
    vpc_peering_connection_id = aws_vpc_peering_connection.app_to_db_peering.id # target
  }

  tags = {
    Name = "DB VPC private subnet RT"
  }
}


############# Route tables association ###################
# Hub VPC public subnets
resource "aws_route_table_association" "hub_public_subnet_rt_assoc_1a" {
  subnet_id      = aws_subnet.hub_public_subnet_1a.id
  route_table_id = aws_route_table.hub_public_subnet_rt.id
}

resource "aws_route_table_association" "hub_public_subnet_rt_assoc_1b" {
  subnet_id      = aws_subnet.hub_public_subnet_1b.id
  route_table_id = aws_route_table.hub_public_subnet_rt.id
}


# Hub VPC private subnets
resource "aws_route_table_association" "hub_private_subnet_rt_assoc_1a" {
  subnet_id      = aws_subnet.hub_private_subnet_1a.id
  route_table_id = aws_route_table.hub_private_subnet_rt_1a.id
}

# resource "aws_route_table_association" "hub_private_subnet_rt_assoc_1b" {
#   subnet_id      = aws_subnet.hub_private_subnet_1b.id
#   route_table_id = aws_route_table.hub_private_subnet_rt_1b.id
# }


# App VPC public subnets
resource "aws_route_table_association" "app_public_subnet_rt_assoc_1a" {
  subnet_id      = aws_subnet.app_public_subnet_1a.id
  route_table_id = aws_route_table.app_public_subnet_rt.id
}

resource "aws_route_table_association" "app_public_subnet_rt_assoc_1b" {
  subnet_id      = aws_subnet.app_public_subnet_1b.id
  route_table_id = aws_route_table.app_public_subnet_rt.id
}

# App VPC private subnets
resource "aws_route_table_association" "app_private_subnet_rt_assoc_1a" {
  subnet_id      = aws_subnet.app_private_subnet_1a.id
  route_table_id = aws_route_table.app_private_subnet_rt.id
}

resource "aws_route_table_association" "app_private_subnet_rt_assoc_1b" {
  subnet_id      = aws_subnet.app_private_subnet_1b.id
  route_table_id = aws_route_table.app_private_subnet_rt.id
}


# DB VPC private subnets
resource "aws_route_table_association" "db_private_subnet_rt_assoc_1a" {
  subnet_id      = aws_subnet.db_private_subnet_1a.id
  route_table_id = aws_route_table.db_private_subnet_rt.id
}

resource "aws_route_table_association" "db_private_subnet_rt_assoc_1b" {
  subnet_id      = aws_subnet.db_private_subnet_1b.id
  route_table_id = aws_route_table.db_private_subnet_rt.id
}



