resource "aws_launch_template" "web_server_lt" {
  name_prefix   = "web-lt-"
  image_id      = data.aws_ami.ubuntu_web.id
  instance_type = "t3.micro"

  vpc_security_group_ids = [aws_security_group.web_server_security_group.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.web_server_profile.name
  }

  user_data = base64encode(templatefile("${path.module}/scripts/web_server_userdata.sh", {
    region     = "eu-central-1"
    account_id = "145887419711"
    repo       = "caste-study-1/web-server"
    db_host    = aws_db_instance.postgres.address
    db_user    = "postgres"
    db_name    = "notesdb"
    db_port    = "5432"
  }))
}

resource "aws_autoscaling_group" "web_asg" {
  name             = "web-asg"
  desired_capacity = 3
  min_size         = 2
  max_size         = 3
  vpc_zone_identifier = [
    aws_subnet.app_private_subnet_1a.id,
    aws_subnet.app_private_subnet_1b.id
  ]

  target_group_arns = [aws_lb_target_group.web_tg.arn]

  launch_template {
    id      = aws_launch_template.web_server_lt.id
    version = "$Latest"
  }

  health_check_type       = "ELB"
  default_instance_warmup = 30

  tag {
    key                 = "Name"
    value               = "web-server"
    propagate_at_launch = true
  }
}
