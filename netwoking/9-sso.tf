# SSO → EKS using existing Permission Sets
# Assumes:
# - Permission sets exist: AdministratorAccess, PowerUserAccess, ReadOnlyAccess
# - Groups exist: Admin, Developers, Support
# - Groups are assigned those permission sets in IAM Identity Center
data "aws_caller_identity" "current" {}


# Role name prefixes (from existing Permission Sets)
# AWS automatically creates IAM roles:
#   AWSReservedSSO_<PermissionSetName>_<random>
locals {
  admin_role_prefix     = "AWSReservedSSO_AdministratorAccess_"
  developer_role_prefix = "AWSReservedSSO_PowerUserAccess_"
  support_role_prefix   = "AWSReservedSSO_ReadOnlyAccess_"
}


# Discover actual IAM role names via AWS CLI (external)
data "external" "admin_role_lookup" {
  program = ["bash", "-lc", <<-EOF
    set -euo pipefail
    name=$(AWS_PROFILE=${var.aws_profile} AWS_SDK_LOAD_CONFIG=1 \
      aws iam list-roles \
        --query "Roles[?starts_with(RoleName, '${local.admin_role_prefix}')].RoleName | [0]" \
        --output text)
    if [ "$name" = "None" ] || [ "$name" = "null" ] || [ -z "$name" ]; then
      echo '{"name":""}'
    else
      printf '{"name":"%s"}' "$name"
    fi
  EOF
  ]
}

data "external" "dev_role_lookup" {
  program = ["bash", "-lc", <<-EOF
    set -euo pipefail
    name=$(AWS_PROFILE=${var.aws_profile} AWS_SDK_LOAD_CONFIG=1 \
      aws iam list-roles \
        --query "Roles[?starts_with(RoleName, '${local.developer_role_prefix}')].RoleName | [0]" \
        --output text)
    if [ "$name" = "None" ] || [ "$name" = "null" ] || [ -z "$name" ]; then
      echo '{"name":""}'
    else
      printf '{"name":"%s"}' "$name"
    fi
  EOF
  ]
}

data "external" "support_role_lookup" {
  program = ["bash", "-lc", <<-EOF
    set -euo pipefail
    name=$(AWS_PROFILE=${var.aws_profile} AWS_SDK_LOAD_CONFIG=1 \
      aws iam list-roles \
        --query "Roles[?starts_with(RoleName, '${local.support_role_prefix}')].RoleName | [0]" \
        --output text)
    if [ "$name" = "None" ] || [ "$name" = "null" ] || [ -z "$name" ]; then
      echo '{"name":""}'
    else
      printf '{"name":"%s"}' "$name"
    fi
  EOF
  ]
}


# Turn discovered names into IAM Role data sources
data "aws_iam_role" "sso_admin_role" {
  count = data.external.admin_role_lookup.result.name != "" ? 1 : 0
  name  = data.external.admin_role_lookup.result.name
}

data "aws_iam_role" "sso_dev_role" {
  count = data.external.dev_role_lookup.result.name != "" ? 1 : 0
  name  = data.external.dev_role_lookup.result.name
}

data "aws_iam_role" "sso_support_role" {
  count = data.external.support_role_lookup.result.name != "" ? 1 : 0
  name  = data.external.support_role_lookup.result.name
}

# Grant EKS access using the existing SSO IAM roles
# Provider alias aws.eks is defined in 3-provider.tf

# Admins → full cluster admin
resource "aws_eks_access_entry" "sso_admin" {
  provider      = aws.eks
  count         = length(data.aws_iam_role.sso_admin_role) == 1 ? 1 : 0
  cluster_name  = module.eks_al2023.cluster_name
  principal_arn = data.aws_iam_role.sso_admin_role[0].arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "sso_admin" {
  provider      = aws.eks
  count         = length(data.aws_iam_role.sso_admin_role) == 1 ? 1 : 0
  cluster_name  = module.eks_al2023.cluster_name
  principal_arn = data.aws_iam_role.sso_admin_role[0].arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}

# Developers → view-only, limited to specific namespaces
resource "aws_eks_access_entry" "sso_dev" {
  provider      = aws.eks
  count         = length(data.aws_iam_role.sso_dev_role) == 1 ? 1 : 0
  cluster_name  = module.eks_al2023.cluster_name
  principal_arn = data.aws_iam_role.sso_dev_role[0].arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "sso_dev" {
  provider      = aws.eks
  count         = length(data.aws_iam_role.sso_dev_role) == 1 ? 1 : 0
  cluster_name  = module.eks_al2023.cluster_name
  principal_arn = data.aws_iam_role.sso_dev_role[0].arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"

  access_scope {
    type       = "namespace"
    namespaces = var.developer_namespaces
  }
}

# Support → read-only at cluster scope
resource "aws_eks_access_entry" "sso_support" {
  provider      = aws.eks
  count         = length(data.aws_iam_role.sso_support_role) == 1 ? 1 : 0
  cluster_name  = module.eks_al2023.cluster_name
  principal_arn = data.aws_iam_role.sso_support_role[0].arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "sso_support" {
  provider      = aws.eks
  count         = length(data.aws_iam_role.sso_support_role) == 1 ? 1 : 0
  cluster_name  = module.eks_al2023.cluster_name
  principal_arn = data.aws_iam_role.sso_support_role[0].arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"

  access_scope {
    type = "cluster"
  }
}
