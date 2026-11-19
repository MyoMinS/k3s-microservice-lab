terraform {
  backend "s3" {

    bucket = "terraform-state-file-store-mms"
    key = "envs/prod/terraform.tfstate"
    region = "ap-southeast-1"
    encrypt = true
    use_lockfile = true
  }
  required_version = ">= 1.6.0"
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

data "aws_ssm_parameter" "ubuntu" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

locals {
  name = var.project_name
  tags = { Project = var.project_name, ManagedBy = "terraform" }
}

resource "aws_security_group" "k3s" {
  name_prefix = "${local.name}-"
  vpc_id      = "vpc-0832ec3aea47024b2"
  description = "Single-node k3s lab"

  ingress {
    description = "SSH from operator"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }
  ingress {
    description = "Kubernetes API from operator"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }
  ingress {
    description = "HTTP Gateway"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.http_cidrs
  }
  egress {
    description = "Updates, Git, container registries and AWS APIs"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = local.tags
}


resource "aws_instance" "k3s" {
  ami                         = data.aws_ssm_parameter.ubuntu.value
  instance_type               = var.instance_type
  subnet_id                   = "subnet-0f540c350c544c129"
  vpc_security_group_ids      = [aws_security_group.k3s.id]
  iam_instance_profile        = "EC2InstanceRoleForSSM"
  key_name                    = var.key_pair_name
  user_data                   = templatefile("${path.module}/bootstrap.sh.tftpl", { public_ip = aws_eip.k3s.public_ip })
  user_data_replace_on_change = true
  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }
  # The bootstrap script and Go build must complete before the Helm stage.
  root_block_device {
    volume_size           = 15
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }
  
  tags       = merge(local.tags, { Name = "${local.name}-k3s" })
}

resource "aws_eip" "k3s" {
  domain = "vpc"
  tags   = local.tags
}

resource "aws_eip_association" "k3s" {
  instance_id   = aws_instance.k3s.id
  allocation_id = aws_eip.k3s.id
}

