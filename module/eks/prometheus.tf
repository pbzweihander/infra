locals {
  prometheus_namespace                  = "prometheus"
  prometheus_server_serviceaccount_name = "prometheus-server"
}

resource "aws_prometheus_workspace" "this" {
  alias = var.cluster_name
}

data "aws_iam_policy_document" "prometheus" {
  statement {
    actions = [
      "aps:RemoteWrite",
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

resource "aws_iam_policy" "prometheus" {
  name_prefix = "prometheus-${var.cluster_name}-"
  policy      = data.aws_iam_policy_document.prometheus.json
}

data "aws_iam_policy_document" "prometheus_assume" {
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
        "system:serviceaccount:${local.prometheus_namespace}:${local.prometheus_server_serviceaccount_name}",
      ]
    }

    effect = "Allow"
  }
}

resource "aws_iam_role" "prometheus" {
  name_prefix        = "prometheus-${var.cluster_name}-"
  assume_role_policy = data.aws_iam_policy_document.prometheus_assume.json
}

resource "aws_iam_role_policy_attachment" "prometheus" {
  role       = aws_iam_role.prometheus.name
  policy_arn = aws_iam_policy.prometheus.arn
}

resource "helm_release" "prometheus" {
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus"

  name             = "prometheus"
  namespace        = local.prometheus_namespace
  create_namespace = true

  values = [yamlencode({
    serviceAccounts = {
      server = {
        name = local.prometheus_server_serviceaccount_name
        annotations = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.prometheus.arn
        }
      }
    }
    server = {
      remoteWrite = [{
        url = "${aws_prometheus_workspace.this.prometheus_endpoint}api/v1/remote_write"
        sigv4 = {
          region = data.aws_region.current.name
        }
        queue_config = {
          max_samples_per_send = 1000
          max_shards           = 200
          capacity             = 2500
        }
      }]
    }
  })]
}
