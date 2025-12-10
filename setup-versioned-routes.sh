#!/bin/bash
# =============================================================================
# APISIX API Versioning - Route Setup Script
# =============================================================================
# This script creates versioned API routes in APISIX demonstrating
# URI path-based, header-based, and query parameter versioning strategies.
# =============================================================================

set -e

# Configuration
APISIX_ADMIN="${APISIX_ADMIN:-http://localhost:9092/apisix/admin}"
API_KEY="${API_KEY:-edd1c9f034335f136f87ad84b625c8f1}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}======================================================${NC}"
echo -e "${BLUE}       APISIX API Versioning Setup Script             ${NC}"
echo -e "${BLUE}======================================================${NC}"
echo ""

# Helper function to create routes
create_route() {
    local route_id=$1
    local route_config=$2
    local description=$3
    
    echo -e "${YELLOW}Creating route: ${route_id}${NC}"
    echo -e "  Description: ${description}"
    
    response=$(curl -s -w "\n%{http_code}" -X PUT "${APISIX_ADMIN}/routes/${route_id}" \
        -H "X-API-KEY: ${API_KEY}" \
        -H "Content-Type: application/json" \
        -d "${route_config}")
    
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    if [[ "$http_code" =~ ^2 ]]; then
        echo -e "  ${GREEN}✓ Created successfully${NC}"
    else
        echo -e "  ${RED}✗ Failed: ${body}${NC}"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# Create Upstreams for Version Testing
# Using httpbin as a mock backend that echoes requests
# -----------------------------------------------------------------------------
echo -e "\n${BLUE}Step 1: Creating Version-Specific Upstreams${NC}"
echo "============================================"

# V1 Upstream
curl -s -X PUT "${APISIX_ADMIN}/upstreams/users-v1" \
    -H "X-API-KEY: ${API_KEY}" \
    -H "Content-Type: application/json" \
    -d '{
        "name": "Users Service V1",
        "desc": "Backend for Users API Version 1",
        "type": "roundrobin",
        "nodes": [{"host": "httpbin", "port": 8080, "weight": 1}],
        "timeout": {"connect": 5, "send": 10, "read": 10}
    }' > /dev/null && echo -e "${GREEN}✓ Created upstream: users-v1${NC}"

# V2 Upstream
curl -s -X PUT "${APISIX_ADMIN}/upstreams/users-v2" \
    -H "X-API-KEY: ${API_KEY}" \
    -H "Content-Type: application/json" \
    -d '{
        "name": "Users Service V2",
        "desc": "Backend for Users API Version 2",
        "type": "roundrobin",
        "nodes": [{"host": "httpbin", "port": 8080, "weight": 1}],
        "timeout": {"connect": 5, "send": 15, "read": 15}
    }' > /dev/null && echo -e "${GREEN}✓ Created upstream: users-v2${NC}"

# V3 Upstream  
curl -s -X PUT "${APISIX_ADMIN}/upstreams/users-v3" \
    -H "X-API-KEY: ${API_KEY}" \
    -H "Content-Type: application/json" \
    -d '{
        "name": "Users Service V3 (Beta)",
        "desc": "Backend for Users API Version 3 - Beta",
        "type": "roundrobin",
        "nodes": [{"host": "httpbin", "port": 8080, "weight": 1}],
        "timeout": {"connect": 5, "send": 15, "read": 15}
    }' > /dev/null && echo -e "${GREEN}✓ Created upstream: users-v3${NC}"

# -----------------------------------------------------------------------------
# STRATEGY 1: URI Path-Based Versioning Routes
# -----------------------------------------------------------------------------
echo -e "\n${BLUE}Step 2: Creating URI Path-Based Version Routes${NC}"
echo "=============================================="

# API V1 - Users (Legacy)
create_route "api-v1-users" '{
    "uri": "/api/v1/users*",
    "name": "Users API V1 - Legacy",
    "desc": "Version 1 of Users API - maintained for backward compatibility",
    "methods": ["GET", "POST", "PUT", "DELETE"],
    "plugins": {
        "response-rewrite": {
            "headers": {
                "set": {
                    "X-API-Version": "1",
                    "X-API-Deprecated": "false"
                }
            }
        },
        "proxy-rewrite": {
            "uri": "/anything/v1/users"
        }
    },
    "upstream_id": "users-v1"
}' "URI path versioning - V1 legacy users endpoint"

# API V2 - Users (Current Stable)
create_route "api-v2-users" '{
    "uri": "/api/v2/users*",
    "name": "Users API V2 - Stable",
    "desc": "Version 2 of Users API - current stable version",
    "methods": ["GET", "POST", "PUT", "PATCH", "DELETE"],
    "plugins": {
        "response-rewrite": {
            "headers": {
                "set": {
                    "X-API-Version": "2",
                    "X-API-Deprecated": "false"
                }
            }
        },
        "proxy-rewrite": {
            "uri": "/anything/v2/users"
        }
    },
    "upstream_id": "users-v2"
}' "URI path versioning - V2 stable users endpoint"

# API V3 - Users (Beta)
create_route "api-v3-users" '{
    "uri": "/api/v3/users*",
    "name": "Users API V3 - Beta",
    "desc": "Version 3 of Users API - beta with new features",
    "methods": ["GET", "POST", "PUT", "PATCH", "DELETE"],
    "plugins": {
        "response-rewrite": {
            "headers": {
                "set": {
                    "X-API-Version": "3",
                    "X-API-Beta": "true",
                    "X-API-Warning": "Beta version - breaking changes may occur"
                }
            }
        },
        "proxy-rewrite": {
            "uri": "/anything/v3/users"
        }
    },
    "upstream_id": "users-v3"
}' "URI path versioning - V3 beta users endpoint"

# -----------------------------------------------------------------------------
# STRATEGY 2: Header-Based Versioning Route
# -----------------------------------------------------------------------------
echo -e "\n${BLUE}Step 3: Creating Header-Based Version Route${NC}"
echo "============================================"

create_route "api-header-versioned-products" '{
    "uri": "/api/products*",
    "name": "Products API - Header Versioned",
    "desc": "Routes based on Api-Version header (default: v2)",
    "methods": ["GET", "POST", "PUT", "PATCH", "DELETE"],
    "plugins": {
        "traffic-split": {
            "rules": [
                {
                    "match": [{"vars": [["http_api_version", "==", "1"]]}],
                    "weighted_upstreams": [{"upstream_id": "users-v1", "weight": 1}]
                },
                {
                    "match": [{"vars": [["http_api_version", "==", "3"]]}],
                    "weighted_upstreams": [{"upstream_id": "users-v3", "weight": 1}]
                },
                {
                    "match": [{"vars": [["http_api_version", "==", "latest"]]}],
                    "weighted_upstreams": [{"upstream_id": "users-v3", "weight": 1}]
                }
            ]
        },
        "proxy-rewrite": {
            "uri": "/anything/products"
        }
    },
    "upstream_id": "users-v2"
}' "Header-based versioning with Api-Version header"

# -----------------------------------------------------------------------------
# STRATEGY 3: Query Parameter Versioning Route
# -----------------------------------------------------------------------------
echo -e "\n${BLUE}Step 4: Creating Query Parameter Version Route${NC}"
echo "==============================================="

create_route "api-query-versioned-orders" '{
    "uri": "/api/orders*",
    "name": "Orders API - Query Param Versioned",
    "desc": "Routes based on ?version=X query param (default: v2)",
    "methods": ["GET", "POST", "PUT", "DELETE"],
    "plugins": {
        "traffic-split": {
            "rules": [
                {
                    "match": [{"vars": [["arg_version", "==", "1"]]}],
                    "weighted_upstreams": [{"upstream_id": "users-v1", "weight": 1}]
                },
                {
                    "match": [{"vars": [["arg_version", "==", "3"]]}],
                    "weighted_upstreams": [{"upstream_id": "users-v3", "weight": 1}]
                }
            ]
        },
        "proxy-rewrite": {
            "uri": "/anything/orders"
        }
    },
    "upstream_id": "users-v2"
}' "Query parameter versioning with ?version=X"

# -----------------------------------------------------------------------------
# PATTERN: Deprecated Version with Warning
# -----------------------------------------------------------------------------
echo -e "\n${BLUE}Step 5: Creating Deprecated Version Route${NC}"
echo "=========================================="

create_route "api-v0-deprecated" '{
    "uri": "/api/v0/*",
    "name": "API V0 - DEPRECATED",
    "desc": "Deprecated version - returns warning headers",
    "plugins": {
        "response-rewrite": {
            "headers": {
                "set": {
                    "X-API-Version": "0",
                    "X-API-Deprecated": "true",
                    "X-API-Sunset-Date": "2025-06-01",
                    "Warning": "299 - API v0 is deprecated. Please upgrade to v2.",
                    "Link": "</api/v2>; rel=\"successor-version\""
                }
            }
        },
        "proxy-rewrite": {
            "uri": "/anything/v0/deprecated"
        }
    },
    "upstream_id": "users-v1"
}' "Deprecated V0 with warning headers"

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
echo -e "\n${BLUE}======================================================${NC}"
echo -e "${GREEN}✓ API Versioning Routes Created Successfully!${NC}"
echo -e "${BLUE}======================================================${NC}"
echo ""
echo -e "${YELLOW}Test the versioned routes:${NC}"
echo ""
echo "# URI Path Versioning:"
echo "  curl http://localhost:9090/api/v1/users"
echo "  curl http://localhost:9090/api/v2/users"
echo "  curl http://localhost:9090/api/v3/users"
echo ""
echo "# Header-Based Versioning:"
echo "  curl http://localhost:9090/api/products"
echo "  curl -H 'Api-Version: 1' http://localhost:9090/api/products"
echo "  curl -H 'Api-Version: 3' http://localhost:9090/api/products"
echo ""
echo "# Query Parameter Versioning:"
echo "  curl 'http://localhost:9090/api/orders'"
echo "  curl 'http://localhost:9090/api/orders?version=1'"
echo "  curl 'http://localhost:9090/api/orders?version=3'"
echo ""
echo "# Deprecated Version (check headers):"
echo "  curl -I http://localhost:9090/api/v0/anything"
echo ""

