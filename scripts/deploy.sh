#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo -e "${BLUE}🚀 Datadog Sandbox Deployment${NC}"
echo "================================"

# Check if setup was run


# Check if configuration file exists and is configured
CONFIG_FILE="$PROJECT_ROOT/configs/config.yaml"
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}❌ Configuration file not found. Please run './scripts/setup.sh' first.${NC}"
    exit 1
fi

if grep -q "YOUR_DATADOG_API_KEY_HERE" "$CONFIG_FILE"; then
    echo -e "${RED}❌ Please configure your Datadog API keys in configs/config.yaml${NC}"
    exit 1
fi

cd "$PROJECT_ROOT"

# Deploy Minikube cluster with Terraform
echo -e "${BLUE}🏗️  Deploying Minikube cluster...${NC}"
cd "$PROJECT_ROOT/terraform/environments/dev"

echo -e "${YELLOW}📋 Planning Terraform deployment...${NC}"
terraform plan -out=terraform.tfplan

echo -e "${YELLOW}🚀 Applying Terraform configuration...${NC}"
terraform apply terraform.tfplan

echo -e "${GREEN}✅ Minikube cluster deployed successfully!${NC}"

# Get cluster info
CLUSTER_NAME=$(terraform output -raw cluster_name)
echo -e "${BLUE}📊 Cluster Name: $CLUSTER_NAME${NC}"

# Configure kubectl context
echo -e "${BLUE}⚙️  Configuring kubectl...${NC}"
minikube profile "$CLUSTER_NAME"
kubectl config use-context "$CLUSTER_NAME"

echo -e "${GREEN}✅ kubectl configured for cluster: $CLUSTER_NAME${NC}"

# Wait for cluster to be ready
echo -e "${BLUE}⏳ Waiting for cluster to be ready...${NC}"
kubectl wait --for=condition=Ready nodes --all --timeout=300s

# Deploy Datadog Agent using Helm
echo -e "${BLUE}📦 Deploying Datadog Agent...${NC}"
cd "$PROJECT_ROOT"

# Create Datadog namespace if it doesn't exist
kubectl create namespace datadog --dry-run=client -o yaml | kubectl apply -f -

# Apply Datadog secret with API keys
SECRET_FILE="$PROJECT_ROOT/kubernetes/datadog/datadog-secret.yaml"
if [[ -f "$SECRET_FILE" ]]; then
    echo -e "${BLUE}🔐 Applying Datadog secret...${NC}"
    kubectl apply -f "$SECRET_FILE"
    echo -e "${GREEN}✅ Datadog secret applied${NC}"
else
    echo -e "${YELLOW}⚠️  Datadog secret not found, it will be created during values.yaml generation${NC}"
fi

# Check for values.yaml file
VALUES_FILE="$PROJECT_ROOT/configs/values.yaml"

if [[ ! -f "$VALUES_FILE" ]]; then
    echo -e "${YELLOW}⚠️  values.yaml not found, generating from config.yaml...${NC}"
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo -e "${RED}❌ Configuration file not found: $CONFIG_FILE${NC}"
        echo -e "${YELLOW}Run './scripts/setup.sh' first to create the configuration files${NC}"
        exit 1
    fi
    
    # Load the generate_values_yaml function and run it
    source <(grep -A 100 "generate_values_yaml()" "$PROJECT_ROOT/scripts/setup.sh" | sed '/^}/q')
    generate_values_yaml
    
    if [[ ! -f "$VALUES_FILE" ]]; then
        echo -e "${RED}❌ Failed to generate values.yaml${NC}"
        echo -e "${YELLOW}Please run './scripts/setup.sh' to regenerate configuration files${NC}"
        exit 1
    fi
fi

echo -e "${BLUE}📖 Using Helm values from values.yaml...${NC}"
echo -e "${YELLOW}💡 Tip: Edit configs/values.yaml to customize your Datadog deployment beyond the basic config.yaml settings${NC}"

# Deploy using Helm with values.yaml
echo -e "${YELLOW}🚀 Installing Datadog Agent with Helm (using values.yaml)...${NC}"

helm upgrade --install datadog-agent datadog/datadog \
    --namespace datadog \
    --values "$VALUES_FILE" \
    --wait \
    --timeout=600s

# Extract some values for display (if available)
if command -v yq &> /dev/null && [[ -f "$CONFIG_FILE" ]]; then
    DD_API_KEY=$(yq eval '.datadog.api_key' "$CONFIG_FILE" 2>/dev/null || echo "")
    DD_SITE=$(yq eval '.datadog.site' "$CONFIG_FILE" 2>/dev/null || echo "")
    CLUSTER_NAME=$(yq eval '.kubernetes.cluster_name' "$CONFIG_FILE" 2>/dev/null || echo "")
    LOGS_ENABLED=$(yq eval '.datadog.features.logs_enabled' "$CONFIG_FILE" 2>/dev/null || echo "")
    APM_ENABLED=$(yq eval '.datadog.features.apm_enabled' "$CONFIG_FILE" 2>/dev/null || echo "")
    USM_ENABLED=$(yq eval '.datadog.features.usm_enabled' "$CONFIG_FILE" 2>/dev/null || echo "")
    
    echo -e "${GREEN}✅ Datadog Agent configured with centralized settings:${NC}"
    echo -e "${BLUE}   • Configuration: $VALUES_FILE${NC}"
    [[ -n "$DD_API_KEY" ]] && echo -e "${BLUE}   • API Key: ${DD_API_KEY:0:8}...${NC}"
    [[ -n "$DD_SITE" ]] && echo -e "${BLUE}   • Site: $DD_SITE${NC}"
    [[ -n "$CLUSTER_NAME" ]] && echo -e "${BLUE}   • Cluster: $CLUSTER_NAME${NC}"
    [[ -n "$LOGS_ENABLED" ]] && echo -e "${BLUE}   • Logs: $LOGS_ENABLED | APM: $APM_ENABLED | USM: $USM_ENABLED${NC}"
else
    echo -e "${GREEN}✅ Datadog Agent configured using values file:${NC}"
    echo -e "${BLUE}   • Values file: $VALUES_FILE${NC}"
    echo -e "${BLUE}   • Config source: $CONFIG_FILE${NC}"
fi

echo -e "${GREEN}✅ Datadog Agent deployed successfully!${NC}"

# Wait for Datadog pods to be ready
echo -e "${BLUE}⏳ Waiting for Datadog Agent pods to be ready...${NC}"
kubectl wait --for=condition=Ready pods -l app.kubernetes.io/name=datadog-agent --namespace=datadog --timeout=300s

# Display cluster status
echo ""
echo -e "${GREEN}🎉 Deployment completed successfully!${NC}"
echo ""
echo -e "${BLUE}📊 Cluster Information:${NC}"
echo "======================"
kubectl cluster-info
echo ""

echo -e "${BLUE}📊 Node Status:${NC}"
echo "==============="
kubectl get nodes -o wide
echo ""

echo -e "${BLUE}📊 Datadog Agent Status:${NC}"
echo "======================="
kubectl get pods -n datadog -o wide
echo ""

echo -e "${BLUE}📊 Services:${NC}"
echo "============"
kubectl get services -n datadog
echo ""

# Create a simple test application
echo -e "${BLUE}📦 Deploying test application...${NC}"
kubectl create deployment nginx-test --image=nginx:latest --replicas=2
kubectl expose deployment nginx-test --port=80 --type=NodePort
kubectl wait --for=condition=Available deployment/nginx-test --timeout=300s

echo -e "${GREEN}✅ Test application deployed!${NC}"

# Display useful commands
echo ""
echo -e "${YELLOW}📋 Useful Commands:${NC}"
echo "==================="
echo "• View cluster status:     kubectl get nodes"
echo "• View Datadog pods:       kubectl get pods -n datadog"
echo "• View Datadog logs:       kubectl logs -n datadog -l app.kubernetes.io/name=datadog-agent"
echo "• Access Kubernetes dashboard: minikube dashboard"
echo "• Port forward to nginx:   kubectl port-forward svc/nginx-test 8080:80"
echo "• Check cluster info:      kubectl cluster-info"
echo "• Minikube status:         minikube status"
echo ""

# Save cluster info to file
echo -e "${BLUE}💾 Saving cluster information...${NC}"
{
    echo "Datadog Sandbox Cluster Information"
    echo "==================================="
    echo "Deployment Date: $(date)"
    echo "Cluster Name: $CLUSTER_NAME"
    echo ""
    echo "Cluster Info:"
    kubectl cluster-info
    echo ""
    echo "Nodes:"
    kubectl get nodes -o wide
    echo ""
    echo "Datadog Pods:"
    kubectl get pods -n datadog -o wide
} > "$PROJECT_ROOT/logs/cluster-info-$(date +%Y%m%d-%H%M%S).log"

echo -e "${GREEN}✅ Cluster information saved to logs/cluster-info-*.log${NC}"

echo ""
echo -e "${GREEN}🎉 Your Datadog Sandbox is ready!${NC}"
echo -e "${BLUE}📊 You should now see metrics and logs from your cluster in Datadog.${NC}" 