# Troubleshooting Tools

This directory contains diagnostic scripts and documentation for troubleshooting token authentication issues with the deployed models.

## 📁 Files Overview

### Documentation

| File | Description |
|------|-------------|
| **TOKEN_SETUP.md** | Complete guide for token authentication setup and usage - start here for normal usage |
| **FIX_AUTH_ERROR.md** | Quick-fix guide for "authorization server error" - use when you encounter authentication issues |
| **TOKEN_AUTH_GUIDE.md** | Comprehensive troubleshooting guide covering all aspects of token authentication |
| **CHANGES_SUMMARY.md** | Complete log of authentication-related changes made to the project |

### Diagnostic Scripts

| Script | Purpose | Usage |
|--------|---------|-------|
| **test-token-auth.sh** | Extract token and test API endpoints | `./test-token-auth.sh <model-name> <namespace> <endpoint>` |
| **diagnose-auth.sh** | Run comprehensive diagnostics on authentication setup | `./diagnose-auth.sh <model-name> <namespace>` |
| **inspect-token.sh** | Decode and display JWT token claims | `./inspect-token.sh <model-name> <namespace>` |
| **check-service-mesh.sh** | Check Service Mesh/Istio and authorization policies | `./check-service-mesh.sh <namespace>` |

## 🚀 Quick Start

### For normal token usage:

1. **Read the setup guide:**
   ```bash
   cat TOKEN_SETUP.md
   ```

2. **Extract and use your token:**
   ```bash
   TOKEN=$(kubectl get secret whisper-large-v3-sa-token -n proj-poc-aros \
     -o jsonpath='{.data.token}' | base64 -d)
   curl -H "Authorization: Bearer $TOKEN" https://your-endpoint/v1/models
   ```

### If you're having authentication issues:

1. **Start with the quick fix guide:**
   ```bash
   cat FIX_AUTH_ERROR.md
   ```

2. **Run diagnostics:**
   ```bash
   ./diagnose-auth.sh whisper-large-v3 proj-poc-aros
   ```

3. **Check Service Mesh configuration:**
   ```bash
   ./check-service-mesh.sh proj-poc-aros
   ```

4. **Inspect your token:**
   ```bash
   ./inspect-token.sh whisper-large-v3 proj-poc-aros
   ```

### Testing authentication:

```bash
# Test Whisper model
./test-token-auth.sh whisper-large-v3 proj-poc-aros https://your-whisper-endpoint

# Test Mistral model
./test-token-auth.sh redhataimistral-small-quantizedw4a16 proj-poc-aros https://your-mistral-endpoint
```

## 🔍 Common Issues Covered

- ❌ Token not showing in OpenShift AI Dashboard
- ❌ 400 Bad Request errors
- ❌ 401 Unauthorized errors
- ❌ 403 Forbidden errors
- ❌ "Authorization server encountered an unexpected condition" error
- ❌ Service Mesh blocking requests
- ❌ Token audience mismatch
- ❌ Missing RBAC permissions

## 📖 Documentation Hierarchy

```
Normal Usage → TOKEN_SETUP.md (How to use tokens)
    ↓
Issues? → FIX_AUTH_ERROR.md (Quick fixes for common issues)
    ↓
Deep Dive → TOKEN_AUTH_GUIDE.md (Comprehensive troubleshooting)
    ↓
Reference → CHANGES_SUMMARY.md (What changed and why)
```

## 💡 Tips

- **Before running scripts**, make sure you have `kubectl` access to your cluster
- **Scripts require Python 3** for JSON parsing
- **All scripts are safe to run** - they only read information, don't make changes
- **Make scripts executable** if needed: `chmod +x *.sh`

## 🎯 Success Criteria

After following the guides, you should be able to:
- ✅ See token in OpenShift AI Dashboard
- ✅ Extract token using kubectl
- ✅ Call model endpoints with Bearer token
- ✅ Receive 200 OK responses from API calls

## 🆘 Still Need Help?

1. Run all diagnostic scripts and save output
2. Check InferenceService pod logs
3. Review OpenShift AI operator logs
4. Consult TOKEN_AUTH_GUIDE.md for detailed troubleshooting

## 📝 Notes

These tools were created during the token authentication setup and troubleshooting process. They're kept for future reference and to help diagnose any authentication issues that may arise.

The authentication works by:
1. ServiceAccount with token secret
2. RBAC permissions (Role + RoleBinding)
3. InferenceService with `security.opendatahub.io/enable-auth: "true"` annotation
4. OpenShift AI authorization layer validating tokens

