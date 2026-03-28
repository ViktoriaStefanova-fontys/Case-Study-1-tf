#creation of tgw
resource "aws_ec2_transit_gateway" "transit_gateway" {
  description                     = "Transit Gateway"
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
}
# route table
resource "aws_ec2_transit_gateway_route_table" "transit_gateway_rt" {
  transit_gateway_id = aws_ec2_transit_gateway.transit_gateway.id
}

resource "aws_ec2_transit_gateway_route" "tgw_default_route" {
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.hub_tgw_attatchment.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.transit_gateway_rt.id
}

resource "aws_ec2_transit_gateway_route" "tgw_to_hub" {
  destination_cidr_block         = var.hub_vpc_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.hub_tgw_attatchment.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.transit_gateway_rt.id
}

resource "aws_ec2_transit_gateway_route" "tgw_to_app" {
  destination_cidr_block         = var.app_vpc_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.app_tgw_attatchment.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.transit_gateway_rt.id
}




# Associate attachments to the TGW route table
resource "aws_ec2_transit_gateway_route_table_association" "hub_assoc" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.hub_tgw_attatchment.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.transit_gateway_rt.id
}

resource "aws_ec2_transit_gateway_route_table_association" "app_assoc" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.app_tgw_attatchment.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.transit_gateway_rt.id
}

# #propagations: removed, because i made routes manually
# resource "aws_ec2_transit_gateway_route_table_propagation" "hub_prop" {
#   transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.hub_tgw_attatchment.id
#   transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.transit_gateway_rt.id
# }

# resource "aws_ec2_transit_gateway_route_table_propagation" "app_prop" {
#   transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.app_tgw_attatchment.id
#   transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.transit_gateway_rt.id
# }