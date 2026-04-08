# Configure the AWS Provider
provider "aws" {
  profile = var.profile
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

}

# Availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

# ------------------------------------------------------
# Terraform backend bucket
# ------------------------------------------------------
resource "aws_s3_bucket" "terraform_state" {
  bucket = var.terraform_state_bucket_name

  tags = {
    Name = "Terraform State"
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ------------------------------------------------------
# ECR repository
# ------------------------------------------------------
resource "aws_ecr_repository" "web_server" {
  name                 = var.ecr_repository_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = var.ecr_repository_name
  }
}

# ------------------------------------------------------
# Secrets Manager secret containers only
# Do not put the real secret values here unless you
# explicitly want them tracked by Terraform state.
# ------------------------------------------------------
resource "aws_secretsmanager_secret" "github_pat_viki" {
  name                    = "github_pat_viki"
  recovery_window_in_days = 0

  tags = {
    Name = "github_pat_viki"
  }
}

resource "aws_secretsmanager_secret" "db_password" {
  name                    = "db_password"
  recovery_window_in_days = 0

  tags = {
    Name = "db_password"
  }
}

# ------------------------------------------------------
# GitHub OIDC provider
# ------------------------------------------------------
resource "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  tags = {
    Name = "github-actions-oidc"
  }
}

# ------------------------------------------------------
# IAM role for GitHub Actions
# ------------------------------------------------------
data "aws_iam_policy_document" "github_oidc_assume_role" {
  statement {
    sid    = "GitHubActionsAssumeRole"
    effect = "Allow"

    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_actions.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/${var.github_branch}"
      ]
    }
  }
}

resource "aws_iam_role" "github_web_server" {
  name               = "github-web-server"
  assume_role_policy = data.aws_iam_policy_document.github_oidc_assume_role.json

  tags = {
    Name = "github-web-server"
  }
}

# ------------------------------------------------------
# Policy: allow ECR push/pull from GitHub Actions
# ------------------------------------------------------
data "aws_iam_policy_document" "github_ecr_push" {
  statement {
    sid    = "EcrAuth"
    effect = "Allow"

    actions = [
      "ecr:GetAuthorizationToken"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "EcrPushPull"
    effect = "Allow"

    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeImages",
      "ecr:DescribeRepositories",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:ListImages",
      "ecr:PutImage",
      "ecr:UploadLayerPart"
    ]

    resources = [
      aws_ecr_repository.web_server.arn
    ]
  }
}

resource "aws_iam_policy" "github_ecr_push" {
  name   = "github-web-server-ecr-push"
  policy = data.aws_iam_policy_document.github_ecr_push.json

  tags = {
    Name = "github-web-server-ecr-push"
  }
}

resource "aws_iam_role_policy_attachment" "github_ecr_push" {
  role       = aws_iam_role.github_web_server.name
  policy_arn = aws_iam_policy.github_ecr_push.arn
}


resource "aws_iam_policy" "github_web_asg_refresh" {
  name = "github-web-asg-instance-refresh"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "autoscaling:StartInstanceRefresh",
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeInstanceRefreshes"
        ]
        Resource = "arn:aws:autoscaling:eu-central-1:660637682717:autoScalingGroup:*:autoScalingGroupName/web-asg"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "github_web_asg_refresh" {
  role       = "github-web-server"
  policy_arn = aws_iam_policy.github_web_asg_refresh.arn
}



# ------------------------------------------------------
# IAM role for Terraform CI (Case-Study-1-tf pipeline)
# ------------------------------------------------------
resource "aws_iam_role" "github_tf_ci" {
  name = "github-tf-ci"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github_actions.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:ViktoriaStefanova-fontys/Case-Study-1-tf:*"
        }
      }
    }]
  })

  tags = {
    Name = "github-tf-ci"
  }
}

resource "aws_iam_policy" "github_tf_ci" {
  name = "github-tf-ci-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3StateAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::terraform-state-s3-viktoria",
          "arn:aws:s3:::terraform-state-s3-viktoria/*"
        ]
      },
      {
        Sid    = "ReadOnlyForPlan"
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "elasticloadbalancing:Describe*",
          "autoscaling:Describe*",
          "rds:Describe*",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecrets",
          "route53:List*",
          "route53:Get*",
          "wafv2:List*",
          "wafv2:Get*",
          "lambda:List*",
          "lambda:Get*",
          "iam:Get*",
          "iam:List*",
          "logs:Describe*",
          "sns:List*",
          "sns:Get*",
          "transit-gateway:Describe*",
          "ec2:DescribeTransitGateways*"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "github_tf_ci" {
  role       = aws_iam_role.github_tf_ci.name
  policy_arn = aws_iam_policy.github_tf_ci.arn
}