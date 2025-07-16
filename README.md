# Datadog Sandbox Environment

A comprehensive, modular sandbox environment for testing and learning Datadog features. This environment provides a complete Kubernetes cluster with Datadog monitoring integration, designed to be easily expandable for future components.

## 🚀 Quick Start

1. **Configure your environment**
   - Edit `configs/config.yaml` with all your Datadog settings (API keys, features, tags, etc.)
   - Optionally adjust infrastructure settings in `terraform/environments/dev/terraform.tfvars`

2. **Setup the environment**
   ```bash
   ./scripts/setup.sh
   ```
3. **Validate configuration (optional)**
   ```bash
   ./scripts/validate-config.sh
   ```

4. **Deploy the cluster**
   ```bash
   ./scripts/deploy.sh
   ```
   *Note: The deploy script will automatically generate `values.yaml` from `config.yaml` if it doesn't exist.*

5. **Check status**
   ```bash
   ./scripts/status.sh
   ```

## 📋 What's Included

### Current Components
- **Kubernetes Cluster**: 3-node Minikube cluster with metrics-server and dashboard
- **Datadog Agent**: Full monitoring stack with logs, metrics, and APM
- **Test Applications**: Sample nginx deployment for testing
- **Infrastructure as Code**: Terraform configuration for reproducible deployments
- **Automation Scripts**: Easy setup, deployment, and cleanup

### Planned Components (Future)
- Windows Virtual Machine
- Linux Ubuntu Virtual Machine
- Additional monitoring tools
- Sample applications with instrumentation

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Datadog Sandbox                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────────────────────────────────────────┐    │
│  │             Kubernetes Cluster                      │    │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐    │    │
│  │  │   Node 1    │ │   Node 2    │ │   Node 3    │    │    │
│  │  │             │ │             │ │             │    │    │
│  │  │ Datadog     │ │ Datadog     │ │ Datadog     │    │    │
│  │  │ Agent       │ │ Agent       │ │ Agent       │    │    │
│  │  └─────────────┘ └─────────────┘ └─────────────┘    │    │
│  │                                                     │    │
│  │  ┌─────────────────────────────────────────────┐    │    │
│  │  │         Datadog Cluster Agent               │    │    │
│  │  └─────────────────────────────────────────────┘    │    │
│  └─────────────────────────────────────────────────────┘    │
│                           │                                 │
│                           ▼                                 │
│  ┌─────────────────────────────────────────────────────┐    │
│  │                 Datadog Cloud                       │    │
│  │          (Metrics, Logs, APM, etc.)                 │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

## 📁 Project Structure

```
DD_Sandbox/
├── configs/                    # Configuration files (gitignored)
│   ├── config.yaml            # Centralized Datadog configuration (API keys, features, tags)
│   ├── values.yaml            # Generated Helm values from config.yaml
│   └── *.template            # Template files for easy setup
├── terraform/                 # Infrastructure as Code
│   ├── modules/              # Reusable Terraform modules
│   └── environments/dev/     # Development environment
├── kubernetes/               # Kubernetes manifests
│   ├── datadog/             # Datadog agent configurations (includes datadog-secret.yaml)
│   └── monitoring/          # Additional monitoring tools
├── scripts/                 # Automation scripts
│   ├── setup.sh            # Initial environment setup
│   ├── deploy.sh           # Deploy the cluster
│   ├── status.sh           # Check cluster status
│   └── cleanup.sh          # Clean up everything
├── docs/                   # Documentation
└── logs/                   # Deployment and status logs
```

## 🔧 Prerequisites

- **macOS**: This setup is optimized for macOS (tested on M1 Macs)
- **Docker Desktop**: For container runtime
- **Homebrew**: For package management (optional, but recommended)

The setup script will automatically install:
- `minikube`: For Kubernetes cluster
- `kubectl`: For Kubernetes management
- `terraform`: For infrastructure provisioning
- `helm`: For package management

## ⚙️ Configuration

### Configuration Files

**🎯 Single Source of Truth: `configs/config.yaml`**
```yaml
# Complete Datadog configuration for ALL components
datadog:
  credentials:
    api_key: "your-api-key"
    app_key: "your-app-key" 
  site: "datadoghq.com"
  
  # Global tags for all components (K8s, VMs, etc.)
  global_tags:
    - "env:dev"
    - "project:dd-sandbox"
    - "owner:your-name"
  
  # Feature flags
  features:
    logs_enabled: true
    apm_enabled: true
    profiling_enabled: false

# Component-specific settings
kubernetes:
  cluster_name: "dd-sandbox-cluster"
  additional_tags:
    - "platform:kubernetes"
    - "cluster:minikube"

# Future VM configuration ready!
virtual_machines:
  windows:
    hostname_prefix: "dd-win"
  linux:
    hostname_prefix: "dd-linux"
```

**Infrastructure Settings (Optional): `terraform/environments/dev/terraform.tfvars`**
```hcl
# Only needed if you want to override infrastructure defaults
# node_memory   = "6144"  # Default: 4GB per node
# node_cpus     = "3"     # Default: 2 CPUs per node
```

**🛠️ Advanced Helm Configuration: `configs/values.yaml`**

The setup script automatically generates a comprehensive `values.yaml` from your `config.yaml` settings. If `values.yaml` doesn't exist during deployment, it will be auto-generated. The file includes **all available Datadog Helm chart options as commented examples**:

```yaml
# Auto-generated from config.yaml
datadog:
  apiKey: "your-api-key"
  site: "datadoghq.com"
  # ... all your config.yaml settings ...

# All Datadog Helm options available for customization:
# agents:
#   resources:
#     requests:
#       cpu: 200m
#       memory: 256Mi
# 
# datadog:
#   networkMonitoring:
#     enabled: false
#   securityAgent:
#     compliance:
#       enabled: false
# ... hundreds of other options ...
```

**💡 Customization Workflow:**
1. Edit `configs/config.yaml` for basic settings (API keys, features, tags)
2. Run `./scripts/setup.sh` to generate `values.yaml` (or it will be auto-generated during deployment)
3. Edit `configs/values.yaml` directly for advanced Helm chart customizations
4. Deploy with `./scripts/deploy.sh` (uses `values.yaml` automatically, generating it if needed)

**✨ Centralized Configuration Benefits:**
- **Single source of truth** for all Datadog settings
- **Full Helm chart visibility** with all options as commented examples
- **Easy customization** beyond basic config.yaml settings
- **Consistent configuration** across Kubernetes, VMs, and future components  
- **No duplicate configuration** files to maintain
- **Easy expansion** for new environments and components

## 🎯 Usage Examples

### Basic Operations
```bash
# Validate configuration
./scripts/validate-config.sh

# Check cluster status
./scripts/status.sh

# View Datadog agent logs
kubectl logs -n datadog -l app.kubernetes.io/name=datadog-agent

# Access Kubernetes dashboard
minikube dashboard

# Port forward to test app
kubectl port-forward svc/nginx-test 8080:80
```

### Advanced Operations
```bash
# Scale test application
kubectl scale deployment nginx-test --replicas=5

# Restart Datadog agent
kubectl rollout restart daemonset/datadog-agent -n datadog

# View cluster events
kubectl get events --sort-by=.metadata.creationTimestamp
```

## 🔍 Monitoring

Once deployed, you'll see the following in your Datadog dashboard:

### Infrastructure
- **Host Map**: 3 Kubernetes nodes
- **Container Map**: All running pods and containers
- **Kubernetes Overview**: Cluster health and resource usage

### Metrics
- **System Metrics**: CPU, memory, disk, network
- **Kubernetes Metrics**: Pod/node status, resource requests/limits
- **Application Metrics**: From your test applications

### Logs
- **Container Logs**: From all pods
- **Kubernetes Events**: Cluster events and changes
- **Application Logs**: Stdout/stderr from your applications

### APM (Application Performance Monitoring)
- **Service Map**: Automatically discovered services
- **Traces**: Request traces from instrumented applications
- **Performance**: Latency, throughput, and error rates

## 🔨 Customization

### Adding New Workloads
```bash
# Create a new deployment
kubectl create deployment my-app --image=my-image:latest

# Expose as service
kubectl expose deployment my-app --port=80 --type=NodePort
```

### Modifying Datadog Configuration
1. Edit `configs/config.yaml` for basic settings OR `configs/values.yaml` for advanced options
2. Redeploy: `helm upgrade datadog-agent datadog/datadog -n datadog -f configs/values.yaml`

### Scaling the Cluster
1. Edit `terraform/environments/dev/terraform.tfvars`
2. Run: `cd terraform/environments/dev && terraform apply`

## 🧹 Cleanup

To remove everything:
```bash
./scripts/cleanup.sh
```

This will:
- Destroy the Minikube cluster (gracefully)
- Remove all Datadog agents and namespaces
- Clean up Terraform state and files (including kubeconfig)
- Clean up kubectl contexts
- Optionally remove Docker images and configuration files
- Optionally remove generated files (values.yaml, datadog-secret.yaml)

## 🚧 Troubleshooting

### Common Issues

**Cluster won't start**
```bash
# Check Docker is running
docker info

# Check minikube status
minikube status

# Check logs
minikube logs
```

**Datadog agent not reporting**
```bash
# Check agent pods
kubectl get pods -n datadog

# Check agent logs
kubectl logs -n datadog -l app.kubernetes.io/name=datadog-agent

# Wait for agent pods to be ready
kubectl wait --for=condition=Ready pods -l app.kubernetes.io/name=datadog-agent --namespace=datadog --timeout=300s

# Verify API key
kubectl get secret datadog-secret -n datadog -o yaml
```

**Resource issues**
```bash
# Check resource usage
kubectl top nodes
kubectl top pods --all-namespaces

# Adjust resources in terraform.tfvars
```

## 📚 Documentation

- [Setup Guide](docs/setup.md) - Detailed setup instructions
- [Configuration Reference](docs/configuration.md) - All configuration options
- [Troubleshooting Guide](docs/troubleshooting.md) - Common issues and solutions
- [Development Guide](docs/development.md) - Extending the sandbox

## 🤝 Contributing

This sandbox is designed to be modular and extensible. To add new components:

1. Create new modules in `terraform/modules/`
2. Add Kubernetes manifests in appropriate directories
3. Update automation scripts as needed
4. Document new features

## 📄 License

This project is for educational and testing purposes. Please ensure you comply with Datadog's terms of service when using their APIs and services.

## 🔗 Resources

- [Datadog Documentation](https://docs.datadoghq.com/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Minikube Documentation](https://minikube.sigs.k8s.io/docs/)
- [Terraform Documentation](https://developer.hashicorp.com/terraform/docs)
