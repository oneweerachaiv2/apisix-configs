# APISIX API Versioning Guide

This directory contains comprehensive examples and configurations for implementing API versioning in APISIX.

## Table of Contents

1. [Versioning Strategies Overview](#versioning-strategies-overview)
2. [URI Path Versioning (Recommended)](#uri-path-versioning)
3. [Header-Based Versioning](#header-based-versioning)
4. [Query Parameter Versioning](#query-parameter-versioning)
5. [Hybrid Approaches](#hybrid-approaches)
6. [Best Practices](#best-practices)

---

## Versioning Strategies Overview

| Strategy | Pros | Cons | Use Case |
|----------|------|------|----------|
| **URI Path** (`/v1/users`) | Clear, cacheable, easy to debug | URI changes between versions | Most REST APIs |
| **Header-Based** (`Api-Version: 1`) | Clean URIs, flexible | Hard to test/cache, less discoverable | Internal APIs |
| **Query Param** (`?version=1`) | Easy to test | Pollutes URIs, cache issues | Quick prototypes |
| **Accept Header** (`Accept: application/vnd.api.v1+json`) | HTTP standard | Complex, verbose | Strict REST APIs |

### Recommendation

**URI Path Versioning** is recommended for most use cases because:
- Explicit and visible version in the URL
- Easy to test with any HTTP client (curl, browser)
- Better caching support (each version has unique URI)
- Clear routing in API gateways
- Easy to deprecate old versions

---

## Quick Start

```bash
# Start APISIX (from apisix-go-plugin-runner directory)
cd apisix-go-plugin-runner
docker-compose up -d

# Set up versioned routes
./scripts/setup-versioned-routes.sh

# Test different versions
curl http://localhost:9090/api/v1/users
curl http://localhost:9090/api/v2/users
curl -H "Api-Version: 2" http://localhost:9090/api/users
```

---

## Files in This Directory

| File | Description |
|------|-------------|
| `01-uri-path-versioning.yaml` | URI path-based versioning examples |
| `02-header-versioning.yaml` | Header-based versioning with traffic-split |
| `03-query-param-versioning.yaml` | Query parameter versioning |
| `04-hybrid-versioning.yaml` | Combined strategies for flexibility |
| `05-version-deprecation.yaml` | Patterns for deprecating old versions |
| `setup-versioned-routes.sh` | Shell script to set up all versioned routes |
| `test-versioning.sh` | Test script to verify versioning works |

---

## Configuration Approaches

### 1. Separate Routes per Version (Simple)
Each API version has its own route definition, routing to different upstreams.

### 2. Single Route with Traffic-Split (Advanced)
One route uses `traffic-split` plugin with `vars` matching to route based on version.

### 3. Proxy-Rewrite Pattern (URL Normalization)
Strip version prefix and add as header for upstream processing.

---

## Upstream Architecture

```
┌─────────────┐     ┌──────────────┐     ┌─────────────────┐
│   Client    │────▶│    APISIX    │────▶│  Backend v1     │
│             │     │   Gateway    │     │  (port 8081)    │
└─────────────┘     │              │     └─────────────────┘
                    │   Version    │     ┌─────────────────┐
                    │   Router     │────▶│  Backend v2     │
                    │              │     │  (port 8082)    │
                    └──────────────┘     └─────────────────┘
                           │             ┌─────────────────┐
                           └────────────▶│  Backend v3     │
                                         │  (port 8083)    │
                                         └─────────────────┘
```

---

## Admin API Connection

Default connection details for the examples:
- **Admin API**: http://localhost:9092 (or 9180 for K8s)
- **API Key**: edd1c9f034335f136f87ad84b625c8f1
- **Gateway**: http://localhost:9090

---

## Best Practices for API Versioning

### 1. Version Naming Convention
- Use simple integer versions (v1, v2, v3)
- Avoid dates or complex version strings
- Consider semantic versioning for major.minor (v2.1) only for sub-versions

### 2. Default Version Strategy
- Always default to the current stable version (not latest)
- Never default to deprecated versions
- Document the default version behavior clearly

### 3. Deprecation Process
```
1. Announce deprecation (X-API-Deprecated: true header)
2. Set sunset date (X-API-Sunset-Date header)
3. Reduce rate limits for deprecated versions
4. Add logging to track usage
5. Return 410 Gone after sunset date
```

### 4. Response Headers to Include
| Header | Description | Example |
|--------|-------------|---------|
| `X-API-Version` | Current version served | `2` |
| `X-API-Deprecated` | Deprecation status | `true/false` |
| `X-API-Sunset-Date` | When version will be removed | `2025-06-01` |
| `Link` | Link to successor version | `</api/v2>; rel="successor-version"` |
| `Warning` | Deprecation warning message | `299 - "API v1 is deprecated"` |

### 5. Backward Compatibility Checklist
- [ ] Old versions continue to work after new version deployment
- [ ] Deprecation headers added to old versions
- [ ] Rate limits adjusted appropriately
- [ ] Monitoring set up for version usage
- [ ] Documentation updated with migration guide
- [ ] SDK clients tested against all supported versions

---

## Routes Created by This Setup

| Route ID | URI Pattern | Versioning Method | Default |
|----------|-------------|-------------------|---------|
| `api-v1-users` | `/api/v1/users*` | URI Path | - |
| `api-v2-users` | `/api/v2/users*` | URI Path | - |
| `api-v3-users` | `/api/v3/users*` | URI Path | - |
| `api-header-versioned-products` | `/api/products*` | Header (`Api-Version`) | V2 |
| `api-query-versioned-orders` | `/api/orders*` | Query (`?version=X`) | V2 |
| `api-v0-deprecated` | `/api/v0/*` | Deprecated | - |
| `api-canary-payments` | `/api/payments*` | Canary (80/20) | V1 |
| `api-beta-testing` | `/api/features*` | Beta User Header | V2 |

---

## Testing Examples

```bash
# URI Path Versioning
curl http://localhost:9090/api/v1/users
curl http://localhost:9090/api/v2/users
curl http://localhost:9090/api/v3/users

# Header-Based Versioning
curl -H "Api-Version: 1" http://localhost:9090/api/products
curl -H "Api-Version: 2" http://localhost:9090/api/products
curl -H "Api-Version: latest" http://localhost:9090/api/products

# Query Parameter Versioning
curl "http://localhost:9090/api/orders?version=1"
curl "http://localhost:9090/api/orders?version=2"
curl "http://localhost:9090/api/orders?version=3"

# Check Deprecated Version Headers
curl -I http://localhost:9090/api/v0/anything

# Test Beta User Routing
curl -H "X-Beta-User: true" http://localhost:9090/api/features

# Verify Canary Distribution (run multiple times)
for i in {1..10}; do curl -s http://localhost:9090/api/payments | jq -r '.headers["X-Traffic-Split"]'; done
```

---

**Last Updated**: December 10, 2025

