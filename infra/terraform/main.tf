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

  lifecycle {
    create_before_destroy = true
  }
}

resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/inventory.tpl", {
    server_ip   = aws_instance.app_server.public_ip
    ssh_user    = var.ssh_user
  })
  filename = "${path.module}/../ansible/inventory/hosts"

  depends_on = [aws_instance.app_server]
}

resource "null_resource" "run_ansible" {
  depends_on = [local_file.ansible_inventory, aws_instance.app_server]

  triggers = {
    instance_id       = aws_instance.app_server.id
    instance_public_ip = aws_instance.app_server.public_ip
    playbook_hash     = filemd5("${path.module}/../ansible/playbook.yml")
    dependencies_hash = filemd5("${path.module}/../ansible/roles/dependencies/tasks/main.yml")
    deploy_hash       = filemd5("${path.module}/../ansible/roles/deploy/tasks/main.yml")
  }

  provisioner "local-exec" {
    command = <<-EOT
      #!/bin/bash
      set -e
      
      echo "=== Starting Deployment Process ==="
      echo "Waiting for instance to initialize (120 seconds)..."
      sleep 120
      
      # Validate SSH key
      SSH_KEY_FILE="$HOME/.ssh/id_ed25519"
      echo "Checking SSH key at: $SSH_KEY_FILE"
      
      if [ ! -f "$SSH_KEY_FILE" ]; then
        echo "ERROR: SSH private key not found at $SSH_KEY_FILE"
        echo "Please ensure SSH_PRIVATE_KEY secret is properly configured"
        exit 1
      fi
      
      # Verify key format
      if ! grep -q "BEGIN.*PRIVATE KEY" "$SSH_KEY_FILE"; then
        echo "ERROR: SSH key file does not contain a valid private key"
        echo "Key must start with '-----BEGIN OPENSSH PRIVATE KEY-----' or similar"
        exit 1
      fi
      
      # Set correct permissions
      chmod 600 "$SSH_KEY_FILE"
      echo "✓ SSH key validated and permissions set"
      
      # Test SSH connectivity
      echo "Testing SSH connection to ${aws_instance.app_server.public_ip}..."
      MAX_ATTEMPTS=30
      ATTEMPT=1
      
      while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
        if ssh -i "$SSH_KEY_FILE" \
               -o StrictHostKeyChecking=no \
               -o UserKnownHostsFile=/dev/null \
               -o ConnectTimeout=10 \
               -o BatchMode=yes \
               ${var.ssh_user}@${aws_instance.app_server.public_ip} "echo 'SSH Ready'" 2>/dev/null; then
          echo "✓ SSH connection established successfully!"
          break
        fi
        echo "Attempt $ATTEMPT/$MAX_ATTEMPTS: Waiting for SSH..."
        sleep 10
        ATTEMPT=$((ATTEMPT + 1))
      done
      
      if [ $ATTEMPT -gt $MAX_ATTEMPTS ]; then
        echo "ERROR: SSH connection failed after $MAX_ATTEMPTS attempts"
        echo "Instance IP: ${aws_instance.app_server.public_ip}"
        echo "Check security group rules and instance status"
        exit 1
      fi
      
      # Run Ansible deployment
      echo "=== Running Ansible Deployment ==="
      cd ${path.module}/../ansible
      
      if [ ! -f "playbook.yml" ]; then
        echo "ERROR: Ansible playbook not found"
        exit 1
      fi
      
      ANSIBLE_HOST_KEY_CHECKING=False \
      ANSIBLE_SSH_RETRIES=3 \
      ansible-playbook -i inventory/hosts playbook.yml \
        -e "github_username=${var.github_username}" \
        --private-key="$SSH_KEY_FILE" \
        -v
      
      echo "=== Deployment Complete ==="
    EOT
    
    interpreter = ["/bin/bash", "-c"]
  }
}
