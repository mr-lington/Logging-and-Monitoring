variable "aws_profile" {
  type    = string
  default = "lington"
}

variable "sso_home_region" {
  type    = string
  default = "eu-west-3"
}

# Default AWS provider (used by VPC, modules, IAM, SSO roles)
provider "aws" {
  region  = var.sso_home_region
  profile = var.aws_profile
}

# SSO Provider (used for SSO resources)
provider "aws" {
  alias   = "sso"
  region  = var.sso_home_region
  profile = var.aws_profile
}

# EKS Provider (use same region as cluster)
provider "aws" {
  alias   = "eks"
  region  = var.sso_home_region
  profile = var.aws_profile
}

# Namespaces that Developers can view in EKS
variable "developer_namespaces" {
  type    = list(string)
  default = ["prod-backend", "prod-frontend", "prod-data", ]
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.eks.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.eks.token
}


# terraform {
#   required_providers {
#     aws = {
#       source  = "hashicorp/aws"
#       version = ">= 6.15"
#     }

#     helm = {
#       source  = "hashicorp/helm"
#       version = "~> 2.12.1" # ⬅️ IMPORTANT: v2, not v3
#     }

#     external = {
#       source  = "hashicorp/external"
#       version = ">= 2.2"
#     }

#     time = {
#       source  = "hashicorp/time"
#       version = ">= 0.9"
#     }
#   }
# }
