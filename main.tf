# Configure the AWS Provider
provider "aws" {
  profile = "fontys"
  region  = var.aws_region
}

terraform {
  required_version = ">= 1.14.5"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.33.0"
    }
  }

  backend "s3" {
    bucket = "terraform-state-s3-viktoria"
    key = "terraform.tfstate"
    region = "eu-central-1"
    # encrypt = true
    use_lockfile = true

    profile = "fontys"
    
  }

}

# Availability zones
data "aws_availability_zones" "available" {
  state = "available"
}