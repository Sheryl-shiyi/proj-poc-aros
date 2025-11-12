#!/bin/bash

# Diagnose Token Authentication Setup
# Usage: ./diagnose-auth.sh <model-name> <namespace>

MODEL_NAME=${1:-"whisper-large-v3"}
NAMESPACE=${2:-"proj-poc-aros"}

echo "=========================================="
echo "Token Authentication Diagnostics"
echo "=========================================="
echo "Model: $MODEL_NAME"
echo "Namespace: $NAMESPACE"
echo ""

# Check InferenceService
echo "1. InferenceService Configuration"
echo "-----------------------------------"
kubectl get inferenceservice $MODEL_NAME -n $NAMESPACE -o yaml 2>&1 | grep -A 20 "metadata:" | head -25
echo ""

echo "   Checking auth annotation..."
AUTH_ANNOTATION=$(kubectl get inferenceservice $MODEL_NAME -n $NAMESPACE -o jsonpath='{.metadata.annotations.security\.opendatahub\.io/enable-auth}' 2>/dev/null)
if [ "$AUTH_ANNOTATION" == "true" ]; then
    echo "   ✓ Auth annotation is enabled"
else
    echo "   ✗ Auth annotation is NOT set or is false"
fi
echo ""

echo "   Checking serviceAccountName..."
SA_NAME=$(kubectl get inferenceservice $MODEL_NAME -n $NAMESPACE -o jsonpath='{.spec.predictor.serviceAccountName}' 2>/dev/null)
if [ -n "$SA_NAME" ]; then
    echo "   ✓ ServiceAccount referenced: $SA_NAME"
else
    echo "   ✗ No ServiceAccount referenced in InferenceService"
fi
echo ""

# Check ServiceAccount
echo "2. ServiceAccount Status"
echo "-----------------------------------"
kubectl get serviceaccount ${MODEL_NAME}-sa -n $NAMESPACE 2>&1
echo ""

if kubectl get serviceaccount ${MODEL_NAME}-sa -n $NAMESPACE &>/dev/null; then
    echo "   ServiceAccount details:"
    kubectl get serviceaccount ${MODEL_NAME}-sa -n $NAMESPACE -o yaml | grep -A 10 "metadata:"
    echo ""
else
    echo "   ✗ ServiceAccount not found"
fi

# Check Token Secret
echo "3. Token Secret Status"
echo "-----------------------------------"
kubectl get secret ${MODEL_NAME}-sa-token -n $NAMESPACE 2>&1
echo ""

if kubectl get secret ${MODEL_NAME}-sa-token -n $NAMESPACE &>/dev/null; then
    echo "   Token secret details:"
    kubectl get secret ${MODEL_NAME}-sa-token -n $NAMESPACE -o yaml | grep -A 15 "metadata:"
    echo ""
    
    echo "   Checking token content..."
    TOKEN_DATA=$(kubectl get secret ${MODEL_NAME}-sa-token -n $NAMESPACE -o jsonpath='{.data.token}' 2>/dev/null)
    if [ -n "$TOKEN_DATA" ]; then
        TOKEN=$(echo $TOKEN_DATA | base64 -d)
        echo "   ✓ Token exists (length: ${#TOKEN} chars)"
        echo "   Token preview: ${TOKEN:0:50}..."
    else
        echo "   ✗ Token data is empty or not found in secret"
    fi
else
    echo "   ✗ Token secret not found"
fi
echo ""

# Check for any other secrets related to the model
echo "4. All Secrets in Namespace"
echo "-----------------------------------"
kubectl get secrets -n $NAMESPACE | grep -E "$MODEL_NAME|NAME" || echo "No matching secrets found"
echo ""

# Check InferenceService status
echo "5. InferenceService Status"
echo "-----------------------------------"
kubectl get inferenceservice $MODEL_NAME -n $NAMESPACE -o jsonpath='{.status.conditions}' | python3 -m json.tool 2>/dev/null || kubectl get inferenceservice $MODEL_NAME -n $NAMESPACE -o jsonpath='{.status.conditions}'
echo ""
echo ""

# Check for related resources
echo "6. Related Resources"
echo "-----------------------------------"
echo "   Pods:"
kubectl get pods -n $NAMESPACE -l serving.kserve.io/inferenceservice=$MODEL_NAME
echo ""

echo "   Services:"
kubectl get svc -n $NAMESPACE | grep $MODEL_NAME
echo ""

# Summary
echo "=========================================="
echo "Summary"
echo "=========================================="
echo "Please verify:"
echo "1. ✓ InferenceService has security.opendatahub.io/enable-auth: 'true'"
echo "2. ✓ InferenceService references serviceAccountName"
echo "3. ✓ ServiceAccount exists with correct labels"
echo "4. ✓ Token secret exists and contains valid token data"
echo "5. ✓ InferenceService is in Ready state"
echo ""
echo "If all checks pass but token still doesn't show in OpenShift AI:"
echo "- Try refreshing the OpenShift AI dashboard"
echo "- Check OpenShift AI operator logs for errors"
echo "- Verify OpenShift AI version compatibility"
echo ""

