#!/usr/bin/env bash

REGION=us-east-1

aws eks update-kubeconfig --name sandkube-eks-cluster --region $REGION 
export KUBECONFIG=~/.kube/config

#----------------------------------------------
echo "Patching Ingresses..."
for each in $(kubectl get ingress -A | grep "80" | awk '{print $1}');
do
  kubectl patch ingress $(kubectl get ing -n $each | grep "80" | awk '{print $1}') -n $each -p '{"metadata":{"finalizers":[]}}' --type=merge
  kubectl delete ingress $(kubectl get ing -n $each | grep "80" | awk '{print $1}') -n $each
done

#----------------------------------------------
SecurityGroups=""
for each in $(aws elbv2 describe-load-balancers --region $REGION | jq -r '.LoadBalancers[]' | jq -r '.SecurityGroups[]');
do
  SecurityGroups+="$each "
done

#----------------------------------------------
echo "Deleting Load Balancers elbv2..."
for each in $(aws elbv2 describe-load-balancers --region $REGION | grep "LoadBalancerArn" | awk '{print $2}' | cut -d '"' -f2)
do
  aws elbv2 delete-load-balancer --load-balancer-arn $each --region $REGION
done

echo "Deleting Classic Load Balancers..."
for each in $(aws elb describe-load-balancers --region $REGION | grep "LoadBalancerName" | awk '{print $2}' | cut -d'"' -f2)
do
  aws elb delete-load-balancer --load-balancer-name $each --region $REGION
done

echo "Deleting Target Groups..."
for each in $(aws elbv2 describe-target-groups --region $REGION | grep "TargetGroupArn" | awk '{print $2}' | cut -d'"' -f2)
do
  aws elbv2 delete-target-group --target-group-arn $each --region $REGION
done

#----------------------------------------------
for each in $SecurityGroups;
do
  NI_IDS=$(aws ec2 describe-network-interfaces --region $REGION --filters Name=group-id,Values=$each --query 'NetworkInterfaces[*].NetworkInterfaceId' --output text)
  for NI_ID in $NI_IDS; do
    aws ec2 detach-network-interface --region $REGION --attachment-id $NI_ID --force     # Find and 'detach' network interfaces associated with the security group
    while true; do
      # Check the status of the network interface
      NI_STATUS=$(aws ec2 describe-network-interfaces --region $REGION --network-interface-id $NI_ID --query 'NetworkInterfaces[0].Status' --output text)
      # Break the loop if the status is available (detached) or an error occurs
      if [ "$NI_STATUS" = "available" ] || [ -z "$NI_STATUS" ]; then
        break
      fi
      # Sleep for a second before checking again
      sleep 2
    done

    echo "Deleting Network Interface attached to Security Group..."
    aws ec2 delete-network-interface --region $REGION --network-interface-id $NI_ID      # Find and 'delete' network interfaces associated with the security group
    # Wait for the network interface to be deleted
    while true; do
      NI_EXISTS=$(aws ec2 describe-network-interfaces --region $REGION --network-interface-id $NI_ID --output text)
      # Break the loop if the network interface does not exist or an error occurs
      if [ -z "$NI_EXISTS" ]; then
        break
      fi
      # Sleep for a second before checking again
      sleep 2
    done
  done

  REF_SG_IDS=$(aws ec2 describe-security-groups --region $REGION --filters Name=ip-permission.group-id,Values=$each --query 'SecurityGroups[*].GroupId' --output text)
  for REF_SG_ID in $REF_SG_IDS; do
    echo "Revoke Inbound Rules referencing to Security Group..."
    aws ec2 revoke-security-group-ingress --region $REGION --group-id $REF_SG_ID --protocol all --source-group $each     # Find and revoke inbound rules referencing the security group
    while true; do          # Waiting till inbound rules referencing the security group is revoked
      # Check the return value of the command
      REVOKED=$(aws ec2 revoke-security-group-ingress --region $REGION --group-id $REF_SG_ID --protocol all --source-group $each --query 'return' --output text)
      # Break the loop if the return value is true or an error occurs
      if [ "$REVOKED" = "true" ] || [ -z "$REVOKED" ]; then
        break
      fi
      sleep 2
    done
  done

  REF_SG_IDS=$(aws ec2 describe-security-groups --region $REGION --filters Name=egress.ip-permission.group-id,Values=$each --query 'SecurityGroups[*].GroupId' --output text)
  for REF_SG_ID in $REF_SG_IDS; do
    echo "Revoke Outbound Rules referencing to Security Group..."
    aws ec2 revoke-security-group-egress --region $REGION --group-id $REF_SG_ID --protocol all --source-group $each      # Find and revoke outbound rules referencing the security group
    while true; do          # Waiting till outbound rules referencing the security group is revoked
      REVOKED=$(aws ec2 revoke-security-group-egress --region $REGION --group-id $REF_SG_ID --protocol all --source-group $each --query 'return' --output text)
      # Break the loop if the return value is true or an error occurs
      if [ "$REVOKED" = "true" ] || [ -z "$REVOKED" ]; then
        break
      fi
      sleep 2
    done
  done

  echo "Deleting Security Groups created by Load Balancers..."
  aws ec2 delete-security-group --region $REGION --group-id $each       # Delete security Group
done
