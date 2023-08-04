locals {
  karpenter_namespace           = "karpenter"
  karpenter_serviceaccount_name = "karpenter"
}

data "aws_iam_policy_document" "karpenter" {
  statement {
    actions = [
      "ssm:GetParameter",
      "ec2:DescribeImages",
      "ec2:RunInstances",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeLaunchTemplates",
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeInstanceTypeOfferings",
      "ec2:DescribeAvailabilityZones",
      "ec2:DeleteLaunchTemplate",
      "ec2:CreateTags",
      "ec2:CreateLaunchTemplate",
      "ec2:CreateFleet",
      "ec2:DescribeSpotPriceHistory",
      "pricing:GetProducts",
    ]
    resources = ["*"]
    effect    = "Allow"
  }

  statement {
    condition {
      test     = "StringLike"
      variable = "ec2:ResourceTag/karpenter.sh/provisioner-name"
      values   = ["*"]
    }
    actions = [
      "ec2:TerminateInstances",
    ]
    resources = ["*"]
    effect    = "Allow"
  }

  statement {
    actions = [
      "iam:PassRole",
    ]
    resources = [for group in module.eks.eks_managed_node_groups : group.iam_role_arn]
    effect    = "Allow"
  }

  statement {
    actions = [
      "eks:DescribeCluster",
    ]
    resources = [
      module.eks.cluster_arn,
    ]
    effect = "Allow"
  }
}

resource "aws_iam_policy" "karpenter" {
  name_prefix = "${var.cluster_name}-karpenter-"
  policy      = data.aws_iam_policy_document.karpenter.json
}

data "aws_iam_policy_document" "karpenter_assume" {
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
        "system:serviceaccount:${local.karpenter_namespace}:${local.karpenter_serviceaccount_name}",
      ]
    }

    effect = "Allow"
  }
}

resource "aws_iam_role" "karpenter" {
  name_prefix        = "${var.cluster_name}-karpenter"
  assume_role_policy = data.aws_iam_policy_document.karpenter_assume.json
}

resource "aws_iam_role_policy_attachment" "karpenter" {
  role       = aws_iam_role.karpenter.name
  policy_arn = aws_iam_policy.karpenter.arn
}

resource "aws_iam_instance_profile" "karpenter" {
  name = "${var.cluster_name}-karpenter"
  role = [for group in module.eks.eks_managed_node_groups : group.iam_role_name][0]
}

resource "helm_release" "karpenter" {
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = "v0.29.2"

  namespace        = local.karpenter_namespace
  name             = "karpenter"
  create_namespace = true

  wait = false

  values = [yamlencode({
    settings = {
      aws = {
        defaultInstanceProfile = aws_iam_instance_profile.karpenter.name
        clusterName            = var.cluster_name
      }
    }
    serviceAccount = {
      name = local.karpenter_serviceaccount_name
      annotations = {
        "eks.amazonaws.com/role-arn" = aws_iam_role.karpenter.arn
      }
    }
    controller = {
      resources = {
        requests = {
          cpu    = "1"
          memory = "1Gi"
        }
        limit = {
          cpu    = "1"
          memory = "1Gi"
        }
      }
    }
  })]
}

resource "kubectl_manifest" "karpenter_node_template" {
  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1alpha1
    kind: AWSNodeTemplate
    metadata:
      name: default
    spec:
      subnetSelector:
        karpenter.sh/discovery: ${var.cluster_name}
      securityGroupSelector:
        aws:eks:cluster-name: ${var.cluster_name}
YAML

  depends_on = [
    helm_release.karpenter,
  ]
}

resource "kubectl_manifest" "karpenter_provisioner" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1alpha5
    kind: Provisioner
    metadata:
      name: default
    spec:
      requirements:
      - key: "karpenter.k8s.aws/instance-category"
        operator: In
        values: ["t"]
      - key: "karpenter.k8s.aws/instance-family"
        operator: In
        values: ["t3a"]
      - key: karpenter.sh/capacity-type
        operator: In
        values: ["spot"]
      limits:
        resources:
          cpu: 1000
      consolidation:
        enabled: true
      providerRef:
        name: default
  YAML

  depends_on = [
    helm_release.karpenter,
    kubectl_manifest.karpenter_node_template,
  ]
}
