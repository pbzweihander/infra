module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.21.0"

  cluster_name    = var.cluster_name
  cluster_version = var.kubernetes_version

  cluster_endpoint_public_access = true

  cluster_addons = {
    kube-proxy = {}
    vpc-cni    = {}
    coredns = {
      configuration_values = jsonencode({
        replicaCount = 1
        computeType  = "Fargate"
        # Ensure that we fully utilize the minimum amount of resources that are supplied by
        # Fargate https://docs.aws.amazon.com/eks/latest/userguide/fargate-pod-configuration.html
        # Fargate adds 256 MB to each pod's memory reservation for the required Kubernetes
        # components (kubelet, kube-proxy, and containerd). Fargate rounds up to the following
        # compute configuration that most closely matches the sum of vCPU and memory requests in
        # order to ensure pods always have the resources that they need to run.
        resources = {
          limits = {
            cpu = "0.25"
            # We are targeting the smallest Task size of 512Mb, so we subtract 256Mb from the
            # request/limit to ensure we can fit within that task
            memory = "256M"
          }
          requests = {
            cpu = "0.25"
            # We are targeting the smallest Task size of 512Mb, so we subtract 256Mb from the
            # request/limit to ensure we can fit within that task
            memory = "256M"
          }
        }
      })
    }
  }

  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  create_aws_auth_configmap = true
  manage_aws_auth_configmap = true
  aws_auth_roles = [
    # required by karpenter
    {
      rolearn  = module.karpenter.role_arn
      username = "system:node:{{EC2PrivateDNSName}}"
      groups = [
        "system:bootstrappers",
        "system:nodes",
      ]
    },
  ]
  aws_auth_users = [
    {
      userarn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      groups  = ["system:masters"]
    },
  ]

  create_cluster_security_group = false
  create_node_security_group    = false

  fargate_profile_defaults = {
    subnet_ids = var.subnet_ids
  }

  fargate_profiles = {
    karpenter = {
      selectors = [
        { namespace = local.karpenter_namespace },
      ]
    }
    coredns = {
      selectors = [
        {
          namespace = "kube-system"
          labels = {
            "eks.amazonaws.com/component" = "coredns"
          }
        },
      ]
    }
    ondemand = {
      selectors = [
        {
          namespace = "*"
          labels = {
            "enable-fargate" = "true"
          }
        },
      ]
    }
  }

  cloudwatch_log_group_retention_in_days = 5

  tags = {
    "karpenter.sh/discovery" = var.cluster_name
  }
}
