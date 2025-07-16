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

echo -e "${BLUE}📊 Datadog Sandbox Status${NC}"
echo "=========================="

# Check if cluster exists
echo -e "${BLUE}🔍 Checking cluster status...${NC}"
if ! minikube status &> /dev/null; then
    echo -e "${RED}❌ No Minikube cluster found or cluster is not running${NC}"
    echo ""
    echo -e "${YELLOW}💡 To deploy the cluster, run: ./scripts/deploy.sh${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Minikube cluster is running${NC}"

# Get current context
CURRENT_CONTEXT=$(kubectl config current-context 2>/dev/null || echo "none")
echo -e "${BLUE}🎯 Current kubectl context: ${CURRENT_CONTEXT}${NC}"

echo ""
echo -e "${BLUE}📊 Cluster Information${NC}"
echo "======================"
kubectl cluster-info 2>/dev/null || echo -e "${RED}❌ Unable to get cluster info${NC}"

echo ""
echo -e "${BLUE}📊 Node Status${NC}"
echo "==============="
kubectl get nodes -o wide 2>/dev/null || echo -e "${RED}❌ Unable to get node status${NC}"

echo ""
echo -e "${BLUE}📊 Namespace Status${NC}"
echo "==================="
kubectl get namespaces | grep -E "(datadog|monitoring|default)" 2>/dev/null || echo -e "${RED}❌ Unable to get namespace status${NC}"

echo ""
echo -e "${BLUE}📊 Datadog Agent Status${NC}"
echo "======================="
if kubectl get namespace datadog &> /dev/null; then
    kubectl get pods -n datadog -o wide 2>/dev/null || echo -e "${RED}❌ Unable to get Datadog pod status${NC}"
    echo ""
    echo -e "${BLUE}📊 Datadog Services${NC}"
    echo "=================="
    kubectl get services -n datadog 2>/dev/null || echo -e "${RED}❌ Unable to get Datadog service status${NC}"
    
    echo ""
    echo -e "${BLUE}📊 Datadog DaemonSet Status${NC}"
    echo "==========================="
    kubectl get daemonsets -n datadog 2>/dev/null || echo -e "${RED}❌ Unable to get Datadog DaemonSet status${NC}"
else
    echo -e "${RED}❌ Datadog namespace not found${NC}"
fi

echo ""
echo -e "${BLUE}📊 Test Applications${NC}"
echo "==================="
kubectl get deployments,services --selector=app=nginx-test 2>/dev/null || echo -e "${YELLOW}⚠️  No test applications found${NC}"

echo ""
echo -e "${BLUE}📊 Resource Usage${NC}"
echo "=================="
kubectl top nodes 2>/dev/null || echo -e "${YELLOW}⚠️  Metrics server may not be ready${NC}"

echo ""
echo -e "${BLUE}📊 Recent Events${NC}"
echo "================"
kubectl get events --sort-by=.metadata.creationTimestamp --all-namespaces | tail -10 2>/dev/null || echo -e "${RED}❌ Unable to get events${NC}"

echo ""
echo -e "${BLUE}🔍 Health Checks${NC}"
echo "================="

# Check if Datadog pods are healthy
if kubectl get namespace datadog &> /dev/null; then
    DATADOG_PODS_READY=$(kubectl get pods -n datadog --no-headers 2>/dev/null | grep -c "Running")
    DATADOG_PODS_TOTAL=$(kubectl get pods -n datadog --no-headers 2>/dev/null | wc -l)
    
    if [ "$DATADOG_PODS_READY" -eq "$DATADOG_PODS_TOTAL" ] && [ "$DATADOG_PODS_TOTAL" -gt 0 ]; then
        echo -e "${GREEN}✅ All Datadog pods are running ($DATADOG_PODS_READY/$DATADOG_PODS_TOTAL)${NC}"
    else
        echo -e "${YELLOW}⚠️  Some Datadog pods may not be ready ($DATADOG_PODS_READY/$DATADOG_PODS_TOTAL)${NC}"
    fi
else
    echo -e "${RED}❌ Datadog not deployed${NC}"
fi

# Check cluster readiness
NODES_READY=$(kubectl get nodes --no-headers 2>/dev/null | grep -c "Ready")
NODES_TOTAL=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)

if [ "$NODES_READY" -eq "$NODES_TOTAL" ] && [ "$NODES_TOTAL" -gt 0 ]; then
    echo -e "${GREEN}✅ All nodes are ready ($NODES_READY/$NODES_TOTAL)${NC}"
else
    echo -e "${YELLOW}⚠️  Some nodes may not be ready ($NODES_READY/$NODES_TOTAL)${NC}"
fi

echo ""
echo -e "${YELLOW}📋 Useful Commands${NC}"
echo "==================="
echo "• View Datadog logs:       kubectl logs -n datadog -l app.kubernetes.io/name=datadog"
echo "• Restart Datadog agent:   kubectl rollout restart daemonset/datadog-agent -n datadog"
echo "• Access dashboard:        minikube dashboard"
echo "• Port forward nginx:      kubectl port-forward svc/nginx-test 8080:80"
echo "• Detailed pod info:       kubectl describe pods -n datadog"
echo "• Check Terraform state:   cd terraform/environments/dev && terraform show"
echo ""

# Check if logs directory exists and show recent logs
if [ -d "$PROJECT_ROOT/logs" ]; then
    LATEST_LOG=$(ls -t "$PROJECT_ROOT/logs"/cluster-info-*.log 2>/dev/null | head -1)
    if [ -n "$LATEST_LOG" ]; then
        echo -e "${BLUE}📝 Latest deployment log: $(basename "$LATEST_LOG")${NC}"
    fi
fi

echo -e "${GREEN}📊 Status check completed!${NC}" 