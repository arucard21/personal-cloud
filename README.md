# Personal Cloud

A personal cloud using self-hosted services in Kubernetes.

This repo is a GitOps-style declarative source for a set of cloud applications.

## Requirements
For this GitOps repo to work, you need a kubernetes cluster with Argo CD installed.

## Setting up a cluster
There are many ways to create a kubernetes cluster and install Argo CD in it. This describes one specific way of doing this, which should be suitable for users looking to set up this personal cloud on a home server. This results in a single-node cluster, which is typically not recommended for enterprise production environments but should be sufficient for home users.

### Requirements for setting up a cluster
For setting up the cluster, these are the tools that are used. They need to be installed on the machine that will contain the kubernetes cluster.
- `docker`
    - [Docker Engine](https://docs.docker.com/engine/install/) is recommended since it is open-source but [Docker Desktop](https://docs.docker.com/get-started/get-docker/) should work just as well and provides a GUI.
- [`k3d`](https://k3d.io/stable/#installation)
- [`kubectl`](https://kubernetes.io/docs/tasks/tools/#kubectl)
- [`telepresence`](https://www.telepresence.io/docs/install/client)
- `base64`
    - Usually already installed on Linux.
### Instructions
Create the kubernetes cluster with `k3d`, called "personal-cloud".
```shell
k3d cluster create personal-cloud
```
The `kubectl` configuration will automatically be updated and its context switched to this new kubernetes cluster.

Install `telepresence` in the cluster.
```shell
telepresence helm install
```
Install Argo CD
```shell
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Allow access to Argo CD UI by providing access to all internal services with `telepresence`
```shell
telepresence connect
```

The default username for the UI is "admin" and the default password is stored in base64-encoded form as a secret in the cluster and can be retrieved with the following command.
```shell
kubectl get secret -n argocd argocd-initial-admin-secret -o "jsonpath={.data.password}" | base64 -d
```

The Argo CD UI is now available at https://argocd-server.argocd

### Automation
There is script called `setup.sh` in the repo which performs all steps described above. It can be used to automatically setup the cluster.
