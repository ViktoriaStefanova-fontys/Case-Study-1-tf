# # Resources:
# # aws_lb
# # aws_lb_target_group
# # aws_lb_listener
# # aws_security_group
# # aws_vpc_security_group_ingress_rule
# # aws_vpc_security_group_ingress_rule
# # aws_vpc_security_group_egress_rule

resource "aws_lb" "web_server_lb" {
  name               = "web-server-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_security_group.id]
  subnets            = [aws_subnet.app_public_subnet_1a.id, aws_subnet.app_public_subnet_1b.id]

  enable_deletion_protection = false
}


resource "aws_lb_target_group" "web_tg" {
  name        = "web-target-group"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.app_vpc.id
  target_type = "instance"

  health_check {
    enabled             = true
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name = "Web Target Group"
  }
}


resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.web_server_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}





















resource "aws_security_group" "alb_security_group" {
  name        = "alb_security_group"
  description = "ALB SG"
  vpc_id      = aws_vpc.app_vpc.id
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb_security_group.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "allow_https_alb" {
  security_group_id = aws_security_group.alb_security_group.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "alb_allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.alb_security_group.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}