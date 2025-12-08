#!/bin/bash

##############################################################################
# DevOps Stage 6 - Complete Setup Script
# This script sets up the entire infrastructure from scratch
##############################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

##############################################################################
# Step 1: Prerequisites Check
##############################################################################

print_info "Checking prerequisites..."

# Check Terraform
if ! command_exists terraform; then
    print_error "Terraform is not installed. Please install Terraform >= 1.0"
    exit 1
fi

TERRAFORM_VERSION=$(terraform version -json | grep -o '"terraform_version":"[^"]*' | cut -d'"' -f4)
print_info "Terraform version: $TERRAFORM_VERSION"

# Check Ansible
if ! command_exists ansible; then
    print_error "Ansible is not installed. Please install Ansible >= 2.9"
    exit 1
fi

ANSIBLE_VERSION=$(ansible --version | head -n1 | cut -d' ' -f2)
print_info "Ansible version: $ANSIBLE_VERSION"

# Check AWS CLI
if ! command_exists aws; then
    print_warning "AWS CLI is not installed. Some features may not work."
else
    print_info "AWS CLI detected"
fi

# Check Git
if ! command_exists git; then
    print_error "Git is not installed. Please install Git."
    exit 1
fi

print_info "All prerequisites met!"

##############################################################################
# Step 2: Configuration
##############################################################################

print_info "Configuration setup..."

cd "$(dirname "$0")/terraform"

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    print_warning "terraform.tfvars not found. Creating from template..."
    
    cat > terraform.tfvars << 'EOF'
# AWS Configuration
aws_region    = "eu-north-1"
instance_type = "t3.medium"

# SSH Configuration (REPLACE WITH YOUR VALUES)
ssh_public_key       = "ssh-ed25519 AAAA... your-email@example.com"
ssh_private_key_path = "~/.ssh/id_ed25519"

# Application Configuration (REPLACE WITH YOUR VALUES)
domain_name = "your-domain.com"
email       = "your-email@example.com"
EOF
    
    print_error "Please edit terraform/terraform.tfvars with your actual values and run this script again."
    exit 1
fi

print_info "Configuration file found"

##############################################################################
# Step 3: Initialize Terraform
##############################################################################

print_info "Initializing Terraform..."

terraform init -reconfigure

if [ $? -ne 0 ]; then
    print_error "Terraform initialization failed"
    exit 1
fi

print_info "Terraform initialized successfully"

##############################################################################
# Step 4: Validate Terraform Configuration
##############################################################################

print_info "Validating Terraform configuration..."

terraform validate

if [ $? -ne 0 ]; then
    print_error "Terraform validation failed"
    exit 1
fi

print_info "Terraform configuration is valid"

##############################################################################
# Step 5: Plan Infrastructure
##############################################################################

print_info "Planning infrastructure changes..."

terraform plan -out=tfplan

if [ $? -ne 0 ]; then
    print_error "Terraform plan failed"
    exit 1
fi

print_info "Terraform plan created successfully"

##############################################################################
# Step 6: Apply Infrastructure (with confirmation)
##############################################################################

echo ""
print_warning "Ready to apply Terraform changes."
read -p "Do you want to proceed? (yes/no): " CONFIRMATION

if [ "$CONFIRMATION" != "yes" ]; then
    print_info "Deployment cancelled by user"
    exit 0
fi

print_info "Applying Terraform changes..."

terraform apply tfplan

if [ $? -ne 0 ]; then
    print_error "Terraform apply failed"
    exit 1
fi

print_info "Infrastructure deployed successfully!"

##############################################################################
# Step 7: Display Outputs
##############################################################################

print_info "Deployment Summary:"
echo ""

terraform output

##############################################################################
# Step 8: Verification
##############################################################################

print_info "Verifying deployment..."

# Get instance IP
INSTANCE_IP=$(terraform output -raw instance_public_ip 2>/dev/null)

if [ -z "$INSTANCE_IP" ]; then
    print_error "Could not retrieve instance IP"
    exit 1
fi

print_info "Instance IP: $INSTANCE_IP"

# Wait for SSH
print_info "Waiting for SSH to be available..."
for i in {1..30}; do
    if ssh -i ~/.ssh/id_ed25519 -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@$INSTANCE_IP "echo 'SSH Ready'" 2>/dev/null; then
        print_info "SSH connection successful"
        break
    fi
    
    if [ $i -eq 30 ]; then
        print_error "SSH connection failed after 30 attempts"
        exit 1
    fi
    
    echo -n "."
    sleep 10
done

echo ""

# Check Docker status
print_info "Checking Docker status on server..."
ssh -i ~/.ssh/id_ed25519 -o StrictHostKeyChecking=no ubuntu@$INSTANCE_IP "docker --version && docker compose version" || {
    print_warning "Docker not fully configured yet, Ansible may still be running"
}

##############################################################################
# Step 9: Display Access Information
##############################################################################

echo ""
print_info "======================================"
print_info "Deployment Complete!"
print_info "======================================"
echo ""

APP_URL=$(terraform output -raw application_url 2>/dev/null)
SSH_COMMAND=$(terraform output -raw ssh_command 2>/dev/null)

echo -e "${GREEN}Application URL:${NC} $APP_URL"
echo -e "${GREEN}SSH Command:${NC} $SSH_COMMAND"
echo ""

print_info "To check application status on server:"
echo "  ssh -i ~/.ssh/id_ed25519 ubuntu@$INSTANCE_IP"
echo "  docker compose ps"
echo "  docker logs traefik"
echo ""

print_warning "Note: It may take a few minutes for SSL certificates to be issued and the application to be fully accessible."

##############################################################################
# Step 10: Optional - Verify Application
##############################################################################

read -p "Do you want to verify the application is responding? (yes/no): " VERIFY

if [ "$VERIFY" == "yes" ]; then
    print_info "Waiting for application to be ready (this may take a few minutes)..."
    
    for i in {1..30}; do
        if curl -f -k -s "$APP_URL" >/dev/null 2>&1; then
            print_info "Application is responding!"
            break
        fi
        
        if [ $i -eq 30 ]; then
            print_warning "Application is not responding yet, but this is normal if SSL certificates are still being issued"
        fi
        
        echo -n "."
        sleep 10
    done
    
    echo ""
fi

print_info "Setup complete! 🎉"
