#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# File paths
CONFIG_FILE="$PROJECT_ROOT/configs/config.yaml"
VALUES_FILE="$PROJECT_ROOT/configs/values.yaml"

echo -e "${BLUE}🚀 Datadog Sandbox Setup${NC}"
echo "=============================="

# Function to check if command exists
check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo -e "${RED}❌ $1 is not installed${NC}"
        return 1
    else
        echo -e "${GREEN}✅ $1 is installed${NC}"
        return 0
    fi
}

# Function to install Homebrew packages
install_with_brew() {
    if ! command -v brew &> /dev/null; then
        echo -e "${YELLOW}⚠️  Homebrew not found. Please install Homebrew first:${NC}"
        echo "   /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        exit 1
    fi
    
    echo -e "${YELLOW}📦 Installing $1 with Homebrew...${NC}"
    brew install "$1"
}

echo -e "${BLUE}🔍 Checking prerequisites...${NC}"

# Check for required tools
MISSING_TOOLS=()

if ! check_command "docker"; then
    MISSING_TOOLS+=("docker")
fi

if ! check_command "minikube"; then
    MISSING_TOOLS+=("minikube")
fi

if ! check_command "kubectl"; then
    MISSING_TOOLS+=("kubectl")
fi

if ! check_command "terraform"; then
    MISSING_TOOLS+=("terraform")
fi

if ! check_command "helm"; then
    MISSING_TOOLS+=("helm")
fi

# Check for yq (optional but recommended)
if ! check_command "yq"; then
    echo -e "${YELLOW}⚠️  yq not found (optional but recommended for better YAML parsing)${NC}"
    read -p "Install yq for better YAML parsing? (y/N): " install_yq
    if [[ "$install_yq" =~ ^[Yy]$ ]]; then
        MISSING_TOOLS+=("yq")
    fi
fi

# Install missing tools
if [ ${#MISSING_TOOLS[@]} -ne 0 ]; then
    echo -e "${YELLOW}⚠️  Some tools are missing. Installing...${NC}"
    for tool in "${MISSING_TOOLS[@]}"; do
        case "$tool" in
            "docker")
                echo -e "${YELLOW}Please install Docker Desktop for Mac from: https://docs.docker.com/desktop/mac/install/${NC}"
                echo "After installation, start Docker Desktop and come back to run this script again."
                exit 1
                ;;
            "minikube")
                install_with_brew "minikube"
                ;;
            "kubectl")
                install_with_brew "kubectl"
                ;;
            "terraform")
                install_with_brew "terraform"
                ;;
            "helm")
                install_with_brew "helm"
                ;;
            "yq")
                install_with_brew "yq"
                ;;
        esac
    done
fi

echo -e "${GREEN}✅ All prerequisites are installed!${NC}"

# Check Docker is running
echo -e "${BLUE}🔍 Checking Docker...${NC}"
if ! docker info &> /dev/null; then
    echo -e "${RED}❌ Docker is not running. Please start Docker Desktop and try again.${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Docker is running${NC}"

# Setup configuration files
echo -e "${BLUE}⚙️  Setting up configuration files...${NC}"

# Copy template files if they don't exist
copy_if_not_exists() {
    local template_file="$1"
    local target_file="$2"
    
    if [ ! -f "$target_file" ]; then
        echo -e "${YELLOW}📝 Creating $target_file from template${NC}"
        cp "$template_file" "$target_file"
        echo -e "${YELLOW}⚠️  Please edit $target_file and add your Datadog API keys${NC}"
    else
        echo -e "${GREEN}✅ $target_file already exists${NC}"
    fi
}

cd "$PROJECT_ROOT"

# Copy configuration templates
copy_if_not_exists "configs/config.yaml.template" "configs/config.yaml"
copy_if_not_exists "terraform/environments/dev/terraform.tfvars.template" "terraform/environments/dev/terraform.tfvars"

# Generate values.yaml from config.yaml and values.yaml.template
generate_values_yaml() {
    log_info "Generating values.yaml from config.yaml..."
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "config.yaml not found. Please create it from config.yaml.template"
        return 1
    fi
    
    local template_file="$PROJECT_ROOT/configs/values.yaml.template"
    if [[ ! -f "$template_file" ]]; then
        log_error "values.yaml.template not found"
        return 1
    fi
    
    # Check if yq is installed for YAML processing
    if ! command -v yq &> /dev/null; then
        log_warn "yq not found. Installing yq for YAML processing..."
        if [[ "$OSTYPE" == "darwin"* ]]; then
            brew install yq
        else
            log_error "Please install yq for YAML processing"
            return 1
        fi
    fi
    
    # Read values from config.yaml
    local api_key=$(yq eval '.datadog.api_key' "$CONFIG_FILE")
    local app_key=$(yq eval '.datadog.app_key' "$CONFIG_FILE")
    
    # Validate required fields
    if [[ "$api_key" == "null" || "$api_key" == "" ]]; then
        log_error "Datadog API key is required in config.yaml"
        return 1
    fi
    
    if [[ "$app_key" == "null" || "$app_key" == "" ]]; then
        log_error "Datadog App key is required in config.yaml"
        return 1
    fi
    
    # Copy template and process each placeholder
    cp "$template_file" "$VALUES_FILE"
    
    # Function to replace template placeholders
    replace_placeholder() {
        local placeholder="$1"
        local config_path="$2"
        local default_value="$3"
        
        local value=$(yq eval "$config_path" "$CONFIG_FILE" 2>/dev/null)
        if [[ "$value" == "null" || "$value" == "" ]]; then
            value="$default_value"
        fi
        
        # Use a more robust replacement method with perl
        perl -i.bak -pe "s/\Q$placeholder\E/$value/g" "$VALUES_FILE"
    }
    
    # Function to replace template placeholders with YAML array
    replace_yaml_array_placeholder() {
        local placeholder="$1"
        local config_path="$2"
        
        # Create a temporary file with the formatted tags
        local temp_tags_file=$(mktemp)
        
        # Extract tags and format as YAML array with proper indentation
        while IFS= read -r tag; do
            if [[ -n "$tag" ]]; then
                echo "    - \"${tag}\"" >> "$temp_tags_file"
            fi
        done < <(yq eval "$config_path[]" "$CONFIG_FILE" 2>/dev/null)
        
        # Use perl for the replacement to handle multiline content properly
        if [[ -s "$temp_tags_file" ]]; then
            local tags_content=$(cat "$temp_tags_file")
            # Ensure we replace the entire placeholder and maintain proper line structure
            perl -i.bak -pe "BEGIN{undef $/;} s/\Q$placeholder\E/\n$tags_content/smg" "$VALUES_FILE"
        fi
        
        rm -f "$temp_tags_file"
    }
    
    # Replace all placeholders found in the template
    replace_placeholder "{{ .datadog.site }}" ".datadog.site" "datadoghq.com"
    replace_placeholder "{{ .kubernetes.cluster_name }}" ".kubernetes.cluster_name" "dd-sandbox"
    
    # Handle tags specially (YAML array)
    replace_yaml_array_placeholder "{{ .datadog.tags | toYaml | nindent 4 }}" ".datadog.tags"
    
    # APM settings
    replace_placeholder "{{ .datadog.features.apm_enabled }}" ".datadog.features.apm_enabled" "false"
    replace_placeholder '{{ .datadog.apm.trace_versions.java | default "1" }}' ".datadog.apm.trace_versions.java" "1"
    replace_placeholder '{{ .datadog.apm.trace_versions.python | default "3" }}' ".datadog.apm.trace_versions.python" "3"
    replace_placeholder '{{ .datadog.apm.trace_versions.nodejs | default "5" }}' ".datadog.apm.trace_versions.nodejs" "5"
    replace_placeholder '{{ .datadog.apm.trace_versions.dotnet | default "3" }}' ".datadog.apm.trace_versions.dotnet" "3"
    
    # Logs settings
    replace_placeholder "{{ .datadog.features.logs_enabled }}" ".datadog.features.logs_enabled" "true"
    replace_placeholder "{{ .kubernetes.logs.collect_all_containers }}" ".kubernetes.logs.collect_all_containers" "true"
    
    # Security settings (individual features)
    replace_placeholder "{{ .kubernetes.security.threats_enabled }}" ".kubernetes.security.threats_enabled" "true"
    replace_placeholder "{{ .kubernetes.security.sca_enabled }}" ".kubernetes.security.sca_enabled" "true"
    replace_placeholder "{{ .kubernetes.security.iast_enabled }}" ".kubernetes.security.iast_enabled" "true"
    replace_placeholder "{{ .kubernetes.security.cws_enabled }}" ".kubernetes.security.cws_enabled" "true"
    replace_placeholder "{{ .kubernetes.security.cspm_enabled }}" ".kubernetes.security.cspm_enabled" "true"
    replace_placeholder "{{ .kubernetes.security.sbom_enabled }}" ".kubernetes.security.sbom_enabled" "true"
    
    # Monitoring settings
    replace_placeholder "{{ .datadog.features.usm_enabled}}" ".datadog.features.usm_enabled" "true"
    replace_placeholder "{{ .datadog.features.network_monitoring_enabled }}" ".datadog.features.network_monitoring_enabled" "true"
    replace_placeholder "{{ .datadog.features.live_processes_enabled }}" ".datadog.features.live_processes_enabled" "true"
    
    # Clean up backup files
    rm -f "$VALUES_FILE.bak"
    
    log_success "Generated values.yaml from config.yaml template"
    log_info "You can now edit values.yaml directly for advanced Helm chart customizations"
    
    # Create Kubernetes secret manifest for API keys
    create_secret_manifest "$api_key" "$app_key"
}

# Create Kubernetes secret manifest for Datadog API keys
create_secret_manifest() {
    local api_key="$1"
    local app_key="$2"
    local secret_file="$PROJECT_ROOT/kubernetes/datadog/datadog-secret.yaml"
    
    log_info "Creating Kubernetes secret manifest..."
    
    mkdir -p "$(dirname "$secret_file")"
    
    cat > "$secret_file" << EOF
apiVersion: v1
kind: Secret
metadata:
  name: datadog-secret
  namespace: datadog
type: Opaque
data:
  api-key: $(echo -n "$api_key" | base64)
  app-key: $(echo -n "$app_key" | base64)
EOF
    
    log_success "Created datadog-secret.yaml with encoded API keys"
    log_warn "Remember: The secret file contains your encoded API keys. Keep it secure!"
}

# Generate Helm values from config
if [[ -f "$PROJECT_ROOT/configs/config.yaml" ]]; then
    generate_values_yaml
else
    echo -e "${YELLOW}⚠️  Skipping values.yaml generation - config.yaml not found${NC}"
fi

# Create logs directory
mkdir -p logs

echo -e "${GREEN}✅ Configuration files created${NC}"

# Setup Terraform
echo -e "${BLUE}🏗️  Setting up Terraform...${NC}"

# Check if tfenv is managing Terraform and ensure a version is set
if command -v tfenv &> /dev/null; then
    echo -e "${BLUE}🔍 Detected tfenv - checking Terraform version...${NC}"
    
    # Check if a version is set
    if ! terraform version &> /dev/null; then
        echo -e "${YELLOW}⚠️  No Terraform version set, installing latest stable version...${NC}"
        
        # Get the latest stable version (non-alpha, non-beta, non-rc)
        LATEST_VERSION=$(tfenv list-remote | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | head -1)
        
        if [ -n "$LATEST_VERSION" ]; then
            echo -e "${BLUE}📦 Installing Terraform $LATEST_VERSION...${NC}"
            tfenv install "$LATEST_VERSION"
            tfenv use "$LATEST_VERSION"
            echo -e "${GREEN}✅ Terraform $LATEST_VERSION installed and activated${NC}"
        else
            echo -e "${RED}❌ Could not determine latest Terraform version${NC}"
            exit 1
        fi
    else
        CURRENT_VERSION=$(terraform version -json | grep '"terraform_version"' | cut -d'"' -f4 2>/dev/null || terraform version | head -1 | cut -d' ' -f2)
        echo -e "${GREEN}✅ Terraform $CURRENT_VERSION is ready${NC}"
    fi
fi

echo -e "${BLUE}🏗️  Initializing Terraform...${NC}"
cd "$PROJECT_ROOT/terraform/environments/dev"
terraform init

echo -e "${GREEN}✅ Terraform initialized${NC}"

# Add Datadog Helm repository
echo -e "${BLUE}📦 Adding Datadog Helm repository...${NC}"
helm repo add datadog https://helm.datadoghq.com
helm repo update

echo -e "${GREEN}✅ Helm repository added${NC}"

echo ""
echo -e "${GREEN}🎉 Setup completed successfully!${NC}"
echo ""
echo -e "${YELLOW}📋 Next steps:${NC}"
echo "1. Edit configs/config.yaml with your Datadog settings (API keys, features, tags, etc.)"
echo "2. (Optional) Validate your configuration: ./scripts/validate-config.sh"
echo "3. (Optional) Edit terraform/environments/dev/terraform.tfvars for infrastructure customization"
echo "4. Run './scripts/deploy.sh' to deploy the cluster"
echo ""
echo -e "${GREEN}✨ Centralized configuration: config.yaml is your single source of truth!${NC}"
echo -e "${BLUE}💡 The same config.yaml will be used for future VMs and components!${NC}"
echo ""
echo -e "${BLUE}📚 For more information, see docs/ directory${NC}" 