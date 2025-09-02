#######------------------------------------SECURITY GROUP----------------------------------------------------########
public_inbound_acl_rules = [
  {
    rule_number = 100
    rule_action = "allow"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_block  = "0.0.0.0/0"
  },
  {
    rule_number     = 101
    rule_action     = "allow"
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    ipv6_cidr_block = "::/0"
  }
]
public_outbound_acl_rules = [
  {
    rule_number = 100
    rule_action = "allow"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_block  = "0.0.0.0/0"
  },
  {
    rule_number     = 101
    rule_action     = "allow"
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    ipv6_cidr_block = "::/0"
  }
]
private_inbound_acl_rules = [
  {
    rule_number = 100
    rule_action = "allow"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_block  = "0.0.0.0/0"
  },
  {
    rule_number     = 101
    rule_action     = "allow"
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    ipv6_cidr_block = "::/0"
  }
]
private_outbound_acl_rules = [
  {
    rule_number = 100
    rule_action = "allow"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_block  = "0.0.0.0/0"
  },
  {
    rule_number     = 101
    rule_action     = "allow"
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    ipv6_cidr_block = "::/0"
  }
]
new_http_https_sg_ingress_rules_with_cidr_blocks = [{
  rule_count  = 1
  from_port   = 80
  protocol    = "tcp"
  to_port     = 80
  cidr_blocks = ["10.0.0.0/16"]
  description = "Allow http traffic."
  },
  {
    rule_count  = 2
    from_port   = 443
    protocol    = "tcp"
    to_port     = 443
    cidr_blocks = ["10.0.0.0/16"]
    description = "Allow https traffic."
}]
new_http_https_sg_egress_rules_with_cidr_blocks = [{
  rule_count       = 1
  from_port        = 0
  protocol         = "-1"
  to_port          = 0
  cidr_blocks      = ["0.0.0.0/0"]
  ipv6_cidr_blocks = ["::/0"]
  description      = "Allow all traffic."
}]

#######------------------------------------EKS----------------------------------------------------########
eks_managed_node_groups = {
  application = {
    name                 = "application"
    capacity_type        = "SPOT"
    min_size             = 1
    max_size             = 5
    desired_size         = 1
    force_update_version = true
    instance_types       = ["t3a.medium"]
  }
}