# Quick Fix: Authorization Server Error

## The Problem

You're seeing this error:
```
'error': 'server_error', 
'error_description': 'The authorization server encountered an unexpected condition that prevented it from fulfilling the request.'
```

✅ Token is visible in OpenShift AI Dashboard  
❌ API calls fail with authorization server error

## Most Likely Cause

**Missing RBAC Permissions** - The ServiceAccount token exists but the ServiceAccount doesn't have permission to access the InferenceService through OpenShift AI's authorization layer.

## Quick Fix Steps

### 1. Deploy Updated Helm Chart with RBAC

The chart now includes Role and RoleBinding resources:

```bash
# Upgrade deployment
helm upgrade proj-poc-aros proj-poc-aros-1.0.0.tgz -n proj-poc-aros

# Verify RBAC resources were created
kubectl get role,rolebinding -n proj-poc-aros | grep -E "whisper|mistral"
```

Expected output:
```
role.rbac.authorization.k8s.io/whisper-large-v3-access
role.rbac.authorization.k8s.io/redhataimistral-small-quantizedw4a16-access
rolebinding.rbac.authorization.k8s.io/whisper-large-v3-access
rolebinding.rbac.authorization.k8s.io/redhataimistral-small-quantizedw4a16-access
```

### 2. Run Diagnostics

```bash
# Check Service Mesh and authorization configuration
./check-service-mesh.sh proj-poc-aros

# Inspect token claims
./inspect-token.sh whisper-large-v3 proj-poc-aros

# Test with token
./test-token-auth.sh whisper-large-v3 proj-poc-aros \
  https://your-whisper-endpoint
```

### 3. Verify RBAC Permissions

```bash
# Check if ServiceAccount can access InferenceService
kubectl auth can-i get inferenceservices \
  --as=system:serviceaccount:proj-poc-aros:whisper-large-v3-sa \
  -n proj-poc-aros

# Should return: yes
```

## If Problem Persists

### Check 1: Service Mesh Blocking

```bash
# Look for restrictive AuthorizationPolicies
kubectl get authorizationpolicy -n proj-poc-aros
kubectl get authorizationpolicy -n istio-system

# Look for strict mTLS requirements
kubectl get peerauthentication -n proj-poc-aros
```

If you find restrictive policies, you may need to add an allow policy:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: allow-serviceaccount-access
  namespace: proj-poc-aros
spec:
  action: ALLOW
  rules:
    - from:
        - source:
            principals:
              - "cluster.local/ns/proj-poc-aros/sa/whisper-large-v3-sa"
              - "cluster.local/ns/proj-poc-aros/sa/redhataimistral-small-quantizedw4a16-sa"
EOF
```

### Check 2: Token Audience Mismatch

```bash
# Inspect token to see audience claim
./inspect-token.sh whisper-large-v3 proj-poc-aros

# If audience doesn't match, create new token with correct audience
TOKEN=$(kubectl create token whisper-large-v3-sa \
  -n proj-poc-aros \
  --audience=https://kubernetes.default.svc \
  --duration=24h)

# Use this token in your API calls
curl -H "Authorization: Bearer $TOKEN" \
  https://your-endpoint/v1/models
```

### Check 3: OpenShift AI Operator Issues

```bash
# Check ODH operator logs for errors
kubectl logs -n redhat-ods-operator \
  deployment/odh-model-controller --tail=100 | grep -i error

# Check if authorization webhook is working
kubectl get validatingwebhookconfiguration | grep odh
kubectl get mutatingwebhookconfiguration | grep odh
```

### Check 4: Verify InferenceService Configuration

```bash
# Ensure InferenceService has correct annotations
kubectl get inferenceservice whisper-large-v3 -n proj-poc-aros -o yaml | grep -A 5 "annotations:"

# Should see:
#   security.opendatahub.io/enable-auth: "true"

# Ensure ServiceAccount is referenced
kubectl get inferenceservice whisper-large-v3 -n proj-poc-aros \
  -o jsonpath='{.spec.predictor.serviceAccountName}'

# Should output: whisper-large-v3-sa
```

## Test Again

After making changes, test with:

```bash
# Extract fresh token
TOKEN=$(kubectl get secret whisper-large-v3-sa-token -n proj-poc-aros \
  -o jsonpath='{.data.token}' | base64 -d)

# Test /v1/models endpoint
curl -v -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  https://your-whisper-endpoint/v1/models

# If successful, you should see:
# HTTP/1.1 200 OK
# {"object":"list","data":[...]}
```

## Common Error Codes After Fix

- **200 OK** = ✅ Authentication working!
- **401 Unauthorized** = Token expired or invalid format
- **403 Forbidden** = RBAC permissions issue
- **404 Not Found** = Wrong endpoint URL
- **500 Internal Server Error** = Backend issue (not auth related)

## Still Having Issues?

1. Collect diagnostic output:
```bash
./diagnose-auth.sh whisper-large-v3 proj-poc-aros > diagnostics.txt
./check-service-mesh.sh proj-poc-aros >> diagnostics.txt
./inspect-token.sh whisper-large-v3 proj-poc-aros >> diagnostics.txt
```

2. Check InferenceService pod logs:
```bash
kubectl logs -n proj-poc-aros \
  -l serving.kserve.io/inferenceservice=whisper-large-v3 \
  --all-containers --tail=100
```

3. Review the complete TOKEN_AUTH_GUIDE.md for detailed troubleshooting

## Summary of What Changed

The updated Helm chart now includes:
- ✅ ServiceAccount (already had)
- ✅ Token Secret (already had)
- ✅ **Role** (NEW) - Grants permissions to access InferenceService
- ✅ **RoleBinding** (NEW) - Binds ServiceAccount to Role

The Role grants these permissions:
- Get and list InferenceServices
- Get and list Services

This should resolve the "authorization server encountered an unexpected condition" error.

