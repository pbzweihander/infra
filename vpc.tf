resource "aws_vpc" "default" {
  cidr_block = "172.31.0.0/16"
}

locals {
  subnets = {
    "${data.aws_region.current.name}a" = "172.31.16.0/20",
    "${data.aws_region.current.name}c" = "172.31.0.0/20",
    "${data.aws_region.current.name}d" = "172.31.32.0/20",
  }
}

resource "aws_subnet" "default" {
  for_each = local.subnets

  vpc_id            = aws_vpc.default.id
  availability_zone = each.key
  cidr_block        = each.value

  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "gateway" {
  vpc_id = aws_vpc.default.id
}
