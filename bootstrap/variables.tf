# variables.tf

variable "aws_region" {
  type        = string
  description = "AWS region"
}

variable "profile" {
  type        = string
  description = "Profile"
}

#######
variable "aws_profile" {
  description = "AWS CLI profile name."
  type        = string
  default     = "fontys"
}

variable "aws_account_id" {
  description = "AWS account ID."
  type        = string
}

variable "terraform_state_bucket_name" {
  description = "Name of the S3 bucket for Terraform remote state."
  type        = string
  default     = "terraform-state-s3-viktoria"
}

variable "ecr_repository_name" {
  description = "Name of the ECR repository."
  type        = string
  default     = "web-server"
}

variable "github_org" {
  description = "GitHub org or username that owns the repository."
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name."
  type        = string
}

variable "github_branch" {
  description = "GitHub branch allowed to assume the AWS role."
  type        = string
  default     = "main"
}

variable "web_asg_name" {
  description = "Name of the web Auto Scaling Group."
  type        = string
  default     = "web-server-asg"
}