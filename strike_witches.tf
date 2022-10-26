locals {
  strike_witches_name = "strike-witches"

  strike_witches_domains = [
    aws_route53_zone.pbzweihander_dev,
    aws_route53_zone.strike_witches_dev,
  ]
}

module "strike_witches_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.18.0"

  name = local.strike_witches_name
  cidr = "10.0.0.0/16"

  azs             = ["ap-northeast-1a", "ap-northeast-1c", "ap-northeast-1d"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]

  create_egress_only_igw = true

  enable_nat_gateway     = true
  one_nat_gateway_per_az = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.strike_witches_name}" = "shared"
    "kubernetes.io/role/elb"                             = 1
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.strike_witches_name}" = "shared"
    "kubernetes.io/role/internal-elb"                    = 1
  }
}

module "strike_witches_eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 18.30.2"

  cluster_name    = local.strike_witches_name
  cluster_version = "1.23"

  vpc_id     = module.strike_witches_vpc.vpc_id
  subnet_ids = module.strike_witches_vpc.private_subnets

  create_aws_auth_configmap = true
  manage_aws_auth_configmap = true

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
  }

  eks_managed_node_group_defaults = {
    ami_type = "AL2_x86_64"

    iam_role_attach_cni_policy = true
  }

  eks_managed_node_groups = {
    default_node_group = {
      instance_types = ["t3.small"]

      create_lauch_template = false
      launch_template_name  = ""

      disk_size = 50

      min_size = 1
      max_size = 10
    }
  }
}

data "aws_eks_cluster_auth" "strike_witches" {
  name = module.strike_witches_eks.cluster_id
}
