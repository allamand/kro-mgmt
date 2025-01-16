#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to display usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  --delete         Delete all ACK resources found"
    echo "  --force-prune    Force delete resources by removing finalizers"
    echo "  --help           Display this help message"
}

# Function to list resources
list_resources() {
    local crd_name=$1
    local api_resource=$2
    local resources

    echo -e "${YELLOW}Checking ${api_resource} resources...${NC}"
    resources=$(kubectl get ${api_resource} --all-namespaces 2>/dev/null || echo "")
    
    if [ ! -z "$resources" ] && [ "$resources" != "No resources found" ]; then
        echo -e "${GREEN}Found ${api_resource} resources:${NC}"
        echo "$resources"
        echo "----------------------------------------"
        return 0
    else
        echo -e "${RED}No ${api_resource} resources found${NC}"
        echo "----------------------------------------"
        return 1
    fi
}

# Function to delete resources
delete_resources() {
    local api_resource=$1
    local resources
    
    resources=$(kubectl get ${api_resource} --all-namespaces -o name 2>/dev/null || echo "")
    if [ ! -z "$resources" ] && [ "$resources" != "No resources found" ]; then
        echo -e "${YELLOW}Deleting ${api_resource} resources...${NC}"
        echo "$resources" | while read resource; do
            echo "Deleting $resource..."
            kubectl delete $resource --timeout=30s 2>/dev/null || echo "Failed to delete $resource"
        done
    fi
}

# Function to force delete resources by removing finalizers
force_prune_resources() {
    local api_resource=$1
    local resources
    
    resources=$(kubectl get ${api_resource} --all-namespaces -o name 2>/dev/null || echo "")
    if [ ! -z "$resources" ] && [ "$resources" != "No resources found" ]; then
        echo -e "${YELLOW}Force pruning ${api_resource} resources...${NC}"
        echo "$resources" | while read resource; do
            echo "Removing finalizers from $resource..."
            kubectl patch $resource -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || echo "Failed to remove finalizers from $resource"
            kubectl delete $resource --timeout=30s 2>/dev/null || echo "Failed to delete $resource"
        done
    fi
}

# Parse command line arguments
DELETE=false
FORCE_PRUNE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --delete)
            DELETE=true
            shift
            ;;
        --force-prune)
            FORCE_PRUNE=true
            DELETE=true
            shift
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Get all CRDs for AWS services
echo -e "${GREEN}Discovering AWS ACK CRDs...${NC}"
CRDS=$(kubectl get crds -o name | grep "services.k8s.aws" || echo "")

if [ -z "$CRDS" ]; then
    echo -e "${RED}No AWS ACK CRDs found${NC}"
    exit 0
fi

# Count total CRDs
TOTAL_CRDS=$(echo "$CRDS" | wc -l)
echo -e "${GREEN}Found ${TOTAL_CRDS} AWS service CRDs${NC}"

# First pass: List all resources
echo -e "${GREEN}=== Listing all ACK resources ===${NC}"
echo "$CRDS" | while read crd; do
    # Extract the plural name and group from CRD
    if [ ! -z "$crd" ]; then
        # Remove the customresourcedefinition.apiextensions.k8s.io/ prefix if present
        crd_clean=${crd#customresourcedefinition.apiextensions.k8s.io/}
        
        # Get the API resource details
        api_resource=$(kubectl api-resources --api-group="${crd_clean#*.}" -o name 2>/dev/null | grep "^${crd_clean%%.*}$" || echo "")
        
        if [ ! -z "$api_resource" ]; then
            list_resources "$crd_clean" "$api_resource"
        fi
    fi
done

# Second pass: Delete resources if --delete flag is set
if $DELETE; then
    echo -e "${YELLOW}=== Deleting ACK resources ===${NC}"
    echo "$CRDS" | while read crd; do
        if [ ! -z "$crd" ]; then
            # Remove the customresourcedefinition.apiextensions.k8s.io/ prefix if present
            crd_clean=${crd#customresourcedefinition.apiextensions.k8s.io/}
            
            # Get the API resource details
            api_resource=$(kubectl api-resources --api-group="${crd_clean#*.}" -o name 2>/dev/null | grep "^${crd_clean%%.*}$" || echo "")
            
            if [ ! -z "$api_resource" ]; then
                if $FORCE_PRUNE; then
                    force_prune_resources "$api_resource"
                else
                    delete_resources "$api_resource"
                fi
            fi
        fi
    done
fi

echo -e "${GREEN}Operation completed${NC}"
