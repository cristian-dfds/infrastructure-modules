# --------------------------------------------------
# Init
# --------------------------------------------------

terraform {
  backend "s3" {}
}

provider "aws" {
  region  = var.aws_region
  version = "~> 2.43"
}

# --------------------------------------------------
# ECR repo and policy
# --------------------------------------------------

resource "aws_ecr_repository" "repo" {
  for_each = var.list_of_repos
  name     = each.key

  image_scanning_configuration {
    scan_on_push = var.scan_images
  }
}

resource "aws_ecr_repository_policy" "pol" {
  for_each    = var.list_of_repos
  repository  = each.key

  policy = <<EOF
{
    "Version": "2008-10-17",
    "Statement": [
        {
            "Sid": "Allow pull from AWS IAM principals",
            "Effect": "Allow",
            "Principal": {
                "AWS": ${jsonencode(var.accounts)}
            },
            "Action": [
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchGetImage",
                "ecr:BatchCheckLayerAvailability"
            ]
        }
    ]
}
EOF
}
