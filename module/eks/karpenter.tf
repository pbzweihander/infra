locals {
  karpenter_namespace           = "karpenter"
  karpenter_serviceaccount_name = "karpenter"
}

module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "~> 19.21.0"

  cluster_name = module.eks.cluster_name

  irsa_oidc_provider_arn          = module.eks.oidc_provider_arn
  irsa_namespace_service_accounts = ["${local.karpenter_namespace}:${local.karpenter_serviceaccount_name}"]

  enable_karpenter_instance_profile_creation = true

  # Attach additional IAM policies to the Karpenter node IAM role
  iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }
}

resource "helm_release" "karpenter" {
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = "0.37.0"

  namespace        = local.karpenter_namespace
  name             = "karpenter"
  create_namespace = true

  wait = false

  values = [yamlencode({
    replicas = 1
    settings = {
      clusterName           = module.eks.cluster_name
      clusterEndpoint       = module.eks.cluster_endpoint
      interruptionQueueName = module.karpenter.queue_name
    }
    serviceAccount = {
      name = local.karpenter_serviceaccount_name
      annotations = {
        "eks.amazonaws.com/role-arn" = module.karpenter.irsa_arn
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

resource "helm_release" "karpenter_crd" {
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter-crd"
  version    = "v0.33.0"

  namespace        = local.karpenter_namespace
  name             = "karpenter-crd"
  create_namespace = true

  wait = false
}

resource "kubectl_manifest" "karpenter_node_class" {
  depends_on = [
    helm_release.karpenter,
    helm_release.karpenter_crd,
  ]

  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1beta1
    kind: EC2NodeClass
    metadata:
      name: default
    spec:
      amiFamily: Bottlerocket
      role: ${module.karpenter.role_name}
      subnetSelectorTerms:
      - tags:
          karpenter.sh/discovery: ${module.eks.cluster_name}
      securityGroupSelectorTerms:
      - tags:
          karpenter.sh/discovery: ${module.eks.cluster_name}
      tags:
        karpenter.sh/discovery: ${module.eks.cluster_name}
      blockDeviceMappings:
      - deviceName: /dev/xvda
        ebs:
          volumeSize: 4Gi
          volumeType: gp3
          encrypted: true
      - deviceName: /dev/xvdb
        ebs:
          volumeSize: 50Gi
          volumeType: gp3
          encrypted: true
  YAML
}

resource "kubectl_manifest" "karpenter_node_pool" {
  depends_on = [
    helm_release.karpenter,
    helm_release.karpenter_crd,
  ]

  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1beta1
    kind: NodePool
    metadata:
      name: default
    spec:
      template:
        spec:
          nodeClassRef:
            apiVersion: karpenter.k8s.aws/v1beta1
            kind: EC2NodeClass
            name: default
          requirements:
          - key: karpenter.k8s.aws/instance-family
            operator: In
            values: ["t3a"]
          - key: "karpenter.k8s.aws/instance-size"
            operator: In
            values: ["medium", "large", "xlarge", "2xlarge"]
          - key: "topology.kubernetes.io/zone"
            operator: In
            values: ["ap-northeast-1a", "ap-northeast-1d"]
          - key: karpenter.sh/capacity-type
            operator: In
            values: ["spot"]
      disruption:
        consolidationPolicy: WhenUnderutilized
        expireAfter: 720h
  YAML
}
