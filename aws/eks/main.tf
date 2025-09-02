################################################################################
# tfstate backend management
################################################################################
terraform {
  backend "s3" {
    bucket = "eks-automated-s3-bucket"
    key    = "terraform.tfstate"
    region = "us-east-1"
  }
}

################################################################################
# Local Variables
################################################################################
locals {
  name           = "eks"
  environment    = "sandkube"
  label_order    = ["environment", "name"]
  region         = "us-east-1"
  vpc_cidr_block = "10.0.0.0/16"
}

################################################################################
# VPC module call
################################################################################
module "vpc" {
  source  = "clouddrove/vpc/aws"
  version = "2.0.0"

  name        = "${local.name}-vpc"
  environment = local.environment
  cidr_block  = local.vpc_cidr_block
}

################################################################################
# Subnet module call
################################################################################
module "subnets" {
  source  = "clouddrove/subnet/aws"
  version = "2.0.0"

  name                = "${local.name}-subnet"
  environment         = local.environment
  nat_gateway_enabled = true
  single_nat_gateway  = true
  availability_zones  = ["${local.region}a", "${local.region}b", "${local.region}c"]
  vpc_id              = module.vpc.vpc_id
  type                = "public-private"
  igw_id              = module.vpc.igw_id
  cidr_block          = module.vpc.vpc_cidr_block
  ipv6_cidr_block     = module.vpc.ipv6_cidr_block
  enable_ipv6         = false

  public_inbound_acl_rules   = var.public_inbound_acl_rules
  public_outbound_acl_rules  = var.public_outbound_acl_rules
  private_inbound_acl_rules  = var.private_inbound_acl_rules
  private_outbound_acl_rules = var.private_outbound_acl_rules
  extra_public_tags = {
    "kubernetes.io/cluster/${module.eks.cluster_name}" = "owned"
    "kubernetes.io/role/elb"                           = "1"
  }
  extra_private_tags = {
    "kubernetes.io/cluster/${module.eks.cluster_name}" = "owned"
    "kubernetes.io/role/internal-elb"                  = "1"
  }
}

################################################################################
# Security Group module call
################################################################################
module "http_https" {
  source  = "clouddrove/security-group/aws"
  version = "2.0.0"

  name                                  = "${local.name}-http-https"
  environment                           = local.environment
  vpc_id                                = module.vpc.vpc_id
  new_sg_ingress_rules_with_cidr_blocks = var.new_http_https_sg_ingress_rules_with_cidr_blocks
  new_sg_egress_rules_with_cidr_blocks  = var.new_http_https_sg_egress_rules_with_cidr_blocks
}


################################################################################
# KMS module call
################################################################################
module "kms" {
  source  = "clouddrove/kms/aws"
  version = "1.3.0"

  name                = "${local.name}-kms"
  environment         = local.environment
  label_order         = local.label_order
  enabled             = true
  description         = "KMS key for sandkube-eks-cluster"
  enable_key_rotation = false
  policy              = data.aws_iam_policy_document.kms.json
}


################################################################################
# EKS module call
################################################################################
module "eks" {
  source = "git::https://github.com/clouddrove/terraform-aws-eks.git?ref=master" 
  enabled = true

  name        = local.name
  environment = local.environment
  label_order = local.label_order

  # Addons
  addons = []

  # EKS
  kubernetes_version     = var.eks_version
  endpoint_public_access = true

  vpc_id                            = module.vpc.vpc_id
  subnet_ids                        = module.subnets.private_subnet_id
  eks_additional_security_group_ids = [module.http_https.security_group_id]
  allowed_cidr_blocks               = [local.vpc_cidr_block]

  # AWS Managed Node Group
  # Default Values for all Node Groups
  managed_node_group_defaults = {
    subnet_ids = module.subnets.private_subnet_id
    tags = {
      "kubernetes.io/cluster/${module.eks.cluster_name}" = "owned"
      "k8s.io/cluster/${module.eks.cluster_name}"        = "owned"
    }
    block_device_mappings = {
      xvda = {
        device_name = "/dev/xvda"
        ebs = {
          volume_size = 50
          volume_type = "gp3"
          iops        = 3000
          throughput  = 150
          encrypted   = true
          kms_key_id  = module.kms.key_arn
        }
      }
    }
  }
  managed_node_group        = var.eks_managed_node_groups
  apply_config_map_aws_auth = true
  map_additional_iam_users = [
    {
      userarn  = "arn:aws:iam::924144197303:role/AWSReservedSSO_AdministratorAccess_3b5b668e6e5741c8"
      username = "AWSReservedSSO_AdministratorAccess_3b5b668e6e5741c8"
      groups   = ["system:masters"]
    },
    {
      userarn  = "arn:aws:iam::924144197303:role/AWSReservedSSO_RestrictedAdmin_58b12189d22677ff"
      username = "AWSReservedSSO_RestrictedAdmin_58b12189d22677ff"
      groups   = ["system:masters"]
    },
    {
      userarn  = "arn:aws:iam::924144197303:role/automated-eks-cluster-assume-role"
      username = "automated-eks-cluster-assume-role"
      groups   = ["system:masters"]
    },
  ]
}


################################################################################
# Addons module call
################################################################################
module "addons" {
   source = "git::https://github.com/clouddrove/terraform-aws-eks-addons.git?ref=master" 

  depends_on       = [module.eks]
  eks_cluster_name = module.eks.cluster_name

  aws_load_balancer_controller             = true
  aws_load_balancer_controller_helm_config = { values = [file("./values/aws-load-balancer-controller-override-values.yaml")] }
  aws_load_balancer_controller_extra_configs = {
    timeout = 300
  }

  aws_ebs_csi_driver             = true
  aws_ebs_csi_driver_helm_config = { values = [file("./values/aws-ebs-csi-driver-override-values.yaml")] }
  aws_ebs_csi_driver_extra_configs = {
    timeout = 300
  }

  metrics_server             = true
  metrics_server_helm_config = { values = [file("./values/metrics-server-override-values.yaml")] }
  metrics_server_extra_configs = {
    timeout = 300
  }

  cluster_autoscaler             = true
  cluster_autoscaler_helm_config = { values = [file("./values/cluster-autoscaler-override-values.yaml")] }
  cluster_autoscaler_extra_configs = {
    timeout = 300
  }
}
