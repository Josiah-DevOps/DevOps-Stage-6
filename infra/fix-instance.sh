#!/bin/bash

# Fix Terraform State - Destroy and Recreate Instance
# Use this when the instance exists but has no public IP

echo "🔧 Fixing infrastructure state..."
echo ""

cd "$(dirname "$0")/terraform" || exit 1

# Check if we're in the right directory
if [ ! -f "main.tf" ]; then
    echo "❌ Error: main.tf not found. Are you in the infra directory?"
    exit 1
fi

echo "📋 Current instance state:"
terraform state show aws_instance.app_server 2>/dev/null | grep -E "(id|public_ip|instance_type)" || echo "No instance found"
echo ""

echo "⚠️  This will destroy and recreate the EC2 instance."
echo "⚠️  This is necessary because the instance lost its public IP."
read -p "Continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "❌ Aborted"
    exit 0
fi

echo ""
echo "🗑️  Step 1: Destroying the problematic instance..."
terraform destroy -target=aws_instance.app_server -target=null_resource.run_ansible -target=local_file.ansible_inventory -auto-approve

echo ""
echo "✨ Step 2: Recreating infrastructure with proper configuration..."
terraform apply -auto-approve

echo ""
echo "✅ Done! Your instance should now have a public IP."
echo ""
echo "📊 New instance details:"
terraform output -json | jq -r '.instance_public_ip.value as $ip | .ssh_command.value as $ssh | "Public IP: \($ip)\nSSH Command: \($ssh)"'
