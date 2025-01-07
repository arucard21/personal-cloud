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

# Perform initial installation of Argo CD without ingress
helm install argo-cd charts/argo-cd/ --create-namespace --namespace argocd --set "global.domain=argocd.personal.cloud" --set "argo-cd.server.ingress.enabled=false" --dependency-update --wait

# Install infrastructure
kubectl apply -f  infrastructure/production/personal-cloud-infrastructure.yaml --wait

# Wait for each part of the infrastructure to be installed
kubectl wait --for="jsonpath={.status.health.status}=Healthy" application/personal-cloud-infrastructure -n argocd --timeout=60s
kubectl wait --for=create application/istio -n argocd --timeout=60s
kubectl wait --for="jsonpath={.status.health.status}=Healthy" application/istio -n argocd --timeout=60s
kubectl wait --for=create application/istio-gateway -n argocd --timeout=60s
kubectl wait --for="jsonpath={.status.health.status}=Healthy" application/istio-gateway -n argocd --timeout=60s
kubectl wait --for=create application/argo-cd -n argocd --timeout=60s
kubectl wait --for="jsonpath={.status.health.status}=Healthy" application/argo-cd -n argocd --timeout=60s

# Install the personal cloud suite of applications
kubectl apply -f applications/production/personal-cloud.yaml --wait

# Wait for each applicatoin to be installed
kubectl wait --for="jsonpath={.status.health.status}=Healthy" application/personal-cloud -n argocd --timeout=60s
kubectl wait --for=create application/nextcloud -n argocd --timeout=60s
kubectl wait --for="jsonpath={.status.health.status}=Healthy" application/nextcloud -n argocd --timeout=120s

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
