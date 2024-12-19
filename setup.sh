#!/bin/sh

# Requirements
#
# - docker and k3d (or an existing kubernetes cluster that is configured as default cluster for kubectl)
# - kubectl
# - telepresence
# - base64
#

# Create kubernetes cluster (can be skipped if a kubernetes cluster is already available)
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
