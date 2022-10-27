locals {
  strike_witches_external_dns_namespace           = "external-dns"
  strike_witches_external_dns_serviceaccount_name = "external-dns"
}

data "aws_iam_policy_document" "strike_witches_external_dns" {
  statement {
    actions = [
      "route53:ChangeResourceRecordSets",
    ]

    resources = [for zone in local.strike_witches_domains : "arn:aws:route53:::hostedzone/${zone.id}"]

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

resource "aws_iam_policy" "strike_witches_external_dns" {
  name   = "${local.strike_witches_name}-external-dns"
  policy = data.aws_iam_policy_document.strike_witches_external_dns.json
}

data "aws_iam_policy_document" "strike_witches_external_dns_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [module.strike_witches_eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${module.strike_witches_eks.oidc_provider}:sub"

      values = [
        "system:serviceaccount:${local.strike_witches_external_dns_namespace}:${local.strike_witches_external_dns_serviceaccount_name}",
      ]
    }

    effect = "Allow"
  }
}

resource "aws_iam_role" "strike_witches_external_dns" {
  name               = "${local.strike_witches_name}-external-dns"
  assume_role_policy = data.aws_iam_policy_document.strike_witches_external_dns_assume.json
}

resource "aws_iam_role_policy_attachment" "strike_witches_external_dns" {
  role       = aws_iam_role.strike_witches_external_dns.name
  policy_arn = aws_iam_policy.strike_witches_external_dns.arn
}

resource "helm_release" "strike_witches_external_dns" {
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "external-dns"
  version    = "6.11.2"

  namespace        = local.strike_witches_external_dns_namespace
  name             = "external-dns"
  create_namespace = true

  values = [
    yamlencode({
      aws = {
        region = data.aws_region.current.name
      }
      rbac = {
        create = true
      }
      serviceAccount = {
        create = true
        name   = local.strike_witches_external_dns_serviceaccount_name
        annotations = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.strike_witches_external_dns.arn
        }
      }
      domainFilters = [for zone in local.strike_witches_domains : zone.name]
      policy        = "sync"
    })
  ]
}
