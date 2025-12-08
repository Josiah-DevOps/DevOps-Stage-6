terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

resource "aws_key_pair" "devops_key" {
  key_name   = var.key_name
  public_key = var.ssh_public_key
}

resource "aws_security_group" "app_sg" {
  name        = "devops-stage6-sg"
  description = "Security group for DevOps Stage 6 application"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "devops-stage6-sg"
  }
}

resource "aws_instance" "app_server" {
  ami           = var.ami_id
  instance_type = var.instance_type
  key_name      = aws_key_pair.devops_key.key_name

  vpc_security_group_ids = [aws_security_group.app_sg.id]

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  user_data = <<-SCRIPT
              #!/bin/bash
              apt-get update
              apt-get install -y python3 python3-pip
              SCRIPT

  tags = {
    Name = "devops-stage6-server"
  }
}

resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/inventory.tpl", {
    server_ip   = aws_instance.app_server.public_ip
    ssh_user    = var.ssh_user
    private_key = var.ssh_private_key_path
  })
  filename = "${path.module}/../ansible/inventory/hosts"

  depends_on = [aws_instance.app_server]
}

resource "null_resource" "run_ansible" {
  depends_on = [local_file.ansible_inventory, aws_instance.app_server]

  triggers = {
    instance_id      = aws_instance.app_server.id
    playbook_hash    = filemd5("${path.module}/../ansible/playbook.yml")
    dependencies_hash = filemd5("${path.module}/../ansible/roles/dependencies/tasks/main.yml")
    deploy_hash      = filemd5("${path.module}/../ansible/roles/deploy/tasks/main.yml")
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for instance to be ready..."
      sleep 60
      cd ${path.module}/../ansible
      ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i inventory/hosts playbook.yml
    EOT
  }
}
