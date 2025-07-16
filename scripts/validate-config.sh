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
CONFIG_FILE="$PROJECT_ROOT/configs/config.yaml"

echo -e "${BLUE}🔍 Datadog Configuration Validator${NC}"
echo "================================="

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}❌ Configuration file not found: configs/config.yaml${NC}"
    echo -e "${YELLOW}💡 Run './scripts/setup.sh' to create it from template${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Configuration file found${NC}"

# Check if API keys are configured
if grep -q "YOUR_DATADOG_API_KEY_HERE" "$CONFIG_FILE"; then
    echo -e "${RED}❌ Datadog API keys not configured${NC}"
    echo -e "${YELLOW}💡 Edit configs/config.yaml and add your actual API keys${NC}"
    exit 1
fi

echo -e "${GREEN}✅ API keys are configured${NC}"

# Validate YAML syntax if yq is available
if command -v yq &> /dev/null; then
    echo -e "${BLUE}🔍 Validating YAML syntax...${NC}"
    if yq eval '.' "$CONFIG_FILE" > /dev/null; then
        echo -e "${GREEN}✅ YAML syntax is valid${NC}"
        
        # Extract and display key configuration
        echo ""
        echo -e "${BLUE}📊 Configuration Summary:${NC}"
        echo "========================"
        
        API_KEY=$(yq eval '.datadog.credentials.api_key' "$CONFIG_FILE")
        SITE=$(yq eval '.datadog.site' "$CONFIG_FILE")
        CLUSTER_NAME=$(yq eval '.kubernetes.cluster_name' "$CONFIG_FILE")
        
        echo -e "${BLUE}• API Key:${NC} ${API_KEY:0:8}..."
        echo -e "${BLUE}• Site:${NC} $SITE"
        echo -e "${BLUE}• Cluster:${NC} $CLUSTER_NAME"
        
        # Display global tags
        echo -e "${BLUE}• Global Tags:${NC}"
        yq eval '.datadog.global_tags[]' "$CONFIG_FILE" | sed 's/^/  - /'
        
        # Display Kubernetes tags
        echo -e "${BLUE}• Kubernetes Tags:${NC}"
        yq eval '.kubernetes.additional_tags[]' "$CONFIG_FILE" | sed 's/^/  - /'
        
        # Display features
        echo -e "${BLUE}• Features:${NC}"
        LOGS_ENABLED=$(yq eval '.datadog.features.logs_enabled' "$CONFIG_FILE")
        APM_ENABLED=$(yq eval '.datadog.features.apm_enabled' "$CONFIG_FILE")
        PROFILING_ENABLED=$(yq eval '.datadog.features.profiling_enabled' "$CONFIG_FILE")
        
        echo "  - Logs: $LOGS_ENABLED"
        echo "  - APM: $APM_ENABLED" 
        echo "  - Profiling: $PROFILING_ENABLED"
        
    else
        echo -e "${RED}❌ YAML syntax error in configuration file${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}⚠️  yq not available, skipping YAML validation${NC}"
    echo -e "${YELLOW}💡 Install yq for better validation: brew install yq${NC}"
fi

echo ""
echo -e "${GREEN}🎉 Configuration validation completed successfully!${NC}"
echo -e "${BLUE}📋 Ready to deploy with: ./scripts/deploy.sh${NC}" 