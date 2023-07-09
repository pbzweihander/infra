locals {
  grafana_namespace           = "grafana"
  grafana_serviceaccount_name = "grafana"
}

data "aws_iam_policy_document" "grafana" {
  statement {
    actions = [
      "aps:QueryMetrics",
      "aps:GetSeries",
      "aps:GetLabels",
      "aps:GetMetricMetadata",
    ]

    resources = [
      aws_prometheus_workspace.this.arn,
    ]

    effect = "Allow"
  }
}

resource "aws_iam_policy" "grafana" {
  name_prefix = "grafana-${var.cluster_name}-"
  policy      = data.aws_iam_policy_document.grafana.json
}

data "aws_iam_policy_document" "grafana_assume" {
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
        "system:serviceaccount:${local.grafana_namespace}:${local.grafana_serviceaccount_name}",
      ]
    }

    effect = "Allow"
  }
}

resource "aws_iam_role" "grafana" {
  name_prefix        = "grafana-${var.cluster_name}-"
  assume_role_policy = data.aws_iam_policy_document.grafana_assume.json
}

resource "aws_iam_role_policy_attachment" "grafana" {
  role       = aws_iam_role.grafana.name
  policy_arn = aws_iam_policy.grafana.arn
}

resource "helm_release" "grafana" {
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"

  name             = "grafana"
  namespace        = local.grafana_namespace
  create_namespace = true

  values = [yamlencode({
    serviceAccount = {
      name = local.grafana_serviceaccount_name
      annotations = {
        "eks.amazonaws.com/role-arn" = aws_iam_role.grafana.arn
      }
    }
    "grafana.ini" = {
      auth = {
        sigv4_auth_enabled = true
      }
    }
    persistence = {
      enabled = true
    }
  })]
}
