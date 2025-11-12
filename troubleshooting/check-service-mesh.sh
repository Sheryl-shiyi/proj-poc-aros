#!/bin/bash

# Check Service Mesh and Authorization Configuration
# Usage: ./check-service-mesh.sh <namespace>

NAMESPACE=${1:-"proj-poc-aros"}

echo "=========================================="
echo "Service Mesh & Authorization Check"
echo "=========================================="
echo "Namespace: $NAMESPACE"
echo ""

# Check if Service Mesh is installed
echo "1. Service Mesh Installation"
echo "-----------------------------------"
kubectl get namespace istio-system 2>/dev/null && echo "✓ Istio/Service Mesh is installed" || echo "✗ Istio/Service Mesh not found"
echo ""

# Check if namespace is part of Service Mesh
echo "2. Namespace Service Mesh Configuration"
echo "-----------------------------------"
MESH_LABEL=$(kubectl get namespace $NAMESPACE -o jsonpath='{.metadata.labels.istio-injection}' 2>/dev/null)
if [ "$MESH_LABEL" == "enabled" ]; then
    echo "✓ Namespace has istio-injection enabled"
else
    echo "  Istio injection: $MESH_LABEL (not enabled)"
fi

MEMBER_LABEL=$(kubectl get namespace $NAMESPACE -o jsonpath='{.metadata.labels.maistra\.io/member-of}' 2>/dev/null)
if [ -n "$MEMBER_LABEL" ]; then
    echo "✓ Namespace is member of Service Mesh: $MEMBER_LABEL"
else
    echo "  Not a Service Mesh member"
fi
echo ""

# Check AuthorizationPolicies
echo "3. AuthorizationPolicies in Namespace"
echo "-----------------------------------"
AUTH_POLICIES=$(kubectl get authorizationpolicy -n $NAMESPACE 2>/dev/null)
if [ $? -eq 0 ]; then
    echo "$AUTH_POLICIES"
    echo ""
    echo "Detailed policies:"
    kubectl get authorizationpolicy -n $NAMESPACE -o yaml 2>/dev/null | grep -A 30 "kind: AuthorizationPolicy" | head -50
else
    echo "  No AuthorizationPolicies found or not accessible"
fi
echo ""

# Check PeerAuthentication
echo "4. PeerAuthentication in Namespace"
echo "-----------------------------------"
PEER_AUTH=$(kubectl get peerauthentication -n $NAMESPACE 2>/dev/null)
if [ $? -eq 0 ]; then
    echo "$PEER_AUTH"
    echo ""
    kubectl get peerauthentication -n $NAMESPACE -o yaml 2>/dev/null | grep -A 20 "kind: PeerAuthentication" | head -30
else
    echo "  No PeerAuthentication found or not accessible"
fi
echo ""

# Check RequestAuthentication
echo "5. RequestAuthentication in Namespace"
echo "-----------------------------------"
REQ_AUTH=$(kubectl get requestauthentication -n $NAMESPACE 2>/dev/null)
if [ $? -eq 0 ]; then
    echo "$REQ_AUTH"
    echo ""
    kubectl get requestauthentication -n $NAMESPACE -o yaml 2>/dev/null | grep -A 30 "kind: RequestAuthentication" | head -50
else
    echo "  No RequestAuthentication found or not accessible"
fi
echo ""

# Check RBAC
echo "6. RBAC Resources in Namespace"
echo "-----------------------------------"
echo "Roles:"
kubectl get role -n $NAMESPACE | grep -E "whisper|mistral|NAME" || echo "No matching roles"
echo ""
echo "RoleBindings:"
kubectl get rolebinding -n $NAMESPACE | grep -E "whisper|mistral|NAME" || echo "No matching rolebindings"
echo ""

# Check ServiceAccounts and their roles
echo "7. ServiceAccount Details"
echo "-----------------------------------"
for sa in $(kubectl get sa -n $NAMESPACE -o name | grep -E "whisper|mistral"); do
    echo "ServiceAccount: $sa"
    SA_NAME=$(echo $sa | cut -d/ -f2)
    
    # Find RoleBindings for this SA
    echo "  RoleBindings:"
    kubectl get rolebinding -n $NAMESPACE -o json | \
        python3 -c "
import sys, json
data = json.load(sys.stdin)
for item in data.get('items', []):
    for subject in item.get('subjects', []):
        if subject.get('name') == '$SA_NAME':
            print(f\"    - {item['metadata']['name']} -> {item['roleRef']['name']}\")
" 2>/dev/null || echo "    Could not parse rolebindings"
    echo ""
done

# Check pods and their sidecar injection
echo "8. Pods and Istio Sidecars"
echo "-----------------------------------"
kubectl get pods -n $NAMESPACE -o custom-columns=NAME:.metadata.name,CONTAINERS:.spec.containers[*].name,STATUS:.status.phase 2>/dev/null
echo ""

# Check for OpenShift AI specific resources
echo "9. OpenShift AI Authorization Resources"
echo "-----------------------------------"
echo "Checking for odh-model-controller resources..."
kubectl get deployment odh-model-controller -n redhat-ods-operator 2>/dev/null && echo "✓ ODH Model Controller found" || echo "  ODH Model Controller not found"
echo ""

# Summary and recommendations
echo "=========================================="
echo "Summary & Recommendations"
echo "=========================================="
echo ""
echo "If you're getting 'authorization server error':"
echo ""
echo "1. Check if Service Mesh is blocking requests:"
echo "   - Look for restrictive AuthorizationPolicies above"
echo "   - Look for PeerAuthentication with STRICT mTLS"
echo ""
echo "2. Verify RBAC permissions:"
echo "   - ServiceAccount should have Role/RoleBinding"
echo "   - Role should allow access to InferenceService"
echo ""
echo "3. Check token audience claim:"
echo "   - Run: ./inspect-token.sh <model-name> $NAMESPACE"
echo "   - Audience should match expected value"
echo ""
echo "4. Check OpenShift AI configuration:"
echo "   - Verify security.opendatahub.io/enable-auth annotation"
echo "   - Check ODH operator logs for errors"
echo ""

