.PHONY: help init plan apply destroy validate ssh logs status clean deploy-local

# Variables
TERRAFORM_DIR := infra/terraform
ANSIBLE_DIR := infra/ansible

# Colors for output
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m

help: ## Show this help message
	@echo "$(GREEN)DevOps Stage 6 - Available Commands$(NC)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""

init: ## Initialize Terraform
	@echo "$(GREEN)Initializing Terraform...$(NC)"
	cd $(TERRAFORM_DIR) && terraform init -reconfigure

plan: ## Run Terraform plan
	@echo "$(GREEN)Running Terraform plan...$(NC)"
	cd $(TERRAFORM_DIR) && terraform plan

apply: ## Apply Terraform changes
	@echo "$(GREEN)Applying Terraform changes...$(NC)"
	cd $(TERRAFORM_DIR) && terraform apply

destroy: ## Destroy all infrastructure
	@echo "$(RED)WARNING: This will destroy all infrastructure!$(NC)"
	@read -p "Are you sure? (yes/no): " confirm && [ "$$confirm" = "yes" ] && \
	cd $(TERRAFORM_DIR) && terraform destroy

validate: ## Run validation script
	@echo "$(GREEN)Running validation...$(NC)"
	cd infra && bash validate.sh

setup: ## Run automated setup
	@echo "$(GREEN)Running automated setup...$(NC)"
	cd infra && bash setup.sh

ssh: ## SSH into the server
	@echo "$(GREEN)Connecting to server...$(NC)"
	@cd $(TERRAFORM_DIR) && ssh -i ~/.ssh/id_ed25519 ubuntu@$$(terraform output -raw instance_public_ip 2>/dev/null)

logs: ## View application logs on server
	@echo "$(GREEN)Fetching logs...$(NC)"
	@cd $(TERRAFORM_DIR) && ssh -i ~/.ssh/id_ed25519 ubuntu@$$(terraform output -raw instance_public_ip 2>/dev/null) \
		"cd ~/DevOps-Stage-6 && docker compose logs --tail=50"

status: ## Check container status on server
	@echo "$(GREEN)Checking container status...$(NC)"
	@cd $(TERRAFORM_DIR) && ssh -i ~/.ssh/id_ed25519 ubuntu@$$(terraform output -raw instance_public_ip 2>/dev/null) \
		"cd ~/DevOps-Stage-6 && docker compose ps"

output: ## Show Terraform outputs
	@cd $(TERRAFORM_DIR) && terraform output

deploy-ansible: ## Run Ansible deployment manually
	@echo "$(GREEN)Running Ansible deployment...$(NC)"
	cd $(ANSIBLE_DIR) && ansible-playbook -i inventory/hosts playbook.yml

deploy-force: ## Force redeploy application
	@echo "$(GREEN)Force redeploying application...$(NC)"
	cd $(ANSIBLE_DIR) && ansible-playbook -i inventory/hosts playbook.yml -e "force_restart=true"

clean: ## Clean Terraform files
	@echo "$(YELLOW)Cleaning Terraform files...$(NC)"
	rm -rf $(TERRAFORM_DIR)/.terraform
	rm -f $(TERRAFORM_DIR)/.terraform.lock.hcl
	rm -f $(TERRAFORM_DIR)/tfplan
	rm -f $(TERRAFORM_DIR)/plan_output.txt

docker-up: ## Start containers locally
	@echo "$(GREEN)Starting containers...$(NC)"
	docker compose up -d

docker-down: ## Stop containers locally
	@echo "$(YELLOW)Stopping containers...$(NC)"
	docker compose down

docker-logs: ## View local container logs
	docker compose logs -f

docker-ps: ## List local containers
	docker compose ps

docker-build: ## Build containers locally
	@echo "$(GREEN)Building containers...$(NC)"
	docker compose build

docker-rebuild: ## Rebuild and restart containers
	@echo "$(GREEN)Rebuilding containers...$(NC)"
	docker compose up -d --build

check-prereqs: ## Check prerequisites
	@echo "$(GREEN)Checking prerequisites...$(NC)"
	@command -v terraform >/dev/null 2>&1 && echo "✓ Terraform installed" || echo "✗ Terraform not found"
	@command -v ansible >/dev/null 2>&1 && echo "✓ Ansible installed" || echo "✗ Ansible not found"
	@command -v docker >/dev/null 2>&1 && echo "✓ Docker installed" || echo "✗ Docker not found"
	@command -v aws >/dev/null 2>&1 && echo "✓ AWS CLI installed" || echo "✗ AWS CLI not found"
	@test -f $(TERRAFORM_DIR)/terraform.tfvars && echo "✓ terraform.tfvars exists" || echo "✗ terraform.tfvars not found"

fmt: ## Format Terraform files
	@echo "$(GREEN)Formatting Terraform files...$(NC)"
	cd $(TERRAFORM_DIR) && terraform fmt -recursive

lint: ## Lint Ansible playbooks
	@echo "$(GREEN)Linting Ansible playbooks...$(NC)"
	cd $(ANSIBLE_DIR) && ansible-lint playbook.yml || true

test-local: ## Test application locally
	@echo "$(GREEN)Testing local deployment...$(NC)"
	@sleep 10
	@curl -f http://localhost:80 && echo "$(GREEN)✓ Frontend responding$(NC)" || echo "$(RED)✗ Frontend not responding$(NC)"

backup: ## Backup Terraform state
	@echo "$(GREEN)Backing up Terraform state...$(NC)"
	@mkdir -p backups
	cd $(TERRAFORM_DIR) && terraform show > ../../backups/terraform-state-$$(date +%Y%m%d-%H%M%S).txt
	@echo "$(GREEN)Backup created in backups/$(NC)"

docs: ## Open documentation
	@echo "$(GREEN)Opening documentation...$(NC)"
	@cat README.md

install-deps: ## Install required dependencies (Ubuntu/Debian)
	@echo "$(GREEN)Installing dependencies...$(NC)"
	@echo "This requires sudo access..."
	@sudo apt-get update
	@sudo apt-get install -y ansible wget curl git
	@echo "$(YELLOW)Note: Install Terraform manually from https://www.terraform.io/downloads$(NC)"
