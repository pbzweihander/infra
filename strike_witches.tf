locals {
  strike_witches_name = "strike-witches"
}

module "strike_witches_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.18.0"

  name = local.strike_witches_name
  cidr = "10.0.0.0/16"

  azs = [
    "${data.aws_region.current.name}a",
    "${data.aws_region.current.name}c",
    "${data.aws_region.current.name}d",
  ]
  private_subnets = [
    "10.0.0.0/19",
    "10.0.32.0/19",
    "10.0.64.0/19",
  ]
  public_subnets = [
    "10.0.96.0/19",
    "10.0.128.0/19",
    "10.0.160.0/19",
  ]
  intra_subnets = [
    "10.0.192.0/20",
    "10.0.208.0/20",
    "10.0.224.0/20",
  ]

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

resource "aws_acm_certificate" "wildcard_strike_witches_dev" {
  domain_name       = "*.strike.witches.dev"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "wildcard_strike_witches_dev_acm_validation" {
  for_each = {
    for dvo in aws_acm_certificate.wildcard_strike_witches_dev.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.strike_witches_dev.zone_id
}

module "strike_witches_eks" {
  source = "./module/eks"

  cluster_name       = local.strike_witches_name
  kubernetes_version = "1.23"

  vpc_id     = module.strike_witches_vpc.vpc_id
  subnet_ids = module.strike_witches_vpc.private_subnets

  managed_domain_hosted_zones = [
    aws_route53_zone.pbzweihander_dev,
    aws_route53_zone.strike_witches_dev,
  ]

  eks_managed_node_group_defaults = {
    ami_type = "AL2_x86_64"

    iam_role_attach_cni_policy = true

    instance_types = ["t3.small"]

    create_lauch_template = false
    launch_template_name  = ""

    disk_size = 50

    min_size = 1
    max_size = 10
  }

  eks_managed_node_groups = {
    default_a = {
      name       = "sw-default-a"
      subnet_ids = [module.strike_witches_vpc.private_subnets[0]]
    }
    default_c = {
      name       = "sw-default-c"
      subnet_ids = [module.strike_witches_vpc.private_subnets[1]]
    }
    default_d = {
      name       = "sw-default-d"
      subnet_ids = [module.strike_witches_vpc.private_subnets[2]]
    }
  }
}
