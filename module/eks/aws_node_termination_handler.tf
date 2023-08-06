resource "helm_release" "aws_node_termination_handler" {
  repository = "oci://public.ecr.aws/aws-ec2/helm"
  chart      = "aws-node-termination-handler"
  version    = "0.22.0"

  namespace        = "aws-node-termination-handler"
  name             = "aws-node-termination-handler"
  create_namespace = true

  wait = false

  values = [yamlencode({
    webhookURL = var.notification_slack_webhook_url
  })]
}
