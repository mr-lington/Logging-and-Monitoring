resource "aws_iam_policy" "loki_s3_policy" {
  name        = "loki-s3-policy"
  description = "Allow Loki to store logs in S3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "LokiS3BucketList"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = "arn:aws:s3:::${var.bucket_name}"
      },
      {
        Sid    = "LokiS3ObjectAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "arn:aws:s3:::${var.bucket_name}/*"
      }
    ]
  })
}


resource "aws_iam_role" "loki_pod_identity_role" {
  name = "loki-pod-identity-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "pods.eks.amazonaws.com"
        },
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "loki_attach_s3_policy" {
  role       = aws_iam_role.loki_pod_identity_role.name
  policy_arn = aws_iam_policy.loki_s3_policy.arn
}


resource "aws_eks_pod_identity_association" "loki" {
  cluster_name    = module.eks_al2023.cluster_name
  namespace       = "monitoring"
  service_account = "loki"
  role_arn        = aws_iam_role.loki_pod_identity_role.arn
}
