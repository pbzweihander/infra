resource "aws_spot_instance_request" "barkhorn" {
  spot_price = "0.0082"
  spot_type  = "one-time"

  ami             = "ami-01d49bad571fb554d" # Arch linux ebs hvm x86_64 lts 20210602
  instance_type   = "t3.small"
  security_groups = ["sg-ed2df38b"] # default
  subnet_id       = aws_subnet.default["ap-northeast-1a"].id
  tags            = { Name = "barkhorn" }

  ebs_block_device {
    device_name           = "/dev/xvda"
    delete_on_termination = false
    tags                  = { Name = "barkhorn" }
    volume_size           = 30
  }
}
