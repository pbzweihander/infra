locals {
  admin            = ["pbzweihander", "Thomas Lee"]
  keybase_username = "pbzweihander"
}

resource "aws_iam_user" "admin" {
  name = local.admin[0]
  path = "/admin/"

  tags = {
    Name = local.admin[1]
  }
}

resource "aws_iam_user_policy_attachment" "admin" {
  user       = aws_iam_user.admin.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_access_key" "admin" {
  user    = aws_iam_user.admin.name
  pgp_key = "keybase:${local.keybase_username}"
}

data "aws_iam_policy" "fleet" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2SpotFleetTaggingRole"
}

resource "aws_iam_role" "fleet" {
  name               = "aws-ec2-spot-fleet-tagging-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "spotfleet.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "fleet" {
  role       = aws_iam_role.fleet.name
  policy_arn = data.aws_iam_policy.fleet.arn
}

locals {
  encrypted_admin_access_key = {
    id               = aws_iam_access_key.admin.id,
    encrypted_secret = aws_iam_access_key.admin.encrypted_secret,
  }
}

resource "aws_iam_account_password_policy" "sane_default" {
  minimum_password_length        = 16
  allow_users_to_change_password = true
}
