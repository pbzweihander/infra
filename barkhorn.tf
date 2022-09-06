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

  tags = { Name = "barkhorn" }
}

resource "aws_ebs_volume" "barkhorn" {
  availability_zone = "ap-northeast-1a"
  size              = 100

  tags = { Name = "barkhorn" }
}

resource "aws_spot_instance_request" "barkhorn" {
  spot_price = "0.0065"
  spot_type  = "one-time"

  ami             = "ami-01b83e6ed7f173924" # Debian ebs hvm arm 20220906
  instance_type   = "t4g.small"
  security_groups = [aws_security_group.barkhorn.id]
  subnet_id       = aws_subnet.default["ap-northeast-1a"].id
  tags            = { Name = "barkhorn" }

  ebs_block_device {
    device_name           = "/dev/xvda"
    delete_on_termination = true
    tags                  = { Name = "barkhorn" }
    volume_size           = 20
  }
}

resource "aws_volume_attachment" "barkhorn" {
  device_name = "/dev/xvdh"
  volume_id   = aws_ebs_volume.barkhorn.id
  instance_id = aws_spot_instance_request.barkhorn.spot_instance_id
}

resource "aws_eip" "barkhorn" {
  instance = aws_spot_instance_request.barkhorn.spot_instance_id
}
