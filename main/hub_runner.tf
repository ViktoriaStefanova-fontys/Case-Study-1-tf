# Resources:
# aws_security_group (runner_sg)
# aws_vpc_security_group_egress_rule
# aws_iam_role (runner_role)
# aws_iam_role_policy_attachment (x4)
# aws_iam_policy (runner_read_secrets)
# aws_iam_instance_profile (runner_profile)
# aws_instance (github_runner)

data "aws_secretsmanager_secret" "github_pat_viki" {
  name = "github_pat_viki"
}

# data "aws_secretsmanager_secret" "github_pat_infra" {
#   name = "github_pat_infra"
# }

##### EC2 INSTANCE   
resource "aws_instance" "github_runner" {
  ami                         = data.aws_ami.ubuntu_2404.id
  instance_type               = "t3.small"
  subnet_id                   = aws_subnet.hub_private_subnet_1a.id
  vpc_security_group_ids      = [aws_security_group.runner_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.runner_profile.name
  associate_public_ip_address = false

  user_data_base64 = base64encode(templatefile("${path.module}/scripts/runner_userdata.sh", {   # *** opitai se da smenish repotata i regiona s variables
    region           = "eu-central-1"
    github_repo_web  = "ViktoriaStefanova-fontys/Case-Study-1-web-pipeline"
    # github_repo_infra = "ViktoriaStefanova-fontys/Case-Study-1-tf"
  }))

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = {
    Name = "github-runner"
    Role = "runner"
  }
}

##### INSTANCE PROFILE
resource "aws_iam_instance_profile" "runner_profile" {
  name = "runner_profile"
  role = aws_iam_role.runner_role.name
}

# Hub Monitoring security group
resource "aws_security_group" "runner_sg" {
  name        = "runner_sg"
  description = "GitHub Actions runner SG"
  vpc_id      = aws_vpc.hub_vpc.id

  tags = {
    Name = "Runner SG"
  }
}

resource "aws_vpc_security_group_egress_rule" "runner_egress_all" {
  security_group_id = aws_security_group.runner_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

###### IAM ROLE
resource "aws_iam_role" "runner_role" {
  name = "runner_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Name = "GitHub Runner Role"
  }
}

##### IAM ROLE POLICY ATTACHMENTS
resource "aws_iam_role_policy_attachment" "runner_ssm" {
  role       = aws_iam_role.runner_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "runner_ecr_access" {
  role       = aws_iam_role.runner_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"
}

resource "aws_iam_role_policy_attachment" "runner_cloudwatch" {
  role       = aws_iam_role.runner_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_policy" "runner_read_secrets" {
  name = "runner-read-secrets"
 
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "secretsmanager:GetSecretValue"
      Resource = [
        data.aws_secretsmanager_secret.github_pat_viki.arn,
        # data.aws_secretsmanager_secret.github_pat_infra.arn
      ]
    }]
  })
}
 
resource "aws_iam_role_policy_attachment" "runner_read_secrets" {
  role       = aws_iam_role.runner_role.name
  policy_arn = aws_iam_policy.runner_read_secrets.arn
}

# Allow runner to trigger ASG instance refresh
resource "aws_iam_policy" "runner_asg_refresh" {
  name = "runner-asg-instance-refresh"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "autoscaling:StartInstanceRefresh"
      Resource = "arn:aws:autoscaling:eu-central-1:660637682717:autoScalingGroup:*:autoScalingGroupName/web-asg"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "runner_asg_refresh" {
  role       = aws_iam_role.runner_role.name
  policy_arn = aws_iam_policy.runner_asg_refresh.arn
}

# # Allow runner to manage Terraform state in S3 (needed for infra pipeline)
# resource "aws_iam_policy" "runner_terraform_state" {
#   name = "runner-terraform-state"

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Action = [
#           "s3:GetObject",
#           "s3:PutObject",
#           "s3:DeleteObject",
#           "s3:ListBucket"
#         ]
#         Resource = [
#           "arn:aws:s3:::terraform-state-s3-viktoria",
#           "arn:aws:s3:::terraform-state-s3-viktoria/*"
#         ]
#       }
#     ]
#   })
# }

# resource "aws_iam_role_policy_attachment" "runner_terraform_state" {
#   role       = aws_iam_role.runner_role.name
#   policy_arn = aws_iam_policy.runner_terraform_state.arn
# }


# *** da si napishesh nqkyde vryzkata mejdu policy, polict attachment, roles i instance profiles i sled tova da razmestish resursite tuka da sa podredeni