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
    bucket       = "terraform-state-s3-viktoria"
    key          = "cs1/main.tfstate"
    region       = "eu-central-1"
    profile      = "fontys"
    use_lockfile = true
  }

}

# Availability zones
data "aws_availability_zones" "available" {
  state = "available"
}
