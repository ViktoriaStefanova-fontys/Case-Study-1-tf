
# Resources:
# aws_vpc_peering_connection

# peering app to db vpc
resource "aws_vpc_peering_connection" "app_to_db_peering" {
  vpc_id      = aws_vpc.app_vpc.id
  peer_vpc_id = aws_vpc.db_vpc.id

  auto_accept = true

  requester {
    allow_remote_vpc_dns_resolution = true
  }

  accepter {
    allow_remote_vpc_dns_resolution = true
  }

  tags = {
    Name = "app-db-peering"
  }
}


# # peering hub to app vpc
# resource "aws_vpc_peering_connection" "hub_to_app_peering" {
#   vpc_id      = aws_vpc.hub_vpc.id
#   peer_vpc_id = aws_vpc.app_vpc.id

#   auto_accept = true

#   requester {
#     allow_remote_vpc_dns_resolution = true
#   }

#   accepter {
#     allow_remote_vpc_dns_resolution = true
#   }

#   tags = {
#     Name = "hub-app-peering"
#   }
# }

