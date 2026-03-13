# variables.tf

variable "aws_region" {
  type        = string
  description = "AWS region"
}

################ HUB VPC ################

variable "hub_vpc_cidr" {
  type        = string
  description = "CIDR block of the Hub VPC"
}

variable "hub_public_subnets_cidr" {
  type        = list(string)
  description = "CIDR block for Hub Public Subnets"
}

variable "hub_private_subnets_cidr" {
  type        = list(string)
  description = "CIDR block for Hub Public Subnets"
}

################ APP VPC ################

variable "app_vpc_cidr" {
  type        = string
  description = "CIDR block of the App VPC"
}

variable "app_public_subnets_cidr" {
  type        = list(string)
  description = "CIDR block for App Public Subnets"
}

variable "app_private_subnets_cidr" {
  type        = list(string)
  description = "CIDR block for App Private Subnets"
}

################ DB VPC ################

variable "db_vpc_cidr" {
  type        = string
  description = "CIDR block of the DB VPC"
}

variable "db_private_subnets_cidr" {
  type        = list(string)
  description = "CIDR block for DB Private Subnets"
}

################# S3 TERRAFORM STATE #########

variable "terraform_state_bucket_name" {
  type        = string
  description = "Name of the S3 bucket for terraform state"
}

############## MY IP ##################
variable "my_ip" {
  description = "my public ip"
  type        = string
}


variable "instance_type" {
  type        = string
  description = "EC2 instance type"
  default     = "t2.micro"
}