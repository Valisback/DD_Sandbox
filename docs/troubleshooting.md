# Troubleshooting Guide

This guide covers common issues and their solutions for the Datadog Sandbox environment.

## Common Issues

### 1. Cluster Issues

#### Minikube Won't Start

**Symptoms:**
- `minikube start` fails
- Timeout errors during cluster creation
- Driver-related errors

**Solutions:**

```bash
# Check minikube status and logs
minikube status
minikube logs

# Try deleting and recreating
minikube delete
minikube start --driver=docker

# For M1 Macs, ensure using docker driver
minikube start --driver=docker --memory=4096 --cpus=2

# Check Docker Desktop is running and has enough resources
docker info
```

**Resource Issues:**
```bash
# Check available resources
docker system df
docker system prune -f

# Increase Docker Desktop resources:
# Docker Desktop > Settings > Resources
# Recommended: 8GB RAM, 4 CPUs, 64GB disk
```

#### Nodes Not Ready

**Symptoms:**
- `kubectl get nodes` shows NotReady status
- Pods stuck in Pending state

**Solutions:**

```bash
# Check node conditions
kubectl describe nodes

# Check system pods
kubectl get pods -n kube-system

# Restart cluster
minikube stop
minikube start

# Check for resource constraints
kubectl top nodes
kubectl describe node minikube
```

### 2. Datadog Agent Issues

#### Agent Pods Not Starting

**Symptoms:**
- Datadog pods in CrashLoopBackOff
- Pods stuck in Pending state
- ImagePullBackOff errors

**Solutions:**

```bash
# Check pod status and events
kubectl get pods -n datadog
kubectl describe pods -n datadog

# Check logs
kubectl logs -n datadog -l app.kubernetes.io/name=datadog-agent

# Verify API keys
kubectl get secret datadog-secret -n datadog -o yaml
echo "WU9VUl9EQVRBRE9HX0FQSV9LRVlfSEVSRQ==" | base64 -d
# Should not show placeholder text

# Restart agent
kubectl rollout restart daemonset/datadog-agent -n datadog
```

#### No Metrics in Datadog

**Symptoms:**
- Cluster not visible in Datadog Infrastructure view
- No metrics flowing to Datadog dashboard

**Solutions:**

```bash
# Verify API keys are correct
kubectl get secret datadog-secret -n datadog -o jsonpath='{.data.api-key}' | base64 -d
# Compare with your actual API key

# Check agent status
kubectl exec -n datadog ds/datadog-agent -- agent status

# Check connectivity
kubectl exec -n datadog ds/datadog-agent -- agent check connectivity

# Verify site configuration
kubectl get configmap -n datadog -o yaml | grep site
```

#### Permission Issues

**Symptoms:**
- Agent can't access certain resources
- Missing metrics or logs

**Solutions:**

```bash
# Check RBAC permissions
kubectl get clusterrole datadog-agent
kubectl get clusterrolebinding datadog-agent

# Recreate RBAC resources
kubectl delete clusterrole datadog-agent
kubectl delete clusterrolebinding datadog-agent
helm upgrade --install datadog-agent datadog/datadog -n datadog -f configs/values.yaml
```

### 3. Terraform Issues

#### Terraform Init Fails

**Symptoms:**
- Provider download failures
- Lock file conflicts

**Solutions:**

```bash
cd terraform/environments/dev

# Clear Terraform cache
rm -rf .terraform
rm -f .terraform.lock.hcl

# Reinitialize
terraform init

# If behind corporate firewall
terraform init -upgrade
```

#### Terraform Apply Fails

**Symptoms:**
- Resource creation failures
- State lock issues

**Solutions:**

```bash
# Check for existing resources
minikube status
minikube profile list

# Force unlock if needed (use carefully)
terraform force-unlock LOCK_ID

# Refresh state
terraform refresh

# Target specific resources
terraform apply -target=minikube_cluster.datadog_sandbox
```

### 4. Networking Issues

#### Can't Access Services

**Symptoms:**
- Can't reach nginx test app
- Port forwarding fails

**Solutions:**

```bash
# Check service status
kubectl get services
kubectl get endpoints

# Try port forwarding
kubectl port-forward svc/nginx-test 8080:80

# Check minikube networking
minikube ip
minikube service list

# For NodePort services
minikube service nginx-test --url
```

#### DNS Resolution Issues

**Symptoms:**
- Pods can't resolve service names
- External DNS lookups fail

**Solutions:**

```bash
# Check CoreDNS
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Test DNS resolution
kubectl run test-pod --image=busybox --rm -it -- nslookup kubernetes.default

# Restart CoreDNS if needed
kubectl rollout restart -n kube-system deployment/coredns
```

### 5. Resource Issues

#### Insufficient Resources

**Symptoms:**
- Pods stuck in Pending state
- Out of memory errors
- CPU throttling

**Solutions:**

```bash
# Check resource usage
kubectl top nodes
kubectl top pods --all-namespaces

# Check resource requests and limits
kubectl describe nodes

# Adjust resource allocation
# Edit terraform/environments/dev/terraform.tfvars
node_memory = "6144"  # Increase memory
node_cpus = "3"       # Increase CPUs

# Apply changes
cd terraform/environments/dev
terraform apply
```

#### Disk Space Issues

**Symptoms:**
- Pods evicted due to disk pressure
- Image pull failures

**Solutions:**

```bash
# Check disk usage
kubectl describe nodes
docker system df

# Clean up Docker
docker system prune -a -f
docker volume prune -f

# Increase disk size
# Edit terraform.tfvars
node_disk_size = "30g"

# Apply changes
terraform apply
```

### 6. Helm Issues

#### Helm Install Fails

**Symptoms:**
- Chart installation failures
- Version conflicts

**Solutions:**

```bash
# Update Helm repositories
helm repo update

# Check chart versions
helm search repo datadog/datadog

# Uninstall and reinstall
helm uninstall datadog-agent -n datadog
helm install datadog-agent datadog/datadog -n datadog -f configs/values.yaml

# Debug installation
helm install datadog-agent datadog/datadog -n datadog -f configs/values.yaml --debug --dry-run
```

### 7. Script Issues

#### Permission Denied

**Symptoms:**
- Scripts won't execute
- Permission denied errors

**Solutions:**

```bash
# Make scripts executable
chmod +x scripts/*.sh

# Check file permissions
ls -la scripts/

# Run with bash explicitly
bash scripts/setup.sh
```

#### Environment Variables

**Symptoms:**
- Scripts can't find configuration
- Path issues

**Solutions:**

```bash
# Check current directory
pwd

# Run from project root
cd /path/to/DD_Sandbox
./scripts/setup.sh

# Check environment
echo $PATH
which docker
which kubectl
```

## Diagnostic Commands

### Cluster Diagnostics

```bash
# Overall cluster health
kubectl cluster-info
kubectl get nodes -o wide
kubectl get pods --all-namespaces
kubectl get events --sort-by=.metadata.creationTimestamp

# Minikube specific
minikube status
minikube logs
minikube ip
minikube ssh -- top
```

### Datadog Diagnostics

```bash
# Agent status
kubectl get pods -n datadog -o wide
kubectl logs -n datadog -l app.kubernetes.io/name=datadog-agent --tail=50

# Configuration
kubectl get configmaps -n datadog -o yaml
kubectl get secrets -n datadog -o yaml

# Agent health check
kubectl exec -n datadog ds/datadog-agent -- agent health
kubectl exec -n datadog ds/datadog-agent -- agent configcheck
```

### Resource Diagnostics

```bash
# Resource usage
kubectl top nodes
kubectl top pods --all-namespaces --sort-by=memory
kubectl top pods --all-namespaces --sort-by=cpu

# Detailed resource info
kubectl describe nodes
kubectl get events --field-selector type=Warning

# Docker resources
docker stats
docker system df
```

## Getting Help

### Log Files
Check the logs directory for deployment and status logs:
```bash
ls -la logs/
tail -f logs/cluster-info-*.log
```

### Verbose Logging
Enable verbose logging for debugging:
```bash
# Kubernetes
kubectl get pods -v=8

# Terraform
TF_LOG=DEBUG terraform apply

# Minikube
minikube start --v=3
```

### Support Resources
- [Datadog Support](https://docs.datadoghq.com/help/)
- [Kubernetes Troubleshooting](https://kubernetes.io/docs/tasks/debug-application-cluster/troubleshooting/)
- [Minikube Issues](https://github.com/kubernetes/minikube/issues)
- [Docker Desktop Issues](https://docs.docker.com/desktop/troubleshoot/)

### Clean Slate Approach
If all else fails, start fresh:
```bash
# Complete cleanup
./scripts/cleanup.sh

# Remove Docker images
docker system prune -a -f

# Restart Docker Desktop

# Setup from scratch
./scripts/setup.sh
# Configure credentials
./scripts/deploy.sh
``` 