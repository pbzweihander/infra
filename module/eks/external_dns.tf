locals {
  external_dns_namespace           = "external-dns"
  external_dns_serviceaccount_name = "external-dns"
}

data "aws_iam_policy_document" "external_dns" {
  statement {
    actions = [
      "route53:ChangeResourceRecordSets",
    ]

    resources = [for zone in var.managed_domain_hosted_zones : zone.arn]

    effect = "Allow"
  }

  statement {
    actions = [
      "route53:ListHostedZones",
      "route53:ListResourceRecordSets",
      "route53:ListTagsForResource",
    ]

    resources = [
      "*",
    ]

    effect = "Allow"
  }
}

resource "aws_iam_policy" "external_dns" {
  name_prefix = "${var.cluster_name}-external-dns"
  policy      = data.aws_iam_policy_document.external_dns.json
}

data "aws_iam_policy_document" "external_dns_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:sub"

      values = [
        "system:serviceaccount:${local.external_dns_namespace}:${local.external_dns_serviceaccount_name}",
      ]
    }

    effect = "Allow"
  }
}

resource "aws_iam_role" "external_dns" {
  name_prefix        = "${var.cluster_name}-external-dns"
  assume_role_policy = data.aws_iam_policy_document.external_dns_assume.json
}

resource "aws_iam_role_policy_attachment" "external_dns" {
  role       = aws_iam_role.external_dns.name
  policy_arn = aws_iam_policy.external_dns.arn
}

resource "helm_release" "external_dns" {
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "external-dns"
  version    = "6.11.2"

  namespace        = local.external_dns_namespace
  name             = "external-dns"
  create_namespace = true

  wait = false

  values = [
    yamlencode({
      sources = [
        "ingress",
      ]
      aws = {
        region = data.aws_region.current.name
      }
      rbac = {
        create = true
      }
      serviceAccount = {
        create = true
        name   = local.external_dns_serviceaccount_name
        annotations = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.external_dns.arn
        }
      }
      domainFilters = [for zone in var.managed_domain_hosted_zones : zone.name]
      policy        = "sync"
    })
  ]
}
