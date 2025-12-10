#!/bin/bash
# =============================================================================
# Environment Deployment Script for APISIX API Versioning
# =============================================================================
# Usage: ./deploy.sh <environment> [--dry-run]
# Environments: dev, sit, uat, prod
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV="${1:-dev}"
DRY_RUN="${2:-}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}=============================================="
    echo -e "  APISIX API Versioning Deployment"
    echo -e "  Environment: ${YELLOW}${ENV}${BLUE}"
    echo -e "==============================================${NC}"
}

validate_env() {
    case "$ENV" in
        dev|sit|uat|prod)
            echo -e "${GREEN}✓${NC} Valid environment: $ENV"
            ;;
        *)
            echo -e "${RED}✗${NC} Invalid environment: $ENV"
            echo "Valid environments: dev, sit, uat, prod"
            exit 1
            ;;
    esac
}

check_prerequisites() {
    echo -e "\n${YELLOW}Checking prerequisites...${NC}"
    
    if ! command -v kubectl &> /dev/null; then
        echo -e "${RED}✗${NC} kubectl not found"
        exit 1
    fi
    echo -e "${GREEN}✓${NC} kubectl found"
    
    if ! command -v kustomize &> /dev/null; then
        echo -e "${YELLOW}!${NC} kustomize not found, using kubectl kustomize"
        KUSTOMIZE_CMD="kubectl kustomize"
    else
        echo -e "${GREEN}✓${NC} kustomize found"
        KUSTOMIZE_CMD="kustomize build"
    fi
}

deploy() {
    echo -e "\n${YELLOW}Building manifests for ${ENV}...${NC}"
    
    if [ "$DRY_RUN" == "--dry-run" ]; then
        echo -e "${YELLOW}Running in DRY-RUN mode${NC}"
        $KUSTOMIZE_CMD "$SCRIPT_DIR/$ENV" | kubectl apply --dry-run=client -f -
    else
        echo -e "${YELLOW}Deploying to ${ENV}...${NC}"
        $KUSTOMIZE_CMD "$SCRIPT_DIR/$ENV" | kubectl apply -f -
    fi
    
    echo -e "\n${GREEN}✓${NC} Deployment complete for ${ENV}"
}

show_resources() {
    echo -e "\n${YELLOW}Deployed resources:${NC}"
    $KUSTOMIZE_CMD "$SCRIPT_DIR/$ENV" | kubectl apply --dry-run=client -o name -f - 2>/dev/null || true
}

# Main
print_header
validate_env
check_prerequisites
deploy
show_resources

echo -e "\n${GREEN}=============================================="
echo -e "  Deployment Complete!"
echo -e "==============================================${NC}"

# Show next steps
case "$ENV" in
    dev)
        echo -e "\n${YELLOW}Next: Test and promote to SIT${NC}"
        echo "  ./deploy.sh sit"
        ;;
    sit)
        echo -e "\n${YELLOW}Next: Test and promote to UAT${NC}"
        echo "  ./deploy.sh uat"
        ;;
    uat)
        echo -e "\n${YELLOW}Next: Get approval and promote to PROD${NC}"
        echo "  ./deploy.sh prod"
        ;;
    prod)
        echo -e "\n${GREEN}Production deployment complete!${NC}"
        echo "  Monitor: kubectl get apisixroutes -n apisix-prod"
        ;;
esac

