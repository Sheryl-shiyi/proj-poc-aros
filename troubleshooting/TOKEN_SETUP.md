# Token Authentication Setup and Usage

## Overview

Both models (Whisper and Mistral) are deployed with token authentication enabled. To access the models via their external endpoints, you'll need to use the ServiceAccount tokens.

## Extracting and Using Tokens

### Quick Test with Script

Use the provided test script to extract and test token authentication:

```bash
# Test Whisper model
./troubleshooting/test-token-auth.sh whisper-large-v3 proj-poc-aros https://your-whisper-endpoint

# Test Mistral model  
./troubleshooting/test-token-auth.sh redhataimistral-small-quantizedw4a16 proj-poc-aros https://your-mistral-endpoint
```

### Manual Token Extraction

```bash
# Extract the token
TOKEN=$(kubectl get secret whisper-large-v3-sa-token -n proj-poc-aros -o jsonpath='{.data.token}' | base64 -d)

# Use the token in API calls
curl -H "Authorization: Bearer $TOKEN" \
     -H "Content-Type: application/json" \
     https://your-model-endpoint/v1/models
```

## Viewing Tokens in OpenShift AI Dashboard

After deployment, the tokens should be visible in the OpenShift AI dashboard under **Models and model servers** → Select your model → **Token authentication** section.

### If Token Doesn't Appear

If the token doesn't appear in the UI immediately:
1. Verify the ServiceAccount was created: `kubectl get sa -n proj-poc-aros`
2. Verify the token secret exists: `kubectl get secret -n proj-poc-aros | grep token`
3. Check InferenceService annotations: `kubectl get inferenceservice -n proj-poc-aros -o yaml`
4. Try refreshing the OpenShift AI dashboard

## Troubleshooting Authentication Issues

If you encounter authentication errors when calling the endpoints:

### Quick Fix for "Authorization Server Error"
See [FIX_AUTH_ERROR.md](FIX_AUTH_ERROR.md) for step-by-step resolution.

### Diagnostic Scripts

```bash
# Run comprehensive diagnostics
./troubleshooting/diagnose-auth.sh whisper-large-v3 proj-poc-aros

# Check Service Mesh configuration
./troubleshooting/check-service-mesh.sh proj-poc-aros

# Inspect token claims
./troubleshooting/inspect-token.sh whisper-large-v3 proj-poc-aros
```

### Complete Troubleshooting Guide
See [TOKEN_AUTH_GUIDE.md](TOKEN_AUTH_GUIDE.md) for comprehensive troubleshooting.

## Using Tokens in Your Applications

### Python Example

```python
import requests
import subprocess
import base64

# Extract token
result = subprocess.run(
    ['kubectl', 'get', 'secret', 'whisper-large-v3-sa-token', 
     '-n', 'proj-poc-aros', '-o', 'jsonpath={.data.token}'],
    capture_output=True, text=True
)
token = base64.b64decode(result.stdout).decode('utf-8')

# Make API call
headers = {
    'Authorization': f'Bearer {token}',
    'Content-Type': 'application/json'
}

response = requests.get('https://your-endpoint/v1/models', headers=headers)
print(response.json())
```

### cURL Example

```bash
# Extract token
TOKEN=$(kubectl get secret whisper-large-v3-sa-token -n proj-poc-aros \
  -o jsonpath='{.data.token}' | base64 -d)

# Test model listing
curl -H "Authorization: Bearer $TOKEN" \
     -H "Content-Type: application/json" \
     https://your-whisper-endpoint/v1/models

# Test transcription
curl -H "Authorization: Bearer $TOKEN" \
     -F "file=@audio.wav" \
     -F "model=whisper-large-v3" \
     https://your-whisper-endpoint/v1/audio/transcriptions
```

## Token Management

### Token Expiration

ServiceAccount tokens created as Secrets are long-lived and don't expire automatically. However, if you need a short-lived token:

```bash
# Create a token with 24-hour expiration
kubectl create token whisper-large-v3-sa \
  -n proj-poc-aros \
  --duration=24h
```

### Security Best Practices

1. **Never commit tokens to version control**
2. **Use environment variables** to store tokens in applications
3. **Rotate tokens periodically** for security
4. **Use RBAC** to limit ServiceAccount permissions
5. **Enable audit logging** to track token usage

## Authentication Flow

```
User Request
    ↓
Extract Token from Secret
    ↓
Add to Authorization Header
    ↓
OpenShift Service Mesh
    ↓
Validate Token (RBAC Check)
    ↓
Forward to InferenceService
    ↓
Return Response
```

## Resources Created

Each model has the following authentication resources:

```
For Whisper:
├── ServiceAccount: whisper-large-v3-sa
├── Secret: whisper-large-v3-sa-token
├── Role: whisper-large-v3-access (RBAC)
├── RoleBinding: whisper-large-v3-access
└── InferenceService (with auth enabled)

For Mistral:
├── ServiceAccount: redhataimistral-small-quantizedw4a16-sa
├── Secret: redhataimistral-small-quantizedw4a16-sa-token
├── Role: redhataimistral-small-quantizedw4a16-access (RBAC)
├── RoleBinding: redhataimistral-small-quantizedw4a16-access
└── InferenceService (with auth enabled)
```

## Need Help?

- **Quick troubleshooting**: See [FIX_AUTH_ERROR.md](FIX_AUTH_ERROR.md)
- **Comprehensive guide**: See [TOKEN_AUTH_GUIDE.md](TOKEN_AUTH_GUIDE.md)
- **Tool index**: See [README.md](README.md) in this directory

