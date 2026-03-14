# Resources:
# aws_db_subnet_group
# aws_security_group
# aws_vpc_security_group_ingress_rule
# aws_vpc_security_group_egress_rule
# aws_db_instance

# subnet group

resource "aws_db_subnet_group" "rds_subnet_group" {
  name = "rds-subnet-group"
  subnet_ids = [
    aws_subnet.db_private_subnet_1a.id,
    aws_subnet.db_private_subnet_1b.id
  ]

  tags = {
    Name = "RDS Subnet Group"
  }
}

# db security group
resource "aws_security_group" "rds_sg" {
  name        = "rds-security-group"
  description = "Allow PostgreSQL from App VPC only"
  vpc_id      = aws_vpc.db_vpc.id

  tags = {
    Name = "RDS Security Group"
  }
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_app_vpc" {
  security_group_id = aws_security_group.rds_sg.id
  cidr_ipv4         = var.app_vpc_cidr
  ip_protocol       = "tcp"
  from_port         = 5432
  to_port           = 5432
}

resource "aws_vpc_security_group_egress_rule" "rds_egress" {
  security_group_id = aws_security_group.rds_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# RDS instance
resource "aws_db_instance" "postgres" {
  identifier     = "web-server-db"
  engine         = "postgres"
  engine_version = "16"
  instance_class = "db.t3.micro"

  # Storage
  allocated_storage     = 20
  max_allocated_storage = 50
  storage_type          = "gp2"
  storage_encrypted     = true

  # Database
  db_name  = "notesdb"
  username = "postgres"
  password = data.aws_secretsmanager_secret_version.db_password.secret_string

  # Networking
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  publicly_accessible    = false

  # Multi-AZ — this is what creates your primary + standby
  multi_az = false

  # Backups
  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  # Protection
  deletion_protection = false # set true in production
  skip_final_snapshot = true  # set false in production

  tags = {
    Name = "Web Server Database"
  }
}
