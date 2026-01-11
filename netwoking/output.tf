output "cluster_name" {
  value = module.eks_al2023.cluster_name
}
output "cluster_endpoint" {
  value = module.eks_al2023.cluster_endpoint
}
output "cluster_ca" {
  value = module.eks_al2023.cluster_certificate_authority_data
}

