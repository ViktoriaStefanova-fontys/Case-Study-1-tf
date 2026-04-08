resource "aws_launch_template" "web_server_lt" { # web server launch template
  name_prefix   = "web-lt-"
  image_id      = data.aws_ami.ubuntu_web.id
  instance_type = "t3.micro"

  vpc_security_group_ids = [aws_security_group.web_server_security_group.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.web_server_profile.name
  }

  user_data = base64encode(templatefile("${path.module}/scripts/web_server_userdata.sh", { # user data web server
    region     = var.aws_region
    account_id = var.account_id
    repo       = "web-server"
    db_host    = aws_db_instance.postgres.address
    db_user    = "postgres"
    db_name    = "notesdb"
    db_port    = "5432"
  }))
}

resource "aws_autoscaling_group" "web_asg" { #autoscaling group
  name             = "web-asg"
  desired_capacity = 2
  min_size         = 2
  max_size         = 3
  vpc_zone_identifier = [
    aws_subnet.app_private_subnet_1a.id,
    aws_subnet.app_private_subnet_1b.id
  ]

  target_group_arns = [aws_lb_target_group.web_tg.arn] # *** arn: amazon registered name?

  launch_template {
    id      = aws_launch_template.web_server_lt.id
    version = "$Latest"
  }

  health_check_type       = "ELB"
  default_instance_warmup = 15

  tag {
    key                 = "Name"
    value               = "web-server"
    propagate_at_launch = true
  }
}
