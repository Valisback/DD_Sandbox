# Datadog Sandbox Environment

## Quick Start

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

## What's Included

### Current Components
- **Kubernetes Cluster**: 3-node Minikube cluster with metrics-server and dashboard
- **Datadog Agent**: Full monitoring stack with logs, metrics, and APM
- **Test Applications**: Sample nginx deployment for testing
- **Infrastructure as Code**: Terraform configuration for reproducible deployments
- **Automation Scripts**: To setup, deploy, and cleanup

### Planned Components (Future)
- Windows Virtual Machine
- Linux Ubuntu Virtual Machine
- Sample applications with instrumentation
- Network devices
- etc.

## Architecture

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

## Project Structure

```
DD_Sandbox/
├── configs/                    # Configuration files (gitignored)
│   ├── config.yaml            # Centralized Datadog configuration (API keys, features, tags)
│   ├── values.yaml            # Generated Helm values from config.yaml
│   └── *.template            # Template files for easy setup
├── terraform/                 # Infrastructure as Code
│   └── environments/dev/     # Development environment
├── kubernetes/               # Kubernetes manifests
│   ├── datadog/             # Datadog agent configurations
├── scripts/                 # Automation scripts
│   ├── setup.sh            # Initial environment setup
│   ├── deploy.sh           # Deploy the cluster
│   ├── status.sh           # Check cluster status
│   └── cleanup.sh          # Clean up everything
└── logs/                   # Deployment and status logs
```

## Prerequisites

- **macOS**: This setup is optimized for macOS (tested on M1 Macs)
- **Docker Desktop**: For container runtime

The setup script will automatically install:
- `minikube`: For Kubernetes cluster
- `kubectl`: For Kubernetes management
- `terraform`: For infrastructure provisioning
- `helm`: For package management

## Configuration

### Configuration Files

**Main config: `configs/config.yaml`**

**Infrastructure Settings (Optional): `terraform/environments/dev/terraform.tfvars`**
```hcl
# Only needed if you want to override infrastructure defaults
# node_memory   = "6144"  # Default: 4GB per node
# node_cpus     = "3"     # Default: 2 CPUs per node
```


** Deployment Workflow:**
1. Edit `configs/config.yaml` for basic settings (API keys, features, tags)
2. Run `./scripts/setup.sh` to generate `values.yaml` (or it will be auto-generated during deployment)
3. Edit `configs/values.yaml` directly for advanced Helm chart customizations
4. Deploy with `./scripts/deploy.sh` (uses `values.yaml` automatically, generating it if needed)


## Usage Examples

### Basic Operations
```bash
# Validate configuration
./scripts/validate-config.sh

# Check cluster status
./scripts/status.sh

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


## Customization

### Adding New Workloads
```bash
# Create a new deployment
kubectl create deployment my-app --image=my-image:latest

# Expose as service
kubectl expose deployment my-app --port=80 --type=NodePort
```


## Cleanup

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


## License

This project is for educational and testing purposes. Please ensure you comply with Datadog's terms of service when using their APIs and services.

## Resources

- [Datadog Documentation](https://docs.datadoghq.com/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Minikube Documentation](https://minikube.sigs.k8s.io/docs/)
- [Terraform Documentation](https://developer.hashicorp.com/terraform/docs)
