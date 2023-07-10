resource "kubernetes_storage_class" "gp3" {
  depends_on = [
    helm_release.aws_ebs_csi_driver,
  ]

  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }
  parameters = {
    fstype = "ext4"
    type   = "gp3"
  }
  storage_provisioner = "ebs.csi.aws.com"
  reclaim_policy      = "Delete"
  volume_binding_mode = "WaitForFirstConsumer"
}
