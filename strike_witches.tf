locals {
  strike_witches_name = "strike-witches"
}

module "strike_witches_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0.0"

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
    "karpenter.sh/discovery"                             = local.strike_witches_name
  }

  map_public_ip_on_launch = true
}

resource "aws_acm_certificate" "wildcard_strike_witches_dev" {
  domain_name       = "*.strike.witches.dev"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "cloudflare_record" "wildcard_strike_witches_dev_acm_validation" {
  for_each = {
    for dvo in aws_acm_certificate.wildcard_strike_witches_dev.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = data.cloudflare_zone.witches_dev.id
  name    = each.value.name
  value   = each.value.record
  type    = each.value.type
  proxied = false
}

module "strike_witches_eks" {
  source = "./module/eks"

  cluster_name       = local.strike_witches_name
  kubernetes_version = "1.25"

  vpc_id     = module.strike_witches_vpc.vpc_id
  subnet_ids = module.strike_witches_vpc.private_subnets

  managed_domain_hosted_zones = []

  eks_managed_node_group_defaults = {
    ami_type = "BOTTLEROCKET_x86_64"
    platform = "bottlerocket"

    iam_role_attach_cni_policy = true

    create_launch_template = false
    launch_template_name   = ""

    disk_size = 50

    min_size = 1
    max_size = 1

    instance_types = ["t3a.medium"]

    iam_role_additional_policies = [
      # Required by Karpenter
      "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
    ]
  }

  eks_managed_node_groups = {
    t3a_medium_bottlerocket_a = {
      name       = "sw-t3a-sma-br-a"
      subnet_ids = [module.strike_witches_vpc.private_subnets[0]]
    }
    # ap-northeast-1c does not have t3a instances.
    t3a_medium_bottlerocket_d = {
      name       = "sw-t3a-sma-br-d"
      subnet_ids = [module.strike_witches_vpc.private_subnets[2]]
    }
  }

  cloudflare_api_token = var.cloudflare_api_token
  cloudflare_managed_domains = [
    "pbzweihander.social",
    "yuri.garden",
    "pbzweihander.dev",
    "witches.dev",
    "tavern.house",
  ]

  argocd_ingress_host = "argocd.strike.witches.dev"

  notification_slack_webhook_url = var.notification_slack_webhook_url

  grafana_cloud_prometheus_host     = var.grafana_cloud_prometheus_host
  grafana_cloud_prometheus_username = var.grafana_cloud_prometheus_username
  grafana_cloud_loki_host           = var.grafana_cloud_loki_host
  grafana_cloud_loki_username       = var.grafana_cloud_loki_username
  grafana_cloud_token               = var.grafana_cloud_token
}
