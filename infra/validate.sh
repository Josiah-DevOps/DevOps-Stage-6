#!/bin/bash

##############################################################################
# DevOps Stage 6 - Infrastructure Validation Script
# This script validates all components of the infrastructure
##############################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASSED=0
FAILED=0

# Functions
print_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

print_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((PASSED++))
}

print_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((FAILED++))
}

print_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

##############################################################################
# Test 1: Terraform State
##############################################################################

print_test "Checking Terraform state..."
cd "$(dirname "$0")/terraform"

if terraform show > /dev/null 2>&1; then
    print_pass "Terraform state is valid"
else
    print_fail "Terraform state is invalid or not initialized"
fi

##############################################################################
# Test 2: Instance Accessibility
##############################################################################

print_test "Checking instance accessibility..."

INSTANCE_IP=$(terraform output -raw instance_public_ip 2>/dev/null || echo "")

if [ -z "$INSTANCE_IP" ]; then
    print_fail "Could not retrieve instance IP from Terraform"
    exit 1
fi

print_info "Instance IP: $INSTANCE_IP"

if ping -c 1 -W 2 "$INSTANCE_IP" > /dev/null 2>&1; then
    print_pass "Instance is reachable via ping"
else
    print_fail "Instance is not reachable via ping"
fi

##############################################################################
# Test 3: SSH Connectivity
##############################################################################

print_test "Checking SSH connectivity..."

if ssh -i ~/.ssh/id_ed25519 -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@$INSTANCE_IP "echo 'SSH OK'" > /dev/null 2>&1; then
    print_pass "SSH connection successful"
else
    print_fail "SSH connection failed"
fi

##############################################################################
# Test 4: Docker Installation
##############################################################################

print_test "Checking Docker installation..."

DOCKER_VERSION=$(ssh -i ~/.ssh/id_ed25519 -o StrictHostKeyChecking=no ubuntu@$INSTANCE_IP "docker --version" 2>/dev/null || echo "")

if [ -n "$DOCKER_VERSION" ]; then
    print_pass "Docker is installed: $DOCKER_VERSION"
else
    print_fail "Docker is not installed"
fi

##############################################################################
# Test 5: Docker Compose
##############################################################################

print_test "Checking Docker Compose..."

COMPOSE_VERSION=$(ssh -i ~/.ssh/id_ed25519 -o StrictHostKeyChecking=no ubuntu@$INSTANCE_IP "docker compose version" 2>/dev/null || echo "")

if [ -n "$COMPOSE_VERSION" ]; then
    print_pass "Docker Compose is available: $COMPOSE_VERSION"
else
    print_fail "Docker Compose is not available"
fi

##############################################################################
# Test 6: Container Status
##############################################################################

print_test "Checking container status..."

CONTAINERS=$(ssh -i ~/.ssh/id_ed25519 -o StrictHostKeyChecking=no ubuntu@$INSTANCE_IP "cd ~/DevOps-Stage-6 && docker compose ps --format '{{.Name}}: {{.Status}}'" 2>/dev/null || echo "")

if [ -n "$CONTAINERS" ]; then
    print_pass "Containers are running:"
    echo "$CONTAINERS" | while read line; do
        echo "  $line"
    done
else
    print_fail "No containers found or unable to check status"
fi

##############################################################################
# Test 7: Traefik Health
##############################################################################

print_test "Checking Traefik health..."

TRAEFIK_STATUS=$(ssh -i ~/.ssh/id_ed25519 -o StrictHostKeyChecking=no ubuntu@$INSTANCE_IP "docker ps --filter 'name=traefik' --format '{{.Status}}'" 2>/dev/null || echo "")

if echo "$TRAEFIK_STATUS" | grep -q "healthy"; then
    print_pass "Traefik is healthy"
elif echo "$TRAEFIK_STATUS" | grep -q "Up"; then
    print_info "Traefik is running but health check not configured"
    print_pass "Traefik is up"
else
    print_fail "Traefik is not healthy or not running"
fi

##############################################################################
# Test 8: Port Accessibility
##############################################################################

print_test "Checking port accessibility..."

# HTTP
if nc -z -w5 "$INSTANCE_IP" 80 2>/dev/null; then
    print_pass "Port 80 (HTTP) is accessible"
else
    print_fail "Port 80 (HTTP) is not accessible"
fi

# HTTPS
if nc -z -w5 "$INSTANCE_IP" 443 2>/dev/null; then
    print_pass "Port 443 (HTTPS) is accessible"
else
    print_fail "Port 443 (HTTPS) is not accessible"
fi

##############################################################################
# Test 9: Application Endpoint
##############################################################################

print_test "Checking application endpoint..."

DOMAIN=$(terraform output -raw application_url 2>/dev/null || echo "")

if [ -n "$DOMAIN" ]; then
    print_info "Testing: $DOMAIN"
    
    if curl -f -k -s -m 10 "$DOMAIN" > /dev/null 2>&1; then
        print_pass "Application is responding at $DOMAIN"
    else
        print_fail "Application is not responding at $DOMAIN"
    fi
else
    print_fail "Could not determine application URL"
fi

##############################################################################
# Test 10: SSL Certificate
##############################################################################

print_test "Checking SSL certificate..."

DOMAIN_NAME=$(echo "$DOMAIN" | sed 's|https://||' | sed 's|http://||')

if timeout 10 openssl s_client -connect "${DOMAIN_NAME}:443" -servername "$DOMAIN_NAME" </dev/null 2>/dev/null | grep -q "BEGIN CERTIFICATE"; then
    print_pass "SSL certificate is present"
    
    # Check expiration
    EXPIRY=$(timeout 10 openssl s_client -connect "${DOMAIN_NAME}:443" -servername "$DOMAIN_NAME" </dev/null 2>/dev/null | openssl x509 -noout -dates 2>/dev/null | grep "notAfter" | cut -d= -f2)
    
    if [ -n "$EXPIRY" ]; then
        print_info "Certificate expires: $EXPIRY"
    fi
else
    print_fail "SSL certificate is not present or could not be verified"
fi

##############################################################################
# Test 11: API Endpoints
##############################################################################

print_test "Checking API endpoints..."

# Auth API
if curl -f -k -s -m 10 "${DOMAIN}/api/auth/version" > /dev/null 2>&1; then
    print_pass "Auth API is responding"
else
    print_fail "Auth API is not responding"
fi

# Todos API (should return 401 without token)
TODOS_RESPONSE=$(curl -k -s -m 10 -w "%{http_code}" "${DOMAIN}/api/todos" -o /dev/null 2>/dev/null)
if [ "$TODOS_RESPONSE" = "401" ]; then
    print_pass "Todos API is responding (401 expected without token)"
else
    print_fail "Todos API unexpected response: $TODOS_RESPONSE"
fi

# Users API (should return 401 without token)
USERS_RESPONSE=$(curl -k -s -m 10 -w "%{http_code}" "${DOMAIN}/api/users" -o /dev/null 2>/dev/null)
if [ "$USERS_RESPONSE" = "401" ]; then
    print_pass "Users API is responding (401 expected without token)"
else
    print_fail "Users API unexpected response: $USERS_RESPONSE"
fi

##############################################################################
# Test 12: Redis Connectivity
##############################################################################

print_test "Checking Redis connectivity..."

REDIS_STATUS=$(ssh -i ~/.ssh/id_ed25519 -o StrictHostKeyChecking=no ubuntu@$INSTANCE_IP "docker exec redis redis-cli ping" 2>/dev/null || echo "")

if [ "$REDIS_STATUS" = "PONG" ]; then
    print_pass "Redis is responding"
else
    print_fail "Redis is not responding"
fi

##############################################################################
# Test 13: Ansible Inventory
##############################################################################

print_test "Checking Ansible inventory..."

cd ../ansible

if [ -f "inventory/hosts" ]; then
    print_pass "Ansible inventory exists"
    
    if grep -q "$INSTANCE_IP" inventory/hosts; then
        print_pass "Instance IP is in inventory"
    else
        print_fail "Instance IP is not in inventory"
    fi
else
    print_fail "Ansible inventory does not exist"
fi

##############################################################################
# Test 14: GitHub Workflows
##############################################################################

cd ../..

print_test "Checking GitHub workflows..."

if [ -f ".github/workflows/infrastructure.yml" ]; then
    print_pass "Infrastructure workflow exists"
else
    print_fail "Infrastructure workflow does not exist"
fi

if [ -f ".github/workflows/deploy.yml" ]; then
    print_pass "Deploy workflow exists"
else
    print_fail "Deploy workflow does not exist"
fi

##############################################################################
# Test 15: Idempotency Check
##############################################################################

print_test "Checking Terraform idempotency..."

cd infra/terraform

terraform plan -detailed-exitcode > /dev/null 2>&1
PLAN_EXIT_CODE=$?

if [ $PLAN_EXIT_CODE -eq 0 ]; then
    print_pass "No infrastructure drift detected (idempotent)"
elif [ $PLAN_EXIT_CODE -eq 2 ]; then
    print_fail "Infrastructure drift detected"
else
    print_fail "Terraform plan failed"
fi

##############################################################################
# Summary
##############################################################################

echo ""
echo "======================================"
echo "Validation Summary"
echo "======================================"
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed! ✓${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed. Please review the output above.${NC}"
    exit 1
fi
