#!/usr/bin/env bash

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
echo "Creating k3d cluster"
k3d cluster create --no-lb --k3s-arg="--disable=traefik@server:0" personal-cloud

# Show the cluster IP that must be configured in your hosts file
echo -n "Cluster IP address: "
clusterip=`docker inspect k3d-personal-cloud-server-0 --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'`
echo $clusterip

if [ `grep -c $clusterip /etc/hosts` -eq 0 ]
then
	echo
	echo "Add this to your hosts file before continuing"
	echo "$clusterip personal.cloud argocd.personal.cloud git.personal.cloud nextcloud.personal.cloud"
	echo
	read -p "Press Enter to continue after updating your hosts file"
fi

# Perform initial installation of Istio so gateways and ingresses can be configured
echo "Install Istio"
helm install istio charts/istio/ --create-namespace --namespace istio-system --dependency-update --wait
echo "Install Istio Gateway"
helm install istio-gateway charts/istio-gateway/ --namespace istio-system --dependency-update --wait

# Perform initial installation of Gitea
echo "Install Gitea"
helm install gitea charts/gitea/ --create-namespace --namespace git --dependency-update --wait

# Perform initial installation of Argo CD
echo "Install Argo CD"
helm install argo-cd charts/argo-cd/ --create-namespace --namespace argocd --dependency-update --wait

echo "Create gitops repositories"
# Can be done manually in the Gitea Web UI at http://git.personal.cloud
curl -X POST "http://git.personal.cloud/api/v1/user/repos" --user "cloudadmin:personalcloudadmin" -H "accept: application/json" -H "Content-Type: application/json" -d "{\"name\": \"gitops-charts\"}" -i
curl -X POST "http://git.personal.cloud/api/v1/user/repos" --user "cloudadmin:personalcloudadmin" -H "accept: application/json" -H "Content-Type: application/json" -d "{\"name\": \"gitops-infrastructure\"}" -i
curl -X POST "http://git.personal.cloud/api/v1/user/repos" --user "cloudadmin:personalcloudadmin" -H "accept: application/json" -H "Content-Type: application/json" -d "{\"name\": \"gitops-applications\"}" -i
cd charts/
git init -b main
git add .
git commit -m "Initial commit"
git remote add origin http://cloudadmin:personalcloudadmin@git.personal.cloud/cloudadmin/gitops-charts.git
git push -u origin main
cd ../infrastructure/
git init -b main
git add .
git commit -m "Initial commit"
git remote add origin http://cloudadmin:personalcloudadmin@git.personal.cloud/cloudadmin/gitops-infrastructure.git
git push -u origin main
cd ../applications/
git init -b main
git add .
git commit -m "Initial commit"
git remote add origin http://cloudadmin:personalcloudadmin@git.personal.cloud/cloudadmin/gitops-applications.git
git push -u origin main
cd ..

# Show some useful information about how to access Argo CD
echo "Argo CD UI credentials:"
echo "admin"
kubectl get secret -n argocd argocd-initial-admin-secret -o "jsonpath={.data.password}" | base64 -d
echo
echo "http://argocd.personal.cloud"

echo "Gitea credentials:"
echo "cloudadmin"
echo "personalcloudadmin"
echo
echo "http://git.personal.cloud"

# Install infrastructure (including previously installed parts so they can be managed with Argo CD)
echo "Installing infrastructure."
# Can be done manually in the Argo CD UI at http://argocd.personal.cloud
kubectl apply -f  infrastructure/production/personal-cloud-infrastructure.yaml --wait

# Wait for each part of the infrastructure to be installed
kubectl wait --for=create application/istio -n argocd --timeout=60s
kubectl wait --for="jsonpath={.status.health.status}=Healthy" applications.argoproj.io/istio -n argocd --timeout=60s
kubectl wait --for=create application/istio-gateway -n argocd --timeout=60s
kubectl wait --for="jsonpath={.status.health.status}=Healthy" applications.argoproj.io/istio-gateway -n argocd --timeout=60s
kubectl wait --for=create application/argo-cd -n argocd --timeout=60s
kubectl wait --for="jsonpath={.status.health.status}=Healthy" applications.argoproj.io/argo-cd -n argocd --timeout=60s
kubectl wait --for="jsonpath={.status.health.status}=Healthy" applications.argoproj.io/personal-cloud-infrastructure -n argocd --timeout=60s

# Install the personal cloud suite of applications
echo "Installing applications."
# Can be done manually in the Argo CD UI
kubectl apply -f applications/production/personal-cloud.yaml --wait

# Wait for each application to be installed
kubectl wait --for="jsonpath={.status.health.status}=Healthy" applications.argoproj.io/personal-cloud -n argocd --timeout=60s
kubectl wait --for=create application/nextcloud -n argocd --timeout=60s
kubectl wait --for="jsonpath={.status.health.status}=Healthy" applications.argoproj.io/nextcloud -n argocd --timeout=120s


# Show some useful information about how to access Nextcloud
echo
echo "Nextcloud is available at http://nextcloud.personal.cloud"
echo "Credentials: admin/changeme"
