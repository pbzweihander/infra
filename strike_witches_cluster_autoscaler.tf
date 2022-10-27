locals {
  strike_witches_cluster_autoscaler_namespace           = "cluster-autoscaler"
  strike_witches_cluster_autoscaler_serviceaccount_name = "cluster-autoscaler"
}

data "aws_iam_policy_document" "strike_witches_cluster_autoscaler" {
  statement {
    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:DescribeTags",
      "autoscaling:SetDesiredCapacity",
      "autoscaling:TerminateInstanceInAutoScalingGroup",
      "ec2:DescribeImages",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeLaunchTemplateVersions",
      "ec2:GetInstanceTypesFromInstanceRequirements",
      "eks:DescribeNodegroup",
    ]

    resources = ["*"]

    effect = "Allow"
  }
}

resource "aws_iam_policy" "strike_witches_cluster_autoscaler" {
  name   = "${local.strike_witches_name}-cluster-autoscaler"
  policy = data.aws_iam_policy_document.strike_witches_cluster_autoscaler.json
}

data "aws_iam_policy_document" "strike_witches_cluster_autoscaler_assume" {
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
        "system:serviceaccount:${local.strike_witches_cluster_autoscaler_namespace}:${local.strike_witches_cluster_autoscaler_serviceaccount_name}",
      ]
    }

    effect = "Allow"
  }
}

resource "aws_iam_role" "strike_witches_cluster_autoscaler" {
  name               = "${local.strike_witches_name}-cluster-autoscaler"
  assume_role_policy = data.aws_iam_policy_document.strike_witches_cluster_autoscaler_assume.json
}

resource "aws_iam_role_policy_attachment" "strike_witches_cluster_autoscaler" {
  role       = aws_iam_role.strike_witches_cluster_autoscaler.name
  policy_arn = aws_iam_policy.strike_witches_cluster_autoscaler.arn
}

resource "helm_release" "strike_witches_cluster_autoscaler" {
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  version    = "9.21.0"

  namespace        = local.strike_witches_cluster_autoscaler_namespace
  name             = "cluster-autoscaler"
  create_namespace = true

  values = [
    yamlencode({
      cloudProvider = "aws"
      awsRegion     = data.aws_region.current.name
      rbac = {
        create = true
        serviceAccount = {
          create = true
          name   = local.strike_witches_cluster_autoscaler_serviceaccount_name
          annotations = {
            "eks.amazonaws.com/role-arn" = aws_iam_role.strike_witches_cluster_autoscaler.arn
          }
        }
      }
      autoDiscovery = {
        clusterName = local.strike_witches_name
      }
      extraArgs = {
        balance-similar-node-groups = true
      }
    })
  ]
}
