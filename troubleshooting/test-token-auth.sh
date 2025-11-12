#!/bin/bash

# Test Token Authentication for InferenceService
# Usage: ./test-token-auth.sh <model-name> <namespace> <endpoint>

MODEL_NAME=${1:-"whisper-large-v3"}
NAMESPACE=${2:-"proj-poc-aros"}
ENDPOINT=$3

echo "=========================================="
echo "Testing Token Authentication"
echo "=========================================="
echo "Model: $MODEL_NAME"
echo "Namespace: $NAMESPACE"
echo ""

# Extract the token from the secret
echo "1. Extracting token from secret ${MODEL_NAME}-sa-token..."
TOKEN=$(kubectl get secret ${MODEL_NAME}-sa-token -n ${NAMESPACE} -o jsonpath='{.data.token}' | base64 -d)

if [ -z "$TOKEN" ]; then
    echo "ERROR: Could not extract token from secret"
    echo "Checking if secret exists..."
    kubectl get secret ${MODEL_NAME}-sa-token -n ${NAMESPACE}
    exit 1
fi

echo "✓ Token extracted successfully"
echo ""

# Display token info
echo "2. Token Info:"
echo "   Token (first 50 chars): ${TOKEN:0:50}..."
echo "   Token length: ${#TOKEN} characters"
echo ""

# Test the ServiceAccount
echo "3. Checking ServiceAccount..."
kubectl get serviceaccount ${MODEL_NAME}-sa -n ${NAMESPACE}
echo ""

# Check InferenceService status
echo "4. Checking InferenceService status..."
kubectl get inferenceservice ${MODEL_NAME} -n ${NAMESPACE}
echo ""

# If endpoint provided, test it
if [ -n "$ENDPOINT" ]; then
    echo "5. Testing endpoint: $ENDPOINT"
    echo ""
    
    echo "Test 1: With Authorization header (Bearer token)"
    curl -v -H "Authorization: Bearer $TOKEN" \
         -H "Content-Type: application/json" \
         "$ENDPOINT/v1/models" 2>&1 | head -30
    echo ""
    
    echo "=========================================="
    echo "Test 2: Sample inference request"
    curl -H "Authorization: Bearer $TOKEN" \
         -H "Content-Type: application/json" \
         -d '{
           "model": "'$MODEL_NAME'",
           "prompt": "Hello, how are you?",
           "max_tokens": 50
         }' \
         "$ENDPOINT/v1/completions"
    echo ""
else
    echo "5. No endpoint provided, skipping API tests"
    echo "   To test with endpoint, run:"
    echo "   ./test-token-auth.sh $MODEL_NAME $NAMESPACE https://your-endpoint"
fi

echo ""
echo "=========================================="
echo "Token authentication test complete"
echo "=========================================="

