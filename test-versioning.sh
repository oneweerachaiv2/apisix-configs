#!/bin/bash
# =============================================================================
# APISIX API Versioning - Test Script
# =============================================================================
# Tests all versioning strategies to verify correct routing behavior
# =============================================================================

set -e

# Configuration
GATEWAY="${GATEWAY:-http://localhost:9090}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASSED=0
FAILED=0

# Test helper function
test_endpoint() {
    local name=$1
    local url=$2
    local expected_version=$3
    local header="${4:-}"
    
    if [ -n "$header" ]; then
        response=$(curl -s -H "$header" "$url")
        response_headers=$(curl -s -I -H "$header" "$url" 2>/dev/null || echo "")
    else
        response=$(curl -s "$url")
        response_headers=$(curl -s -I "$url" 2>/dev/null || echo "")
    fi
    
    # Check for version in response or headers
    version_header=$(echo "$response_headers" | grep -i "X-API-Version" | awk -F': ' '{print $2}' | tr -d '\r\n')
    
    if [[ "$response" == *"$expected_version"* ]] || [[ "$version_header" == "$expected_version" ]]; then
        echo -e "${GREEN}✓ PASS${NC}: $name"
        echo -e "  Expected: v$expected_version, Got version header: $version_header"
        ((PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}: $name"
        echo -e "  Expected: v$expected_version"
        echo -e "  Version header: $version_header"
        ((FAILED++))
    fi
}

echo -e "${BLUE}======================================================${NC}"
echo -e "${BLUE}       APISIX API Versioning - Test Suite             ${NC}"
echo -e "${BLUE}======================================================${NC}"
echo ""

# Check if APISIX is accessible
echo -e "${YELLOW}Checking APISIX connectivity...${NC}"
if ! curl -s -o /dev/null -w "%{http_code}" "$GATEWAY" | grep -q "404\|200"; then
    echo -e "${RED}ERROR: Cannot connect to APISIX at $GATEWAY${NC}"
    echo "Make sure APISIX is running: docker-compose up -d"
    exit 1
fi
echo -e "${GREEN}✓ APISIX is accessible${NC}\n"

# -----------------------------------------------------------------------------
# Test 1: URI Path-Based Versioning
# -----------------------------------------------------------------------------
echo -e "${BLUE}Test 1: URI Path-Based Versioning${NC}"
echo "=================================="

test_endpoint "GET /api/v1/users (V1)" "$GATEWAY/api/v1/users" "1"
test_endpoint "GET /api/v2/users (V2)" "$GATEWAY/api/v2/users" "2"
test_endpoint "GET /api/v3/users (V3)" "$GATEWAY/api/v3/users" "3"
echo ""

# -----------------------------------------------------------------------------
# Test 2: Header-Based Versioning
# -----------------------------------------------------------------------------
echo -e "${BLUE}Test 2: Header-Based Versioning${NC}"
echo "================================"

test_endpoint "GET /api/products (default V2)" "$GATEWAY/api/products" "2"
test_endpoint "GET /api/products Api-Version:1" "$GATEWAY/api/products" "1" "Api-Version: 1"
test_endpoint "GET /api/products Api-Version:3" "$GATEWAY/api/products" "3" "Api-Version: 3"
test_endpoint "GET /api/products Api-Version:latest" "$GATEWAY/api/products" "3" "Api-Version: latest"
echo ""

# -----------------------------------------------------------------------------
# Test 3: Query Parameter Versioning
# -----------------------------------------------------------------------------
echo -e "${BLUE}Test 3: Query Parameter Versioning${NC}"
echo "==================================="

test_endpoint "GET /api/orders (default V2)" "$GATEWAY/api/orders" "2"
test_endpoint "GET /api/orders?version=1" "$GATEWAY/api/orders?version=1" "1"
test_endpoint "GET /api/orders?version=3" "$GATEWAY/api/orders?version=3" "3"
echo ""

# -----------------------------------------------------------------------------
# Test 4: Deprecated Version Headers
# -----------------------------------------------------------------------------
echo -e "${BLUE}Test 4: Deprecated Version Headers${NC}"
echo "===================================="

deprecated_headers=$(curl -s -I "$GATEWAY/api/v0/test" 2>/dev/null || echo "")
if echo "$deprecated_headers" | grep -qi "X-API-Deprecated: true"; then
    echo -e "${GREEN}✓ PASS${NC}: Deprecated header present"
    ((PASSED++))
else
    echo -e "${RED}✗ FAIL${NC}: Deprecated header missing"
    ((FAILED++))
fi

if echo "$deprecated_headers" | grep -qi "X-API-Sunset-Date"; then
    echo -e "${GREEN}✓ PASS${NC}: Sunset date header present"
    ((PASSED++))
else
    echo -e "${RED}✗ FAIL${NC}: Sunset date header missing"
    ((FAILED++))
fi

if echo "$deprecated_headers" | grep -qi "Warning:"; then
    echo -e "${GREEN}✓ PASS${NC}: Warning header present"
    ((PASSED++))
else
    echo -e "${RED}✗ FAIL${NC}: Warning header missing"
    ((FAILED++))
fi
echo ""

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
echo -e "${BLUE}======================================================${NC}"
TOTAL=$((PASSED + FAILED))
echo -e "Results: ${GREEN}$PASSED passed${NC} / ${RED}$FAILED failed${NC} / $TOTAL total"
echo -e "${BLUE}======================================================${NC}"

if [ $FAILED -gt 0 ]; then
    exit 1
fi

