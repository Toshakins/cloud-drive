terraform {
  required_version = "~> 0.12"
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
  region = "eu-west-3"  # Paris

  default_ami           = "ami-0bfddfb1ccc3a6993"  # Amazon Linux 2
  default_instance_type = "t3a.micro"
  default_public_key    = join(".", [local.proj, "pub"]) // will return "key_name.pub"
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

  egress {
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_ebs_volume" "public_volume" {
  availability_zone   = join("", [local.region, "a"])
  size                = 5
  type                = "gp2"
  tags                = local.tags
}

resource "aws_instance" "public" {
  ami             = local.default_ami
  instance_type   = local.default_instance_type
  subnet_id       = aws_subnet.public.id
  key_name        = aws_key_pair.default.key_name
  security_groups = [aws_security_group.default.id]
  tags            = local.tags
}


