# resource "aws_route53_zone" "private_internal" {
#   name = "internal.cs1"

#   vpc {
#     vpc_id = aws_vpc.app_vpc.id
#   }

#   vpc {
#     vpc_id = aws_vpc.db_vpc.id
#   }

#   vpc {
#     vpc_id = aws_vpc.hub_vpc.id
#   }

#   tags = {
#     Name = "private-internal-zone"
#   }
# }

# resource "aws_route53_record" "db_record" {
#   zone_id = aws_route53_zone.private_internal.zone_id
#   name    = "db.internal.cs1"
#   type    = "CNAME"
#   ttl     = 300
#   records = [aws_db_instance.postgres.address]
# }