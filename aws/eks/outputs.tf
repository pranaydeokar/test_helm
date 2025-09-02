output "eks_name" {
  value = module.eks.cluster_name
}

output "node_iam_role_name" {
  value = module.eks.node_group_iam_role_name
}

output "tags" {
  value = module.eks.tags
}