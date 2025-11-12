#!/bin/bash

# Inspect ServiceAccount Token Claims
# Usage: ./inspect-token.sh <model-name> <namespace>

MODEL_NAME=${1:-"whisper-large-v3"}
NAMESPACE=${2:-"proj-poc-aros"}

echo "=========================================="
echo "Token Claims Inspector"
echo "=========================================="
echo "Model: $MODEL_NAME"
echo "Namespace: $NAMESPACE"
echo ""

# Extract token
TOKEN=$(kubectl get secret ${MODEL_NAME}-sa-token -n ${NAMESPACE} -o jsonpath='{.data.token}' | base64 -d)

if [ -z "$TOKEN" ]; then
    echo "ERROR: Could not extract token"
    exit 1
fi

echo "Token extracted successfully (${#TOKEN} chars)"
echo ""

# Decode JWT header and payload
echo "=========================================="
echo "JWT Header"
echo "=========================================="
echo $TOKEN | cut -d. -f1 | base64 -d 2>/dev/null | python3 -m json.tool || echo "Could not decode header"
echo ""

echo "=========================================="
echo "JWT Payload (Claims)"
echo "=========================================="
echo $TOKEN | cut -d. -f2 | base64 -d 2>/dev/null | python3 -m json.tool || echo "Could not decode payload"
echo ""

echo "=========================================="
echo "Key Claims to Verify"
echo "=========================================="
echo "Issuer (iss):"
echo $TOKEN | cut -d. -f2 | base64 -d 2>/dev/null | python3 -c "import sys, json; print(json.load(sys.stdin).get('iss', 'NOT FOUND'))"

echo "Audience (aud):"
echo $TOKEN | cut -d. -f2 | base64 -d 2>/dev/null | python3 -c "import sys, json; print(json.load(sys.stdin).get('aud', 'NOT FOUND'))"

echo "Subject (sub):"
echo $TOKEN | cut -d. -f2 | base64 -d 2>/dev/null | python3 -c "import sys, json; print(json.load(sys.stdin).get('sub', 'NOT FOUND'))"

echo "ServiceAccount (kubernetes.io/serviceaccount/service-account.name):"
echo $TOKEN | cut -d. -f2 | base64 -d 2>/dev/null | python3 -c "import sys, json; print(json.load(sys.stdin).get('kubernetes.io/serviceaccount/service-account.name', 'NOT FOUND'))"

echo "Namespace (kubernetes.io/serviceaccount/namespace):"
echo $TOKEN | cut -d. -f2 | base64 -d 2>/dev/null | python3 -c "import sys, json; print(json.load(sys.stdin).get('kubernetes.io/serviceaccount/namespace', 'NOT FOUND'))"

echo "Expiration (exp):"
EXP=$(echo $TOKEN | cut -d. -f2 | base64 -d 2>/dev/null | python3 -c "import sys, json; print(json.load(sys.stdin).get('exp', 'NOT FOUND'))")
if [ "$EXP" != "NOT FOUND" ]; then
    echo "  Timestamp: $EXP"
    echo "  Date: $(date -r $EXP 2>/dev/null || date -d @$EXP 2>/dev/null || echo 'Could not parse')"
fi

echo ""

