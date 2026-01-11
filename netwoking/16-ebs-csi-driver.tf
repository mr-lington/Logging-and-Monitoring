# Trust policy for EBS CSI Driver (Pod Identity -> IAM role)
data "aws_iam_policy_document" "ebs_csi_driver" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }

    actions = [
      "sts:AssumeRole",
      "sts:TagSession",
    ]
  }
}

# IAM role assumed by the EBS CSI Driver service account
resource "aws_iam_role" "ebs_csi_driver" {
  name               = "${module.eks_al2023.cluster_name}-ebs-csi-driver"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_driver.json
}

# Attach AWS-managed EBS CSI policy
resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi_driver.name
}

# Optional: extra permissions for KMS-encrypted EBS volumes
resource "aws_iam_policy" "ebs_csi_driver_encryption" {
  name = "${module.eks_al2023.cluster_name}-ebs-csi-driver-encryption"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKeyWithoutPlaintext",
          "kms:CreateGrant",
        ]
        Resource = "*"
      }
    ]
  })
}

# Optional: attach KMS policy to the EBS CSI role
resource "aws_iam_role_policy_attachment" "ebs_csi_driver_encryption" {
  policy_arn = aws_iam_policy.ebs_csi_driver_encryption.arn
  role       = aws_iam_role.ebs_csi_driver.name
}

# Pod Identity association for the EBS CSI controller
resource "aws_eks_pod_identity_association" "ebs_csi_driver" {
  cluster_name    = module.eks_al2023.cluster_name
  namespace       = "kube-system"
  service_account = "ebs-csi-controller-sa"
  role_arn        = aws_iam_role.ebs_csi_driver.arn
}

# EBS CSI Driver addon
resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name             = module.eks_al2023.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = "v1.31.0-eksbuild.1" # adjust if you want a different version
  service_account_role_arn = aws_iam_role.ebs_csi_driver.arn

  # Just make sure the cluster (and its node groups) exist first
  depends_on = [
    module.eks_al2023
  ]
}
