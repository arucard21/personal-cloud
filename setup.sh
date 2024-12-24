#!/bin/sh

# Requirements
#
# - docker and k3d (or an existing kubernetes cluster that is configured as default cluster for kubectl)
# - kubectl
# - helm
# - base64 (non-critical for cluster setup)
#

# Create kubernetes cluster (can be skipped if a kubernetes cluster is already available)
#
# Creates a single server node for a simple but non-high-availability configuration
# Disables the default loadbalancer that distributes traffic to multiple nodes since we only have one node
k3d cluster create --no-lb --k3s-arg="--disable=traefik@server:0" personal-cloud

# Install Argo CD
helm install argo-cd argo-cd/ --create-namespace --namespace argocd --version 7.7.11 --dependency-update --wait
# Add Argo CD as application in Argo CD so it can also be managed from there
kubectl apply -f argo-cd.yaml --wait

# Provide information needed to access the Argo CD UI
initialPassword=`kubectl get secret -n argocd argocd-initial-admin-secret -o "jsonpath={.data.password}" | base64 -d`
externalIp=`kubectl get services -n kube-system traefik -o "jsonpath={.status.loadBalancer.ingress[].ip}"`
echo
echo "Please ensure that the following host names resolve to the server IP address $externalIp"
echo "\targocd.personal.cloud"
echo "\tgrpc.argocd.personal.cloud (for use with argocd CLI)"
echo
echo "Argo CD should now be available at http://argocd.personal.cloud"
echo "You can log in with username admin and password $initialPassword"


# Provide instructions to install the personal-cloud app
echo
echo "You can install the personal cloud applications through the UI or with the following command in this repo"
echo
echo "kubectl apply -f personal-cloud.yaml"
