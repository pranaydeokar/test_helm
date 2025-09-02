# ------------------------------ Security Group ---------------------------------------------
variable "public_inbound_acl_rules" {}
variable "public_outbound_acl_rules" {}
variable "private_inbound_acl_rules" {}
variable "private_outbound_acl_rules" {}
variable "new_http_https_sg_ingress_rules_with_cidr_blocks" {}
variable "new_http_https_sg_egress_rules_with_cidr_blocks" {}

# ------------------------------ EKS ---------------------------------------------
variable "eks_managed_node_groups" {}

variable "eks_version" {
  type        = number
  description = "Version of EKS Cluster"
  default     = 1.32
}