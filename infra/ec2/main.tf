terraform {
  required_version = ">= 1.13, < 2.0"
  backend "s3" {}
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  assume_role {
    role_arn = var.provision_role_arn
  }
  default_tags {
    tags = { Project = "disaster-party", Stage = var.stage, ManagedBy = "terraform" }
  }
}

locals {
  name = "disaster-party-${var.stage}"
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_vpc" "game" {
  cidr_block           = "10.42.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = local.name }
}

resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.game.id
  cidr_block        = "10.42.1.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]
  tags              = { Name = "${local.name}-public" }
}

resource "aws_internet_gateway" "game" {
  vpc_id = aws_vpc.game.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.game.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.game.id
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "game" {
  name   = local.name
  vpc_id = aws_vpc.game.id
}

resource "aws_vpc_security_group_ingress_rule" "web" {
  for_each          = toset(["80", "443"])
  security_group_id = aws_security_group.game.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = tonumber(each.value)
  to_port           = tonumber(each.value)
  description       = "HTTPS and ACME HTTP challenge/redirect"
}

resource "aws_vpc_security_group_ingress_rule" "game" {
  security_group_id = aws_security_group.game.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "udp"
  from_port         = 29810
  to_port           = 29811
  description       = "Two managed rooms; no public discovery backend port"
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.game.id
  cidr_ipv4         = var.operator_ipv4_cidr
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  description       = "Single operator IP only"
}

resource "aws_vpc_security_group_egress_rule" "outbound" {
  security_group_id = aws_security_group.game.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# Runtime identity is separate from the operator's provisioning identity.
# SSM only: the game has no S3, EC2, IAM or DNS management permissions.
resource "aws_iam_role" "runtime" {
  name = "${local.name}-runtime"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.runtime.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "runtime" {
  name = "${local.name}-runtime"
  role = aws_iam_role.runtime.name
}

resource "aws_instance" "game" {
  ami                         = coalesce(var.ami_id, data.aws_ami.ubuntu.id)
  instance_type               = "t3.small" # x86_64, 2 vCPU / 2 GiB; reprofile before increasing room limits.
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.game.id]
  associate_public_ip_address = false
  key_name                    = var.ssh_key_name
  iam_instance_profile        = aws_iam_instance_profile.runtime.name
  user_data                   = templatefile("${path.module}/bootstrap.sh.tftpl", { domain = var.domain })
  user_data_replace_on_change = true
  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }
  root_block_device {
    volume_type = "gp3"
    volume_size = 16
    encrypted   = true
  }
  credit_specification {
    cpu_credits = "standard" # Avoid unlimited-credit surcharges; monitor throttling.
  }
  tags       = { Name = local.name }
  depends_on = [aws_route_table_association.public, aws_iam_role_policy_attachment.ssm]
}

resource "aws_eip" "game" {
  domain = "vpc"
  tags   = { Name = local.name }
}

resource "aws_eip_association" "game" {
  instance_id   = aws_instance.game.id
  allocation_id = aws_eip.game.id
}

output "public_ip" {
  value = aws_eip.game.public_ip
}

output "room_service_url" {
  value = "https://${var.domain}"
}

output "instance_id" {
  value = aws_instance.game.id
}

output "dns_record" {
  value = { type = "A", name = var.domain, value = aws_eip.game.public_ip }
}
