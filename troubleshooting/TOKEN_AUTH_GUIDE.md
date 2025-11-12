# Token Authentication Guide

## Overview

This guide explains the token authentication setup for the Whisper and Mistral models deployed via Helm.

## What Was Configured

### 1. InferenceService Changes
Both `inferenceservice-whisper.yaml` and `inferenceservice-mistral.yaml` now include:
- **Annotation**: `security.opendatahub.io/enable-auth: "true"` - Enables authentication
- **ServiceAccount Reference**: `serviceAccountName: <model-name>-sa` - Links to the ServiceAccount
- **Labels**: `opendatahub.io/dashboard: "true"` - Makes it visible in the dashboard

### 2. ServiceAccount Resources
Created `serviceaccount-whisper.yaml` and `serviceaccount-mistral.yaml`:
- Creates a ServiceAccount for each model
- Includes OpenShift AI labels for dashboard integration
- Links to the model via annotations

### 3. Token Secret Resources
Created `token-secret-whisper.yaml` and `token-secret-mistral.yaml`:
- Explicitly creates token secrets (required for Kubernetes 1.24+)
- Type: `kubernetes.io/service-account-token`
- Auto-populated by Kubernetes with actual token data

## Resources Created

```
For Whisper:
├── ServiceAccount: whisper-large-v3-sa
├── Secret: whisper-large-v3-sa-token (token)
├── Role: whisper-large-v3-access (RBAC permissions)
├── RoleBinding: whisper-large-v3-access (binds SA to Role)
└── InferenceService: whisper-large-v3 (with auth enabled)

For Mistral:
├── ServiceAccount: redhataimistral-small-quantizedw4a16-sa
├── Secret: redhataimistral-small-quantizedw4a16-sa-token (token)
├── Role: redhataimistral-small-quantizedw4a16-access (RBAC permissions)
├── RoleBinding: redhataimistral-small-quantizedw4a16-access (binds SA to Role)
└── InferenceService: redhataimistral-small-quantizedw4a16 (with auth enabled)
```

## Troubleshooting

### Issue 1: Token Not Showing in OpenShift AI Dashboard

**Possible Causes:**
1. UI caching - needs refresh
2. OpenShift AI operator hasn't reconciled yet
3. Missing labels or annotations

**Diagnostic Steps:**
```bash
# Run the diagnostic script
./diagnose-auth.sh whisper-large-v3 proj-poc-aros

# Check if resources exist
kubectl get sa,secret,inferenceservice -n proj-poc-aros
```

### Issue 2: 400 Bad Request Error When Using Token

**Possible Causes:**
1. Token not properly extracted from secret
2. Wrong Authorization header format
3. Endpoint configuration issues
4. Service mesh/Istio authentication policies

**How to Extract Token Correctly:**
```bash
# Extract token
TOKEN=$(kubectl get secret whisper-large-v3-sa-token -n proj-poc-aros \
  -o jsonpath='{.data.token}' | base64 -d)

# Verify token is not empty
echo "Token length: ${#TOKEN}"

# Use with proper Authorization header
curl -H "Authorization: Bearer $TOKEN" \
     -H "Content-Type: application/json" \
     https://your-endpoint/v1/models
```

**Common Mistakes:**
- ❌ Using `Authorization: Token $TOKEN` (wrong format)
- ❌ Not base64 decoding the token
- ❌ Including newlines or spaces in the token
- ✅ Use `Authorization: Bearer $TOKEN` (correct)

### Issue 3: Authorization Server Error

**Error Message:**
```
'error': 'server_error', 
'error_description': 'The authorization server encountered an unexpected condition...'
```

This typically indicates:
1. **Missing RBAC permissions** - ServiceAccount can't access the InferenceService
2. **Service Mesh blocking** - AuthorizationPolicies or PeerAuthentication issues
3. **Token audience mismatch** - Token aud claim doesn't match expected value
4. **OpenShift AI authorization misconfiguration**

**Diagnostic Steps:**

1. **Check RBAC permissions:**
```bash
# Verify Role and RoleBinding were created
kubectl get role,rolebinding -n proj-poc-aros | grep -E "whisper|mistral"

# Check what permissions the SA has
kubectl auth can-i get inferenceservices \
  --as=system:serviceaccount:proj-poc-aros:whisper-large-v3-sa \
  -n proj-poc-aros
```

2. **Inspect token claims:**
```bash
# Run token inspector
./inspect-token.sh whisper-large-v3 proj-poc-aros

# Key things to verify:
# - iss (issuer): should be your cluster's issuer
# - aud (audience): should match expected audience
# - sub (subject): should reference the ServiceAccount
```

3. **Check Service Mesh configuration:**
```bash
# Run comprehensive service mesh check
./check-service-mesh.sh proj-poc-aros

# Look for:
# - Restrictive AuthorizationPolicies
# - PeerAuthentication with STRICT mTLS
# - RequestAuthentication policies
```

4. **Check OpenShift AI operator logs:**
```bash
kubectl logs -n redhat-ods-operator \
  deployment/odh-model-controller --tail=100
```

**Common Fixes:**

**Fix 1: RBAC Missing (Most Common)**
The Helm chart now includes Role and RoleBinding resources. Redeploy:
```bash
helm upgrade proj-poc-aros proj-poc-aros-1.0.0.tgz -n proj-poc-aros
```

**Fix 2: Service Mesh Blocking**
If Service Mesh is blocking, you may need to add an AuthorizationPolicy:
```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: allow-token-access
  namespace: proj-poc-aros
spec:
  action: ALLOW
  rules:
    - from:
        - source:
            principals: ["cluster.local/ns/proj-poc-aros/sa/whisper-large-v3-sa"]
```

**Fix 3: Token Audience Issue**
You may need to create a token with specific audience:
```bash
# Create token with custom audience
kubectl create token whisper-large-v3-sa \
  -n proj-poc-aros \
  --audience=https://kubernetes.default.svc \
  --duration=24h
```

### Issue 4: Token Exists but API Returns 401/403

This could indicate:
1. Service mesh authentication policies blocking requests  
2. OpenShift Service Mesh not configured to accept the token
3. Token doesn't have proper RBAC permissions

**Check Service Mesh Policies:**
```bash
# Run comprehensive check
./check-service-mesh.sh proj-poc-aros

# Or manually check
kubectl get authorizationpolicy -n proj-poc-aros
kubectl get peerauthentication -n proj-poc-aros
```

## Testing Authentication

### Use the Test Script
```bash
# Test Whisper
./test-token-auth.sh whisper-large-v3 proj-poc-aros \
  https://whisper-endpoint.apps.cluster.example.com

# Test Mistral
./test-token-auth.sh redhataimistral-small-quantizedw4a16 proj-poc-aros \
  https://mistral-endpoint.apps.cluster.example.com
```

### Manual Testing
```bash
# 1. Extract token
TOKEN=$(kubectl get secret whisper-large-v3-sa-token -n proj-poc-aros \
  -o jsonpath='{.data.token}' | base64 -d)

# 2. Test /v1/models endpoint
curl -i -H "Authorization: Bearer $TOKEN" \
  https://your-endpoint/v1/models

# 3. Test inference
curl -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "whisper-large-v3",
    "file": "audio.wav"
  }' \
  https://your-endpoint/v1/audio/transcriptions
```

## Expected Behavior

### In OpenShift AI Dashboard
You should see:
- **Token name**: `whisper-large-v3-sa-token` (or mistral equivalent)
- **Token secret**: A long JWT string (starts with `eyJ...`)
- **Resource name**: The ServiceAccount name

### API Behavior
- Without token: 401 Unauthorized or 403 Forbidden
- With valid token: 200 OK with proper response
- With malformed token: 400 Bad Request
- With expired token: 401 Unauthorized

## Re-deployment Steps

```bash
# 1. Package the Helm chart
cd /Users/sherwang/Repo/proj-poc-aros
helm package helm/

# 2. Upgrade existing deployment
helm upgrade proj-poc-aros proj-poc-aros-1.0.0.tgz -n proj-poc-aros

# 3. Verify resources were created
kubectl get sa,secret -n proj-poc-aros | grep -E "whisper|mistral"

# 4. Check InferenceService status
kubectl get inferenceservice -n proj-poc-aros

# 5. Run diagnostics
./diagnose-auth.sh whisper-large-v3 proj-poc-aros
./diagnose-auth.sh redhataimistral-small-quantizedw4a16 proj-poc-aros
```

## Additional Notes

### Why Tokens Might Not Show in UI
The OpenShift AI dashboard detects tokens based on:
1. The `security.opendatahub.io/enable-auth: "true"` annotation
2. The ServiceAccount reference in the InferenceService
3. The existence of associated token secrets
4. Proper labels on all resources

If everything is configured correctly but the UI still doesn't show the token:
- The OpenShift AI operator might need time to reconcile (wait 1-2 minutes)
- Try logging out and back into the OpenShift AI dashboard
- Check OpenShift AI operator logs: `kubectl logs -n redhat-ods-operator deployment/rhods-operator`

### Service Mesh Considerations
If your cluster uses OpenShift Service Mesh (Istio):
- The `security.opendatahub.io/enable-auth` annotation should configure mesh policies automatically
- If it doesn't, you may need to create custom AuthorizationPolicies
- Check for PeerAuthentication policies that might conflict

## Getting Help

If issues persist:
1. Run both diagnostic scripts and save output
2. Check InferenceService events: `kubectl describe inferenceservice <name> -n proj-poc-aros`
3. Check pod logs: `kubectl logs -n proj-poc-aros -l serving.kserve.io/inferenceservice=whisper-large-v3`
4. Review OpenShift AI operator logs
5. Consult Red Hat OpenShift AI documentation on model serving authentication

