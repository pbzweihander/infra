locals {
  openobserve_namespace           = "openobserve"
  openobserve_serviceaccount_name = "openobserve"
}

resource "aws_s3_bucket" "openobserve" {
  bucket_prefix = "pbzh-oo-${var.cluster_name}-"
}

data "aws_iam_policy_document" "openobserve" {
  statement {
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:DeleteObject",
    ]

    resources = [
      "${aws_s3_bucket.openobserve.arn}",
      "${aws_s3_bucket.openobserve.arn}/*",
    ]

    effect = "Allow"
  }
}

resource "aws_iam_policy" "openobserve" {
  name_prefix = "openobserve-${var.cluster_name}-"
  policy      = data.aws_iam_policy_document.openobserve.json
}

data "aws_iam_policy_document" "openobserve_assume" {
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
        "system:serviceaccount:${local.openobserve_namespace}:${local.openobserve_serviceaccount_name}",
      ]
    }

    effect = "Allow"
  }
}

resource "aws_iam_role" "openobserve" {
  name_prefix        = "openobserve-${var.cluster_name}-"
  assume_role_policy = data.aws_iam_policy_document.openobserve_assume.json
}

resource "aws_iam_role_policy_attachment" "openobserve" {
  role       = aws_iam_role.openobserve.name
  policy_arn = aws_iam_policy.openobserve.arn
}

resource "random_password" "openobserve" {
  length = 30
}

resource "helm_release" "openobserve" {
  repository = "https://charts.openobserve.ai"
  chart      = "openobserve"

  name             = "openobserve"
  namespace        = local.openobserve_namespace
  create_namespace = true

  values = [yamlencode({
    auth = {
      ZO_ROOT_USER_EMAIL    = "pbzweihander@gmail.com"
      ZO_ROOT_USER_PASSWORD = random_password.openobserve.result
    }
    config = {
      ZO_S3_BUCKET_NAME  = aws_s3_bucket.openobserve.id
      ZO_HTTP_WORKER_NUM = "0"
    }
    serviceAccount = {
      name = local.openobserve_serviceaccount_name
      annotations = {
        "eks.amazonaws.com/role-arn" = aws_iam_role.openobserve.arn
      }
    }
  })]
}

