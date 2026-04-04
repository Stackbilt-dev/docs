---
title: "API Key Management"
description: "Generate, validate, rotate, and revoke API keys for programmatic access to Stackbilt services."
section: "platform"
order: 10
color: "#f59e0b"
tag: "10"
---

# API Key Management

API keys provide programmatic access to Stackbilt services without requiring an interactive OAuth session. Use them for CI/CD pipelines, backend integrations, MCP clients, and automated workflows.

## Key Prefixes

Stackbilt uses prefixed keys to identify the key type and scope:

| Prefix | Service | Description |
|--------|---------|-------------|
| `ea_` | edge-auth | General-purpose API keys issued through edge-auth |
| `sb_live_` | Stackbilder | Production keys for the Stackbilder platform |
| `sb_test_` | Stackbilder | Test/sandbox keys for development |
| `imgf_` | img-forge | Image generation API keys |

All key types are validated through edge-auth's centralized identity layer.

## Generating a Key

### Via the REST API

```
POST https://auth.stackbilt.dev/api-keys
```

Requires an authenticated session. The response includes the raw key **once** -- store it securely, as it cannot be retrieved again.

**Request body:**

```json
{
  "orgId": "org_stackbilt",
  "projectId": "prop_stackbilder",
  "label": "CI/CD Pipeline",
  "scopes": ["ai:invoke", "read"]
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `orgId` | string | Yes | Organization the key belongs to |
| `projectId` | string | No | Scope to a specific project (recommended) |
| `tenantId` | string | No | Scope to a specific tenant |
| `label` | string | No | Human-readable name for the key |
| `scopes` | string[] | No | Permission scopes (default: all scopes) |

**Response (`201 Created`):**

```json
{
  "key": "ea_abc123...xyz",
  "keyId": "uuid",
  "prefix": "ea_abc123"
}
```

### Via RPC (Service Binding)

Other Stackbilt services call the `generateApiKey` RPC method on the `EdgeAuthEntrypoint`:

```typescript
const result = await env.AUTH_SERVICE.generateApiKey({
  userId: "user-id",
  name: "MCP Access Key",
});
// result.key — raw key (store securely)
// result.id  — key ID for management operations
```

## Using a Key

Include the key in the `Authorization` header:

```bash
curl -X GET https://auth.stackbilt.dev/api-keys?org_id=org_stackbilt \
  -H "Authorization: Bearer ea_your_key_here"
```

For img-forge, the `X-API-Key` header is also accepted:

```bash
curl -X POST https://imgforge.stackbilt.dev/v2/generate \
  -H "X-API-Key: imgf_your_key_here" \
  -H "Content-Type: application/json" \
  -d '{"prompt": "A mountain landscape"}'
```

## Validation

API key validation is constant-time and uses SHA-256 hashing. The system:

1. Extracts the key prefix (first 11 characters)
2. Looks up the key row by prefix
3. Performs constant-time hash verification via Web Crypto
4. Checks expiration and revocation status
5. Returns the key's scopes, org, project, and tenant bindings

**Validation response shape:**

```json
{
  "valid": true,
  "keyId": "uuid",
  "userId": "user-id or null",
  "orgId": "org_stackbilt",
  "projectId": "prop_stackbilder or null",
  "tenantId": "tenant-id or null",
  "scopes": ["ai:invoke", "read"],
  "rateLimit": {
    "limit": 1000,
    "remaining": 998,
    "resetAt": 1234567890
  }
}
```

Invalid, revoked, or expired keys receive a uniform 403 denial with no distinguishing information. This prevents key enumeration and timing attacks.

## Listing Keys

```
GET https://auth.stackbilt.dev/api-keys?org_id=org_stackbilt
```

Returns all active (non-revoked) keys for the organization. Raw key values are never returned -- only the prefix is shown.

**Response:**

```json
[
  {
    "id": "uuid",
    "prefix": "ea_abc1234",
    "label": "CI/CD Pipeline",
    "scopes": ["ai:invoke", "read"],
    "projectId": "prop_stackbilder",
    "lastUsedAt": "2026-04-01T12:00:00Z",
    "createdAt": "2026-03-15T09:00:00Z"
  }
]
```

## Revoking a Key

```
DELETE https://auth.stackbilt.dev/api-keys/:keyId
```

Revocation is a soft delete -- the key row is marked `revoked = 1` and immediately stops validating. Revoked keys cannot be un-revoked; generate a new key instead.

```bash
curl -X DELETE https://auth.stackbilt.dev/api-keys/key-uuid \
  -H "Authorization: Bearer ea_your_admin_key"
```

**Response:**

```json
{
  "success": true
}
```

## Rotation

To rotate a key:

1. Generate a new key with the same scopes and project binding
2. Update your application configuration to use the new key
3. Verify the new key works by making a test request
4. Revoke the old key

There is no atomic rotation endpoint -- this two-step process ensures zero downtime. Both keys remain valid until the old one is explicitly revoked.

For img-forge keys, the gateway provides an atomic rotation endpoint:

```
POST https://imgforge.stackbilt.dev/v2/tenants/:id/rotate
```

This invalidates the current key and returns a new one in a single request.

## Scope Reference

| Scope | Description |
|-------|-------------|
| `ai:invoke` | Call MCP tools and scaffold endpoints |
| `read` | Read flows, images, and project data |
| `generate` | Create image generation jobs (img-forge) |

When no scopes are specified at creation, the key inherits all scopes available to the creating user's role.

## Access Control

API key operations are governed by edge-auth's policy engine:

- **Creating org-wide keys** (no `projectId`) requires org admin role or a service principal. Project-scoped keys or member-role users cannot mint org-wide keys.
- **Creating project-scoped keys** requires at least member access to the project's org.
- **Revoking keys** requires access to the key's org (and project, if project-scoped).
- **Listing keys** requires read access to the org.

All API key operations are audit-logged with risk level, principal identity, and outcome.

## Security

- Keys are hashed with SHA-256 before storage. Raw keys exist only in memory during generation and in the creation response.
- Validation uses constant-time comparison to prevent timing attacks.
- All denied requests return a uniform 403 response -- the system does not distinguish between nonexistent keys, revoked keys, and unauthorized access.
- `last_used_at` is updated on each successful validation for monitoring.
- Keys can optionally carry an `expires_at` timestamp for automatic expiration.
