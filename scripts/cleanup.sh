#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo -e "${BLUE}🧹 Datadog Sandbox Cleanup${NC}"
echo "=========================="

# Ask for confirmation
echo -e "${YELLOW}⚠️  This will destroy the entire Datadog sandbox environment!${NC}"
echo -e "${YELLOW}⚠️  This includes:${NC}"
echo "   • Minikube cluster and all workloads"
echo "   • All data in the cluster"
echo "   • Datadog agent and monitoring data"
echo ""
read -p "Are you sure you want to continue? (y/N): " confirm

if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}✅ Cleanup cancelled${NC}"
    exit 0
fi

echo ""
echo -e "${BLUE}🧹 Starting cleanup process...${NC}"

# Save cluster info before destroying
if minikube status &> /dev/null; then
    echo -e "${BLUE}💾 Saving final cluster state...${NC}"
    {
        echo "Final Cluster State Before Cleanup"
        echo "=================================="
        echo "Cleanup Date: $(date)"
        echo ""
        echo "Cluster Info:"
        kubectl cluster-info 2>/dev/null || echo "Unable to get cluster info"
        echo ""
        echo "Nodes:"
        kubectl get nodes -o wide 2>/dev/null || echo "Unable to get nodes"
        echo ""
        echo "All Pods:"
        kubectl get pods --all-namespaces -o wide 2>/dev/null || echo "Unable to get pods"
        echo ""
        echo "Datadog Pods:"
        kubectl get pods -n datadog -o wide 2>/dev/null || echo "No Datadog pods found"
    } > "$PROJECT_ROOT/logs/final-state-$(date +%Y%m%d-%H%M%S).log"
    echo -e "${GREEN}✅ Final state saved to logs/final-state-*.log${NC}"
fi

# Remove Datadog Helm deployment
echo -e "${BLUE}🗑️  Removing Datadog Agent...${NC}"
if kubectl get namespace datadog &> /dev/null; then
    helm uninstall datadog-agent --namespace datadog 2>/dev/null || echo -e "${YELLOW}⚠️  Helm release not found or already removed${NC}"
    
    # Wait a moment for helm cleanup to complete, then remove namespace
    sleep 5
    kubectl delete namespace datadog 2>/dev/null || echo -e "${YELLOW}⚠️  Datadog namespace not found${NC}"
    echo -e "${GREEN}✅ Datadog Agent removed${NC}"
else
    echo -e "${YELLOW}⚠️  Datadog namespace not found${NC}"
fi

# Remove test applications
echo -e "${BLUE}🗑️  Removing test applications...${NC}"
kubectl delete deployment nginx-test --ignore-not-found=true 2>/dev/null
kubectl delete service nginx-test --ignore-not-found=true 2>/dev/null
echo -e "${GREEN}✅ Test applications removed${NC}"

# Get cluster name for deletion
CLUSTER_NAME=""
if [ -f "$PROJECT_ROOT/terraform/environments/dev/terraform.tfstate" ]; then
    cd "$PROJECT_ROOT/terraform/environments/dev"
    CLUSTER_NAME=$(terraform output -raw cluster_name 2>/dev/null || echo "")
fi

# If we couldn't get the name from Terraform, try to get it from minikube
if [ -z "$CLUSTER_NAME" ]; then
    CLUSTER_NAME=$(minikube profile list -o json 2>/dev/null | jq -r '.valid[0].Name' 2>/dev/null || echo "")
fi

# Destroy Terraform infrastructure
echo -e "${BLUE}🗑️  Destroying Terraform infrastructure...${NC}"
cd "$PROJECT_ROOT/terraform/environments/dev"

if [ -f "terraform.tfstate" ]; then
    echo -e "${YELLOW}🚀 Running terraform destroy...${NC}"
    terraform destroy -auto-approve
    echo -e "${GREEN}✅ Terraform infrastructure destroyed${NC}"
else
    echo -e "${YELLOW}⚠️  No Terraform state found${NC}"
fi

# Force delete minikube cluster if it still exists
echo -e "${BLUE}🗑️  Ensuring Minikube cluster is deleted...${NC}"
if [ -n "$CLUSTER_NAME" ]; then
    minikube delete --profile "$CLUSTER_NAME" 2>/dev/null || echo -e "${YELLOW}⚠️  Cluster already deleted or not found${NC}"
else
    # Try to delete any minikube clusters
    minikube delete 2>/dev/null || echo -e "${YELLOW}⚠️  No minikube clusters found${NC}"
fi

echo -e "${GREEN}✅ Minikube cluster removed${NC}"

# Clean up Terraform files
echo -e "${BLUE}🧹 Cleaning up Terraform files...${NC}"
cd "$PROJECT_ROOT/terraform/environments/dev"
rm -f terraform.tfplan terraform.tfplan.* .terraform.lock.hcl 2>/dev/null
rm -f kubeconfig-* 2>/dev/null
rm -rf .terraform/ 2>/dev/null
echo -e "${GREEN}✅ Terraform files cleaned${NC}"

# Clean up kubectl contexts
echo -e "${BLUE}🧹 Cleaning up kubectl contexts...${NC}"
if [ -n "$CLUSTER_NAME" ]; then
    kubectl config delete-context "$CLUSTER_NAME" 2>/dev/null || echo -e "${YELLOW}⚠️  Context not found${NC}"
    kubectl config delete-cluster "$CLUSTER_NAME" 2>/dev/null || echo -e "${YELLOW}⚠️  Cluster not found in kubeconfig${NC}"
    kubectl config delete-user "$CLUSTER_NAME" 2>/dev/null || echo -e "${YELLOW}⚠️  User not found in kubeconfig${NC}"
fi
echo -e "${GREEN}✅ kubectl contexts cleaned${NC}"

# Optional: Clean up Docker images
echo ""
echo -e "${YELLOW}🐳 Docker Image Cleanup${NC}"
echo "======================"
read -p "Do you want to clean up Datadog-related Docker images? (y/N): " cleanup_docker

if [[ "$cleanup_docker" =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}🧹 Removing Datadog Docker images...${NC}"
    docker images | grep -E "(datadog|gcr.io/datadoghq)" | awk '{print $3}' | xargs docker rmi -f 2>/dev/null || echo -e "${YELLOW}⚠️  No Datadog images found${NC}"
    
    echo -e "${BLUE}🧹 Cleaning up unused Docker resources...${NC}"
    docker system prune -f 2>/dev/null || echo -e "${YELLOW}⚠️  Docker cleanup failed${NC}"
    echo -e "${GREEN}✅ Docker images cleaned${NC}"
fi

# Optional: Remove configuration files
echo ""
echo -e "${YELLOW}📝 Configuration Cleanup${NC}"
echo "========================"
echo -e "${YELLOW}⚠️  The following files contain your configuration and will be preserved:${NC}"
echo "   • configs/config.yaml (Datadog settings, API keys, features, tags)"
echo "   • configs/values.yaml (generated Helm values from config.yaml)"
echo "   • kubernetes/datadog/datadog-secret.yaml (Kubernetes secret with API keys)"
echo "   • terraform/environments/dev/terraform.tfvars (infrastructure settings)"
echo ""
read -p "Do you want to remove these configuration files? (y/N): " cleanup_configs

if [[ "$cleanup_configs" =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}🗑️  Removing configuration files...${NC}"
    rm -f "$PROJECT_ROOT/configs/config.yaml" 2>/dev/null
    rm -f "$PROJECT_ROOT/configs/values.yaml" 2>/dev/null
    rm -f "$PROJECT_ROOT/configs/secrets.yaml" 2>/dev/null  # Remove legacy file if it exists
    rm -f "$PROJECT_ROOT/kubernetes/datadog/datadog-secret.yaml" 2>/dev/null
    rm -f "$PROJECT_ROOT/terraform/environments/dev/terraform.tfvars" 2>/dev/null
    echo -e "${GREEN}✅ Configuration files removed${NC}"
    echo -e "${YELLOW}⚠️  You'll need to run './scripts/setup.sh' before deploying again${NC}"
fi

echo ""
echo -e "${GREEN}🎉 Cleanup completed successfully!${NC}"
echo ""
echo -e "${BLUE}📊 Summary:${NC}"
echo "==========="
echo "• Minikube cluster: Deleted"
echo "• Datadog Agent: Removed"
echo "• Test applications: Removed"
echo "• Terraform state: Destroyed"
echo "• Terraform files: Cleaned (including kubeconfig)"
echo "• kubectl contexts: Cleaned"
if [[ "$cleanup_docker" =~ ^[Yy]$ ]]; then
    echo "• Docker images: Cleaned"
fi
if [[ "$cleanup_configs" =~ ^[Yy]$ ]]; then
    echo "• Configuration files: Removed"
else
    echo "• Configuration files: Preserved"
fi

echo ""
echo -e "${BLUE}📝 Log files preserved in logs/ directory${NC}"
echo -e "${YELLOW}💡 To redeploy, run: ./scripts/setup.sh && ./scripts/deploy.sh${NC}" 