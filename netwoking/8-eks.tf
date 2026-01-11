
# EKS terraform module
module "eks_al2023" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = "${local.env}-demo-eks"
  kubernetes_version = "1.33"


  # Optional
  endpoint_public_access = true # This is needed to reach the kubernetes API from public access, that is accessinng kubectl from your laptop

  # EKS Addons
  addons = {
    coredns = {}
    eks-pod-identity-agent = {
      before_compute = true
    }
    kube-proxy = {}
    vpc-cni = {
      before_compute = true
    }
  }

  vpc_id = aws_vpc.vpc.id
  subnet_ids = [
    aws_subnet.private1.id,
    aws_subnet.private2.id
    #aws_subnet.private3.id
  ]


  eks_managed_node_groups = {
    demo-NG = {
      instance_types = ["t3.large"] # Starting on 1.30, AL2023 is the default AMI type for EKS managed node groups
      ami_type       = "AL2023_x86_64_STANDARD"
      min_size       = 2
      max_size       = 10
      desired_size   = 2

      tags = {
        "k8s.io/cluster-autoscaler/enabled"                           = "true"
        "k8s.io/cluster-autoscaler/${module.eks_al2023.cluster_name}" = "true"
      }
    }
  }

  tags = {
    Environment = "staging"
    ManagedBy   = "Terraform"
  }
}

