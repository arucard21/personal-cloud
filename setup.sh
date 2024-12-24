#!/bin/sh

# Requirements
#
# - docker and k3d (or an existing kubernetes cluster that is configured as default cluster for kubectl)
# - kubectl
# - helm
# - base64 (non-critical for cluster setup)
#

# Create kubernetes cluster
#
# Creates a single server node for a simple but non-high-availability configuration
# Disables the default loadbalancer that distributes traffic to multiple nodes since we only have one node
k3d cluster create --no-lb --k3s-arg="--disable=traefik@server:0" personal-cloud

# Install Argo CD without ingress
helm install argo-cd argo-cd/ --create-namespace --namespace argocd --version 7.7.11 --dependency-update --wait --set "argo-cd.server.ingress.enabled=false" --set "argo-cd.server.ingressGrpc.enabled=false"

# Install Istio to ensure access to Argo CD and other applications from outside the cluster
kubectl apply -f istio.yaml
kubectl wait --for="jsonpath={.status.health.status}=Healthy" application/istio -n argocd --timeout=60s
# Install Istio gateway separately since its installation will fail if Istio is not completely installed yet.
kubectl apply -f istio-gateway.yaml
kubectl wait --for="jsonpath={.status.health.status}=Healthy" application/istio-gateway -n argocd --timeout=60s

# Add Argo CD as application in Argo CD so it can also be managed from there. This also configures the ingress which should now work with Istio.
kubectl apply -f argo-cd.yaml --wait
kubectl wait --for="jsonpath={.status.health.status}=Healthy" application/argo-cd -n argocd --timeout=60s

# Install the personal cloud suite of applications
kubectl apply -f personal-cloud.yaml
kubectl wait --for="jsonpath={.status.health.status}=Healthy" application/nextcloud -n argocd --timeout=60s

# Provide information needed to access the Argo CD UI
initialPassword=`kubectl get secret -n argocd argocd-initial-admin-secret -o "jsonpath={.data.password}" | base64 -d`
externalIp=`kubectl get services -n istio-system istio-gateway -o "jsonpath={.status.loadBalancer.ingress[].ip}"`
echo
echo "Please ensure that the following host names resolve to the server IP address $externalIp"
echo "\targocd.personal.cloud"
echo "\tgrpc.argocd.personal.cloud (for use with argocd CLI)"
echo "\tnextcloud.personal.cloud"
echo
echo "Argo CD should now be available at http://argocd.personal.cloud"
echo "You can log in with username admin and password $initialPassword"
echo
echo "Nextcloud should now be available at http://nextcloud.personal.cloud"
echo "You can log in with username admin and password changeme"
