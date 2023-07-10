locals {
  aws_load_balancer_controller_namespace           = "aws-load-balancer-controller"
  aws_load_balancer_controller_serviceaccount_name = "aws-load-balancer-controller"
}

data "http" "aws_load_balancer_controller_crd" {
  url = "https://raw.githubusercontent.com/aws/eks-charts/93fa739be6d96e15ec1735a50ace40eefb2ec2c6/stable/aws-load-balancer-controller/crds/crds.yaml"
}

data "kubectl_file_documents" "aws_load_balancer_controller_crd" {
  content = data.http.aws_load_balancer_controller_crd.response_body
}

resource "kubectl_manifest" "aws_load_balancer_controller_crd" {
  for_each  = data.kubectl_file_documents.aws_load_balancer_controller_crd.manifests
  yaml_body = each.value
}

data "http" "aws_load_balancer_controller_iam_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.4.4/docs/install/iam_policy.json"
}

resource "aws_iam_policy" "aws_load_balancer_controller" {
  name_prefix = "${var.cluster_name}-aws-lb-controller"
  policy      = data.http.aws_load_balancer_controller_iam_policy.response_body
}

data "aws_iam_policy_document" "aws_load_balancer_controller_assume" {
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
        "system:serviceaccount:${local.aws_load_balancer_controller_namespace}:${local.aws_load_balancer_controller_serviceaccount_name}",
      ]
    }

    effect = "Allow"
  }
}

resource "aws_iam_role" "aws_load_balancer_controller" {
  name_prefix        = "${var.cluster_name}-aws-lb-controller"
  assume_role_policy = data.aws_iam_policy_document.aws_load_balancer_controller_assume.json
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  role       = aws_iam_role.aws_load_balancer_controller.name
  policy_arn = aws_iam_policy.aws_load_balancer_controller.arn
}

resource "helm_release" "aws_load_balancer_controller" {
  depends_on = [
    helm_release.cert_manager,
    kubectl_manifest.aws_load_balancer_controller_crd,
  ]

  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.4.5"

  namespace        = local.aws_load_balancer_controller_namespace
  name             = "aws-load-balancer-controller"
  create_namespace = true

  wait = false

  values = [
    yamlencode({
      clusterName = module.eks.cluster_id
      serviceAccount = {
        create = true
        name   = local.aws_load_balancer_controller_serviceaccount_name
        annotations = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.aws_load_balancer_controller.arn
        }
      }
      region            = data.aws_region.current.name
      vpcId             = var.vpc_id
      enableCertManager = true
    })
  ]
}
