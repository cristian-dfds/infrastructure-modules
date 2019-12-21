# --------------------------------------------------
# AWS
# --------------------------------------------------

variable "aws_region" {
  type = string
}

variable "aws_assume_role_arn" {
  type = string
}

# --------------------------------------------------
# EKS
# --------------------------------------------------

variable "eks_cluster_name" {
  type = string
}

