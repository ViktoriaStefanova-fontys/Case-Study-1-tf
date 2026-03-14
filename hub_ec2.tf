# # Resources:
# # aws_security_group
# # aws_instance
# # aws_instance


# resource "aws_security_group" "test_sg_hub" { # *** remove in the end
#   name        = "test_sg_hub"
#   description = "Connectivity test SG (ICMP + SSH) from allowed CIDR"
#   vpc_id      = aws_vpc.hub_vpc.id

#   ingress {
#     description = "ICMP (ping) from allowed CIDR"
#     from_port   = -1
#     to_port     = -1
#     protocol    = "icmp"
#     cidr_blocks = [var.app_vpc_cidr]
#   }

#   ingress {
#     description = "SSH from allowed CIDR"
#     from_port   = 22
#     to_port     = 22
#     protocol    = "tcp"
#     cidr_blocks = [var.app_vpc_cidr]
#   }

#   ingress {
#     description = "SSH from my IP"
#     from_port   = 22
#     to_port     = 22
#     protocol    = "tcp"
#     cidr_blocks = [var.my_ip]
#   }


#   egress {
#     description = "Allow all outbound"
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
# }


# resource "aws_instance" "test_hub" { # *** remove in the end
#   ami                         = data.aws_ami.amazon_linux.id
#   instance_type               = var.instance_type
#   subnet_id                   = aws_subnet.hub_public_subnet_1a.id
#   vpc_security_group_ids      = [aws_security_group.test_sg_hub.id]
#   key_name                    = "hub_ec2"
#   associate_public_ip_address = true

#   iam_instance_profile = data.aws_iam_instance_profile.ec2_profile.name

#   tags = {
#     Name = "hub test"
#   }
# }


# resource "aws_instance" "test_hub_prv" { # *** remove in the end
#   ami                         = data.aws_ami.amazon_linux.id
#   instance_type               = var.instance_type
#   subnet_id                   = aws_subnet.hub_private_subnet_1a.id
#   vpc_security_group_ids      = [aws_security_group.test_sg_hub.id]
#   key_name                    = "hub_ec2"
#   associate_public_ip_address = false

#   iam_instance_profile = data.aws_iam_instance_profile.ec2_profile.name

#   tags = {
#     Name = "hub test"
#   }
# }