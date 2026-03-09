# # Resources:
# # aws_launch_template
# # aws_autoscaling_group

resource "aws_launch_template" "web_server_lt" {
  name_prefix   = "web-lt-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"

  vpc_security_group_ids = [aws_security_group.web_server_security_group.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.web_server_profile.name
  }
}

# resource "aws_autoscaling_group" "web_asg" {
#   name                = "web-asg"
#   desired_capacity    = 2
#   min_size            = 2
#   max_size            = 2
#   vpc_zone_identifier = [
#     aws_subnet.app_private_subnet_1a.id,
#     aws_subnet.app_private_subnet_1b.id
#   ]

#   target_group_arns = [aws_lb_target_group.web_tg.arn]

#   launch_template {
#     id      = aws_launch_template.web_server_lt.id
#     version = "$Latest"
#   }

#   health_check_type = "ELB"
# }