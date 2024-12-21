#!/bin/sh

# Requirements
#
# - docker and k3d (or an existing kubernetes cluster that is configured as default cluster for kubectl)
# - kubectl
# - telepresence (non-critical for cluster setup)
# - base64 (non-critical for cluster setup)
#

# Create kubernetes cluster (can be skipped if a kubernetes cluster is already available)
# Only creates a single server node and no agent nodes, for a simpler but non-high-availability configuration
# Does not install the in-cluster ingress controller (traefik) on the server node
# Disables the default loadbalancer that distributes traffic to multiple nodes since we only have one node
k3d cluster create --no-lb personal-cloud

# Install telepresence in the cluster
telepresence helm install

# Install Argo CD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Allow access to Argo CD UI by providing access to all internal services with telepresence
telepresence connect

# Wait until the initial password has been configured for Argo CD
kubectl wait --for=create secret/argocd-initial-admin-secret -n argocd
initialPassword=`kubectl get secret -n argocd argocd-initial-admin-secret -o "jsonpath={.data.password}" | base64 -d`

# Provide information needed to access the Argo CD UI
echo
echo "Argo CD is now available at https://argocd-server.argocd"
echo "You can log in with username admin and password $initialPassword"


# Provide instructions to install the personal-cloud app
echo
echo "You can install the personal cloud applications through the UI or with the following command"
echo
echo "kubectl apply -n argocd -f personal-cloud.yaml"
