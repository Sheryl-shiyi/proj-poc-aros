# Changes Summary - Token Authentication Fix

## Current Status

✅ **COMPLETED:** Token visible in OpenShift AI Dashboard  
🔧 **IN PROGRESS:** Fixing "authorization server error" when using the token

## What Was the Problem?

You had the token showing in the OpenShift AI UI, but when trying to use it to call the API endpoint, you got:
```
'error': 'server_error', 
'error_description': 'The authorization server encountered an unexpected condition that prevented it from fulfilling the request.'
```

## Root Cause

The ServiceAccount existed and had a valid token, but it was **missing RBAC permissions** to access the InferenceService through OpenShift AI's authorization layer.

## What We Fixed

### 1. Added RBAC Resources

Created for both Whisper and Mistral models:

**`rbac-whisper.yaml`** and **`rbac-mistral.yaml`**:
- **Role**: Grants permissions to get/list InferenceServices and Services
- **RoleBinding**: Binds the ServiceAccount to the Role

These resources give the ServiceAccount the necessary permissions to access the model endpoints.

### 2. Created Diagnostic Scripts

**`inspect-token.sh`**
- Decodes and displays JWT token claims
- Shows issuer, audience, subject, and expiration
- Helps identify token configuration issues

**`check-service-mesh.sh`**
- Checks for Service Mesh (Istio) configuration
- Lists AuthorizationPolicies and PeerAuthentication
- Identifies Service Mesh blocking issues
- Displays RBAC resources

### 3. Updated Documentation

**`FIX_AUTH_ERROR.md`** (NEW)
- Quick-reference guide specifically for the authorization server error
- Step-by-step troubleshooting
- Common fixes and verification steps

**`TOKEN_AUTH_GUIDE.md`** (UPDATED)
- Added detailed section on authorization server errors
- Included RBAC troubleshooting steps
- Added diagnostic procedures

**`README.md`** (UPDATED)
- Added troubleshooting section
- Links to diagnostic scripts and guides

## New Files Created

```
proj-poc-aros/
├── helm/templates/
│   ├── rbac-whisper.yaml (NEW)
│   └── rbac-mistral.yaml (NEW)
├── inspect-token.sh (NEW)
├── check-service-mesh.sh (NEW)
├── FIX_AUTH_ERROR.md (NEW)
├── TOKEN_AUTH_GUIDE.md (UPDATED)
└── README.md (UPDATED)
```

## Complete Resource List Per Model

### Whisper Model
```
Authentication Resources:
├── serviceaccount-whisper.yaml
│   └── Creates: whisper-large-v3-sa
├── token-secret-whisper.yaml
│   └── Creates: whisper-large-v3-sa-token (auto-populated with JWT)
├── rbac-whisper.yaml (NEW)
│   ├── Creates: whisper-large-v3-access (Role)
│   └── Creates: whisper-large-v3-access (RoleBinding)
└── inferenceservice-whisper.yaml
    ├── Annotation: security.opendatahub.io/enable-auth: "true"
    └── Uses: serviceAccountName: whisper-large-v3-sa
```

### Mistral Model
```
Authentication Resources:
├── serviceaccount-mistral.yaml
│   └── Creates: redhataimistral-small-quantizedw4a16-sa
├── token-secret-mistral.yaml
│   └── Creates: redhataimistral-small-quantizedw4a16-sa-token
├── rbac-mistral.yaml (NEW)
│   ├── Creates: redhataimistral-small-quantizedw4a16-access (Role)
│   └── Creates: redhataimistral-small-quantizedw4a16-access (RoleBinding)
└── inferenceservice-mistral.yaml
    ├── Annotation: security.opendatahub.io/enable-auth: "true"
    └── Uses: serviceAccountName: redhataimistral-small-quantizedw4a16-sa
```

## Next Steps for You

### 1. Deploy Updated Chart (Required)

```bash
# This will add the RBAC resources
helm upgrade proj-poc-aros proj-poc-aros-1.0.0.tgz -n proj-poc-aros

# Wait for resources to be created (30-60 seconds)
kubectl get role,rolebinding -n proj-poc-aros | grep -E "whisper|mistral"
```

You should see:
```
role.rbac.authorization.k8s.io/whisper-large-v3-access
role.rbac.authorization.k8s.io/redhataimistral-small-quantizedw4a16-access
rolebinding.rbac.authorization.k8s.io/whisper-large-v3-access
rolebinding.rbac.authorization.k8s.io/redhataimistral-small-quantizedw4a16-access
```

### 2. Run Diagnostics

```bash
# Check everything is configured correctly
./check-service-mesh.sh proj-poc-aros

# Inspect token to ensure it's valid
./inspect-token.sh whisper-large-v3 proj-poc-aros
```

### 3. Test Authentication

```bash
# Test with your endpoint
./test-token-auth.sh whisper-large-v3 proj-poc-aros \
  https://your-whisper-endpoint-url

# Or manually
TOKEN=$(kubectl get secret whisper-large-v3-sa-token -n proj-poc-aros \
  -o jsonpath='{.data.token}' | base64 -d)

curl -H "Authorization: Bearer $TOKEN" \
  https://your-whisper-endpoint/v1/models
```

### 4. If Still Getting Errors

Refer to [FIX_AUTH_ERROR.md](FIX_AUTH_ERROR.md) for:
- Service Mesh blocking issues
- Token audience problems
- Additional RBAC configuration

## What Should Happen Now

After deploying the updated Helm chart:

1. ✅ RBAC permissions will be granted to ServiceAccounts
2. ✅ ServiceAccounts can access InferenceService endpoints
3. ✅ API calls with token should return 200 OK
4. ✅ Authorization server error should be resolved

## Testing Success Criteria

**Success looks like:**
```bash
$ curl -H "Authorization: Bearer $TOKEN" https://your-endpoint/v1/models
HTTP/1.1 200 OK
{
  "object": "list",
  "data": [
    {
      "id": "whisper-large-v3",
      "object": "model",
      ...
    }
  ]
}
```

**Still need to troubleshoot if you see:**
- 401 Unauthorized → Token format or expired
- 403 Forbidden → RBAC or Service Mesh blocking
- 404 Not Found → Wrong endpoint URL
- 500 Server Error → Check InferenceService pod logs

## Summary

The "authorization server error" was caused by missing RBAC permissions. The ServiceAccount had a valid token but wasn't allowed to access the InferenceService resources.

The fix adds Role and RoleBinding resources that grant the necessary permissions.

After deploying the updated Helm chart, your token authentication should work end-to-end! 🎉

## Questions?

- For step-by-step troubleshooting: See [FIX_AUTH_ERROR.md](FIX_AUTH_ERROR.md)
- For comprehensive documentation: See [TOKEN_AUTH_GUIDE.md](TOKEN_AUTH_GUIDE.md)
- For diagnostic commands: Use the provided shell scripts

