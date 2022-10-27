locals {
  strike_witches_aws_load_balancer_controller_namespace           = "aws-load-balancer-controller"
  strike_witches_aws_load_balancer_controller_serviceaccount_name = "aws-load-balancer-controller"
}

data "http" "strike_witches_aws_load_balancer_controller_crd" {
  url = "https://raw.githubusercontent.com/aws/eks-charts/93fa739be6d96e15ec1735a50ace40eefb2ec2c6/stable/aws-load-balancer-controller/crds/crds.yaml"
}

data "kubectl_file_documents" "strike_witches_aws_load_balancer_controller_crd" {
  content = data.http.strike_witches_aws_load_balancer_controller_crd.response_body
}

resource "kubectl_manifest" "strike_witches_aws_load_balancer_controller_crd" {
  for_each  = data.kubectl_file_documents.strike_witches_aws_load_balancer_controller_crd.manifests
  yaml_body = each.value
}

data "http" "strike_witches_aws_load_balancer_controller_iam_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.4.4/docs/install/iam_policy.json"
}

resource "aws_iam_policy" "strike_witches_aws_load_balancer_controller" {
  name   = "${local.strike_witches_name}-aws-load-balancer-controller"
  policy = data.http.strike_witches_aws_load_balancer_controller_iam_policy.response_body
}

data "aws_iam_policy_document" "strike_witches_aws_load_balancer_controller_assume" {
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
        "system:serviceaccount:${local.strike_witches_aws_load_balancer_controller_namespace}:${local.strike_witches_aws_load_balancer_controller_serviceaccount_name}",
      ]
    }

    effect = "Allow"
  }
}

resource "aws_iam_role" "strike_witches_aws_load_balancer_controller" {
  name               = "${local.strike_witches_name}-aws-load-balancer-controller"
  assume_role_policy = data.aws_iam_policy_document.strike_witches_aws_load_balancer_controller_assume.json
}

resource "aws_iam_role_policy_attachment" "strike_witches_aws_load_balancer_controller" {
  role       = aws_iam_role.strike_witches_aws_load_balancer_controller.name
  policy_arn = aws_iam_policy.strike_witches_aws_load_balancer_controller.arn
}

resource "helm_release" "strike_witches_aws_load_balancer_controller" {
  depends_on = [
    helm_release.strike_witches_cert_manager,
    kubectl_manifest.strike_witches_aws_load_balancer_controller_crd,
  ]

  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.4.5"

  namespace        = local.strike_witches_aws_load_balancer_controller_namespace
  name             = "aws-load-balancer-controller"
  create_namespace = true

  values = [
    yamlencode({
      clusterName = local.strike_witches_name
      serviceAccount = {
        create = true
        name   = local.strike_witches_aws_load_balancer_controller_serviceaccount_name
        annotations = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.strike_witches_aws_load_balancer_controller.arn
        }
      }
      region            = data.aws_region.current.name
      vpcId             = module.strike_witches_vpc.vpc_id
      enableCertManager = true
    })
  ]
}
