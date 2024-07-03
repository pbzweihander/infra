locals {
  aws_ebs_csi_driver_namespace           = "aws-ebs-csi-driver"
  aws_ebs_csi_driver_serviceaccount_name = "aws-ebs-csi-driver"
}

data "aws_iam_policy_document" "aws_ebs_csi_driver_assume" {
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
        "system:serviceaccount:${local.aws_ebs_csi_driver_namespace}:${local.aws_ebs_csi_driver_serviceaccount_name}",
      ]
    }

    effect = "Allow"
  }
}

resource "aws_iam_role" "aws_ebs_csi_driver" {
  name_prefix        = "${var.cluster_name}-aws-ebs-csi-driver"
  assume_role_policy = data.aws_iam_policy_document.aws_ebs_csi_driver_assume.json
}

resource "aws_iam_role_policy_attachment" "aws_ebs_csi_driver" {
  role       = aws_iam_role.aws_ebs_csi_driver.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "helm_release" "aws_ebs_csi_driver" {
  repository = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
  chart      = "aws-ebs-csi-driver"
  version    = "2.32.0"

  namespace        = local.aws_ebs_csi_driver_namespace
  name             = "aws-ebs-csi-driver"
  create_namespace = true

  wait = false

  values = [yamlencode({
    controller = {
      k8sTagClusterId = module.eks.cluster_name
      serviceAccount = {
        name = local.aws_ebs_csi_driver_serviceaccount_name
        annotations = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.aws_ebs_csi_driver.arn
        }
      }
    }
  })]
}
