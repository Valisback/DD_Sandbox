# Setup Guide

This guide provides detailed setup instructions for the Datadog Sandbox environment.

## Prerequisites

### System Requirements
- **Operating System**: macOS (tested on macOS Sequoia 15.5)
- **Hardware**: MacBook Pro M1 with 32GB RAM (minimum 16GB recommended)
- **Free Disk Space**: At least 50GB available

### Required Software

#### Docker Desktop
1. Download Docker Desktop for Mac from [docker.com](https://docs.docker.com/desktop/mac/install/)
2. Install and start Docker Desktop
3. Verify installation:
   ```bash
   docker --version
   docker info
   ```

#### Homebrew (Recommended)
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### Datadog Account
1. Sign up for a Datadog account at [datadoghq.com](https://www.datadoghq.com/)
2. Navigate to Organization Settings > API Keys
3. Create a new API key or copy an existing one
4. Navigate to Organization Settings > Application Keys
5. Create a new Application key or copy an existing one

## Automated Setup

The easiest way to set up the environment is using the automated setup script:

```bash
./scripts/setup.sh
```

This script will:
1. Check for required tools and install missing ones
2. Verify Docker is running
3. Create configuration files from templates
4. Initialize Terraform
5. Add Datadog Helm repository

## Manual Setup

If you prefer to set up manually or the automated script fails:

### 1. Install Required Tools

```bash
# Install minikube
brew install minikube

# Install kubectl
brew install kubectl

# Install terraform
brew install terraform

# Install helm
brew install helm

# Verify installations
minikube version
kubectl version --client
terraform version
helm version
```

### 2. Configure Terraform

```bash
cd terraform/environments/dev
terraform init
```

### 3. Add Helm Repository

```bash
helm repo add datadog https://helm.datadoghq.com
helm repo update
```

### 4. Create Configuration Files

Copy template files and configure:

```bash
# Copy configuration templates
cp configs/config.yaml.template configs/config.yaml
cp terraform/environments/dev/terraform.tfvars.template terraform/environments/dev/terraform.tfvars
```

## Configuration

### 1. Centralized Configuration

Edit `configs/config.yaml` - this is your **single source of truth** for all Datadog settings:

```yaml
# Global Datadog Configuration (used by ALL components)
datadog:
  credentials:
    api_key: "your-actual-api-key-here"
    app_key: "your-actual-app-key-here"
  site: "datadoghq.com"  # datadoghq.eu for EU, etc.
  
  # Tags applied to ALL components (K8s, VMs, future tools)
  global_tags:
    - "env:dev"
    - "project:dd-sandbox"
    - "owner:your-name"
    - "purpose:testing"
  
  # Feature flags for all components
  features:
    logs_enabled: true
    apm_enabled: true
    profiling_enabled: false
    security_agent_enabled: false

# Kubernetes-specific configuration
kubernetes:
  cluster_name: "dd-sandbox-cluster"
  additional_tags:
    - "platform:kubernetes"
    - "cluster:minikube"
  agent_settings:
    process_agent_enabled: true
    orchestrator_explorer_enabled: true

# Ready for future VM configuration!
virtual_machines:
  windows:
    hostname_prefix: "dd-win"
    additional_tags:
      - "platform:windows"
  linux:
    hostname_prefix: "dd-linux"
    additional_tags:
      - "platform:linux"
```

**Benefits of this approach:**
- ✅ **Single source of truth** - no duplicate configuration
- ✅ **Consistent settings** across all components (current K8s, future VMs)
- ✅ **Easy expansion** - just add new sections for new components
- ✅ **Global tags** automatically applied everywhere

### 2. Infrastructure Configuration (Optional)

Most infrastructure settings have sensible defaults in `terraform/environments/dev/variables.tf`. 

Only edit `terraform/environments/dev/terraform.tfvars` if you need to customize infrastructure:

```hcl
# OPTIONAL: Uncomment only if you want to override defaults
# node_memory   = "6144"  # Increase to 6GB per node if you have more RAM
# node_cpus     = "3"     # Increase CPUs if needed
```

**Note:** Datadog API keys are configured in `config.yaml`, not in Terraform!

**Terraform Pattern Explained:**
- `variables.tf` = Declares variables and sets sensible **defaults**
- `terraform.tfvars` = **Overrides** defaults with your specific values
- You only need to specify what you want to change!

### 3. Advanced Configuration (Optional)

The deployment script automatically generates `configs/values.yaml` from your `config.yaml` settings with all available Datadog Helm chart options as commented examples.

For advanced Helm configurations, you can:
- Edit `configs/values.yaml` directly after running `./scripts/setup.sh`
- Or let the deploy script auto-generate it and edit afterwards
- All Datadog Helm chart options are included as commented examples for easy customization

**Benefits:**
- **Complete visibility** of all available Helm options
- **Auto-generation** from your central config.yaml
- **Easy customization** beyond basic settings

## Verification

After setup, verify your configuration:

### 1. Check Configuration Files
```bash
# Verify API keys are set (should not show placeholder values)
grep -v "YOUR_.*_HERE" configs/config.yaml

# Check Terraform configuration
cd terraform/environments/dev
terraform validate
```

### 2. Test Docker
```bash
docker run --rm hello-world
```

### 3. Test Minikube
```bash
minikube status
# If no cluster exists yet, this is expected
```

## Resource Recommendations

### For Development (Minimum)
- **Nodes**: 3
- **Memory per node**: 2GB (6GB total)
- **CPU per node**: 1 (3 CPUs total)
- **Disk per node**: 20GB

### For Testing (Recommended)
- **Nodes**: 3
- **Memory per node**: 4GB (12GB total)
- **CPU per node**: 2 (6 CPUs total)
- **Disk per node**: 20GB

### For Heavy Workloads
- **Nodes**: 3
- **Memory per node**: 6GB (18GB total)
- **CPU per node**: 3 (9 CPUs total)
- **Disk per node**: 30GB

## Next Steps

Once setup is complete:

1. **Deploy the cluster**:
   ```bash
   ./scripts/deploy.sh
   ```

2. **Check status**:
   ```bash
   ./scripts/status.sh
   ```

3. **Access Datadog dashboard** and verify metrics are flowing

## Troubleshooting Setup Issues

### Docker Issues
```bash
# Restart Docker Desktop
# Check if virtualization is enabled in BIOS/UEFI
# Ensure Docker has enough resources allocated
```

### Permission Issues
```bash
# Ensure scripts are executable
chmod +x scripts/*.sh

# Check file permissions
ls -la configs/
```

### Homebrew Issues
```bash
# Update Homebrew
brew update

# Fix any issues
brew doctor
```

### Network Issues
```bash
# Check internet connectivity
ping google.com

# Check if corporate firewall is blocking downloads
curl -I https://github.com/
```

For more troubleshooting tips, see [troubleshooting.md](troubleshooting.md). 