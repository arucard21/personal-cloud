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

#### Optional 
These tools are not strictly required but the instructions here do assume that they are available. They clearly document what is needed if these tools are not available.
- [`telepresence`](https://www.telepresence.io/docs/install/client)
    - If not available, you cannot connect to the Argo CD UI with https://argocd-server.argocd/ since that is the internal hostname. You'll have to [configure another way to access it](https://argo-cd.readthedocs.io/en/stable/getting_started/#3-access-the-argo-cd-api-server).
- `base64`
    - Usually already installed on Linux.
    - If not available, you will have to retrieve the base64-encoded password for Argo CD manually (see instructions below) and decode it with some other tool.
### Instructions
Create the kubernetes cluster with `k3d`, called "personal-cloud".
```shell
k3d cluster create --no-lb personal-cloud
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

## Usage

You can set up the entire suite of cloud applications with this command (where `personal-cloud.yaml` is in the root of this repo).
```shell
kubectl apply -n argocd -f personal-cloud.yaml
```

You can also do this [from the Argo CD UI](https://argo-cd.readthedocs.io/en/stable/getting_started/#creating-apps-via-ui). You can follow the steps there but make sure to use the URL to this repo as "Repository URL" in the Source section and set the path to `personal-cloud`. You can also set the "Sync Policy" in the General section to `Automatic` and enable `Prune Resources` and `Self-Heal` to ensure that everything is automatically updated to match the git repo. Other than this, select the in-cluster URL as "Cluster URL" in the Destination section and set the namespace to `default`, same as described in the documentation.

If you plan to install applications separately, instead of with the "personal-cloud" app, you may want to configure the git repository in Argo CD. This makes it possible to select it as a source when adding an app, instead of having to repeatedly copy-paste it from somewhere. You can make the git repo available with this command (where `git-repo.yaml` is in the root of this repo).
```shell
kubectl apply -n argocd -f git-repo.yaml
```
