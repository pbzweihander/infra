module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 18.30.2"

  cluster_name    = var.cluster_name
  cluster_version = var.kubernetes_version

  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  create_aws_auth_configmap = true
  manage_aws_auth_configmap = true
  aws_auth_users = [
    {
      userarn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      groups  = ["system:masters"]
    }
  ]

  enable_irsa = true

  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    ingress_master_all = {
      description                   = "Control plane to node all ports/protocols"
      protocol                      = "-1"
      from_port                     = 0
      to_port                       = 0
      type                          = "ingress"
      source_cluster_security_group = true
    }
    egress_all = {
      description      = "Node all egress"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
    ingress_karpenter_webhook_tcp = {
      description                   = "Control plane invoke Karpenter webhook"
      protocol                      = "tcp"
      from_port                     = 8443
      to_port                       = 8443
      type                          = "ingress"
      source_cluster_security_group = true
    }
  }

  eks_managed_node_group_defaults = var.eks_managed_node_group_defaults
  eks_managed_node_groups         = var.eks_managed_node_groups

  tags = {
    "karpenter.sh/discovery" = var.cluster_name
  }
}

data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_id
}
