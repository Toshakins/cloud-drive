terraform {
  required_version = "~> 1.0"
  backend "s3" {
    bucket         = "terraform-aws-init-bucket"
    key            = "cloudform/terraform.tfstate"
    dynamodb_table = "TerraformLockTable"
    region         = "eu-west-3"
    profile        = "my_admin"
  }
}

provider "aws" {
  region  = local.region
  profile = "my_admin"
}

locals {
  proj   = "cloud-drive"
  region = "eu-west-3" # Paris

  default_ami           = "ami-05f0a049e7aeb407c" # Amazon Linux 2
  default_instance_type = "t3a.micro"
  default_public_key    = join(".", [local.proj, "pub"]) // will return "key_name.pub"
  drive_subdomain       = join(".", ["drive", var.apex_domain])
  tags = {
    Name = local.proj
  }
}

resource "aws_vpc" "default" {
  cidr_block = "10.0.0.0/16"
  tags       = local.tags
}

resource "aws_internet_gateway" "default" {
  vpc_id = aws_vpc.default.id
  tags   = local.tags
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.default.id
  tags   = local.tags

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.default.id
  }
}

resource "aws_route_table_association" "public" {
  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.public.id
}

resource "aws_subnet" "public" {
  cidr_block              = "10.0.1.0/24"
  vpc_id                  = aws_vpc.default.id
  map_public_ip_on_launch = true
  tags                    = local.tags
}

resource "aws_key_pair" "default" {
  key_name   = local.proj
  public_key = file(join("/", [pathexpand("~/.ssh"), local.default_public_key]))
}

resource "aws_security_group" "default" {
  vpc_id = aws_vpc.default.id
  tags   = local.tags
  name   = "Default SG"

  ingress {
    from_port   = 22
    protocol    = "tcp"
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    protocol    = "tcp"
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    protocol    = "tcp"
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_eip" "ip" {
  instance = aws_instance.public.id
  tags     = local.tags
  depends_on = [aws_instance.public]
}

resource "aws_instance" "public" {
  ami                    = local.default_ami
  instance_type          = local.default_instance_type
  subnet_id              = aws_subnet.public.id
  key_name               = aws_key_pair.default.key_name
  vpc_security_group_ids = [aws_security_group.default.id]
  root_block_device {
    volume_type = "gp3"
    volume_size = 25
    encrypted   = true
  }
  tags = local.tags

  connection {
    # The default username for our AMI
    user = "ec2-user"
    host = self.public_ip

    # The connection will use the local SSH agent for authentication.
  }

  provisioner "remote-exec" {
    inline = [
      "sudo amazon-linux-extras install -y docker"
    ]
  }

  provisioner "local-exec" {
    command = "ANSIBLE_CONFIG=ansible/ansible.cfg ansible-playbook -i \"${self.public_ip},\" -u ec2-user ansible/provision.yml"
  }
}


data "aws_route53_zone" "primary" {
  name = var.apex_domain
}


resource "aws_route53_record" "drive_A" {
  name    = local.drive_subdomain
  type    = "A"
  ttl     = 86400
  zone_id = data.aws_route53_zone.primary.zone_id
  records = [aws_eip.ip.public_ip]
}

