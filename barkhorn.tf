resource "aws_security_group" "barkhorn" {
  name   = "barkhorn"
  vpc_id = aws_vpc.default.id

  ingress {
    description = "ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "mosh"
    from_port   = 60000
    to_port     = 61000
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "barkhorn"
  }
}

resource "aws_spot_instance_request" "barkhorn" {
  spot_price = "0.0082"
  spot_type  = "one-time"

  ami             = "ami-01d49bad571fb554d" # Arch linux ebs hvm x86_64 lts 20210602
  instance_type   = "t3.small"
  security_groups = [aws_security_group.barkhorn.id]
  subnet_id       = aws_subnet.default["ap-northeast-1a"].id
  tags            = { Name = "barkhorn" }

  ebs_block_device {
    device_name           = "/dev/xvda"
    delete_on_termination = false
    tags                  = { Name = "barkhorn" }
    volume_size           = 30
  }
}
