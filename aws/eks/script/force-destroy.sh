#!/usr/bin/env bash

terraform state rm 'module.vpc'      # Remove VPC from state file

# Deleting resources that may cause error on deletion step
terraform state rm 'module.addons.module.aws_load_balancer_controller[0].module.helm_addon.helm_release.addon[0]'
terraform state rm 'module.addons.module.cluster_autoscaler[0].module.helm_addon.helm_release.addon[0]'
terraform state rm 'module.addons.module.metrics_server[0].module.helm_addon.helm_release.addon[0]'
terraform state rm 'module.addons.module.aws_ebs_csi_driver[0].module.helm_addon.helm_release.addon[0]'
terraform state rm 'module.eks.kubernetes_config_map.aws_auth_ignore_changes[0]'
terraform state rm 'module.addons.module.cluster_autoscaler[0].module.helm_addon.module.irsa[0].kubernetes_service_account_v1.irsa[0]'
terraform state rm 'module.addons.module.aws_ebs_csi_driver[0].module.helm_addon.module.irsa[0].kubernetes_service_account_v1.irsa[0]'
terraform state rm 'module.addons.module.aws_load_balancer_controller[0].module.helm_addon.module.irsa[0].kubernetes_service_account_v1.irsa[0]'

terraform destroy --auto-approve      # Delete all Terraform resources.