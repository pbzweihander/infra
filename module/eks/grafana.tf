locals {
  grafana_namespace           = "grafana"
  grafana_serviceaccount_name = "grafana"
}

data "aws_iam_policy_document" "grafana" {
  statement {
    actions = [
      "cloudwatch:DescribeAlarmsForMetric",
      "cloudwatch:DescribeAlarmHistory",
      "cloudwatch:DescribeAlarms",
      "cloudwatch:ListMetrics",
      "cloudwatch:GetMetricData",
      "cloudwatch:GetInsightRuleReport",
      "logs:DescribeLogGroups",
      "logs:GetLogGroupFields",
      "logs:StartQuery",
      "logs:StopQuery",
      "logs:GetQueryResults",
      "logs:GetLogEvents",
      "ec2:DescribeTags",
      "ec2:DescribeInstances",
      "ec2:DescribeRegions",
      "tag:GetResources",
    ]

    resources = [
      "*",
    ]

    effect = "Allow"
  }
}

resource "aws_iam_policy" "grafana" {
  name_prefix = "grafana-${var.cluster_name}-"
  policy      = data.aws_iam_policy_document.grafana.json
}

resource "aws_iam_user" "grafana_cloud" {
  name = "grafana-cloud"
}

resource "aws_iam_user_policy_attachment" "grafana_cloud" {
  user       = aws_iam_user.grafana_cloud.name
  policy_arn = aws_iam_policy.grafana.arn
}
