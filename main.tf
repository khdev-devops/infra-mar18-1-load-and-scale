terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Hämta default VPC
data "aws_vpc" "default" {
  default = true
}

# Hämta alla publika subnät i default VPC
data "aws_subnets" "public_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "map-public-ip-on-launch"
    values = ["true"]
  }
}

# lokala variabler för de två första publika subnäten
locals {
  sorted_public_subnets = sort(data.aws_subnets.public_subnets.ids)
  first_public_subnet  = length(local.sorted_public_subnets) > 0 ? local.sorted_public_subnets[0] : null
  second_public_subnet = length(local.sorted_public_subnets) > 1 ? local.sorted_public_subnets[1] : null
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*"]
  }
}

resource "aws_key_pair" "deployer_key" {
  key_name   = "mar18-tofu"
  public_key = file(var.public_key_path)
}

# 2 st manuella ec2-instanser

resource "aws_instance" "mar18_webserver_1" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  subnet_id     = local.first_public_subnet
  key_name      = aws_key_pair.deployer_key.key_name
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  user_data = file("${path.module}/files/ec2_install.sh")

  tags = {
    Name = "mar18-opentofu-webserver-1"
  }
}

resource "aws_instance" "mar18_webserver_2" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  subnet_id     = local.second_public_subnet
  key_name      = aws_key_pair.deployer_key.key_name
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  user_data = file("${path.module}/files/ec2_install.sh")

  tags = {
    Name = "mar18-opentofu-webserver-2"
  }
}

resource "aws_security_group" "web_sg" {
  name        = "web_sg"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.trusted_ip_for_ssh]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]  # Tillåter all trafik ut
  }
}

resource "aws_security_group" "alb_sg" {
  name        = "alb_sg"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Tillåter webb-trafik från hela internet in
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Launch Template för Auto Scaling
resource "aws_launch_template" "web_lt" {
  name          = "mar18-web-lt"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  key_name      = aws_key_pair.deployer_key.key_name

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.web_sg.id]
  }

  user_data = base64encode(file("${path.module}/files/ec2_install.sh"))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "mar18-auto-web"
    }
  }
}
