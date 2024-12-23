# Personal Cloud

A personal cloud using self-hosted services in Kubernetes.

This repo is a GitOps-style declarative source for a set of cloud applications.

## Requirements
For this GitOps repo to work, you need a kubernetes cluster with Argo CD installed.

## Setting up a cluster
There are many ways to create a kubernetes cluster and install Argo CD in it. These instructions describe one specific way of doing this, one which should be suitable for users looking to set up this personal cloud on a home server. This results in a single-node cluster, which is typically not recommended for enterprise production environments but should be sufficient for home users.

### Requirements
For setting up the cluster, these are the tools that are used. They need to be installed on the machine that will contain the kubernetes cluster.
- `docker`
    - [Docker Engine](https://docs.docker.com/engine/install/) is recommended since it is open-source but [Docker Desktop](https://docs.docker.com/get-started/get-docker/) should work just as well and provides a GUI.
- [`k3d`](https://k3d.io/stable/#installation)
- [`kubectl`](https://kubernetes.io/docs/tasks/tools/#kubectl)
- [`helm`](https://helm.sh/docs/intro/install/)

#### Optional 
These tools are not strictly required but the instructions here do assume that they are available. They clearly document what is needed if these tools are not available.
- `base64`
    - Usually already installed on Linux.
    - If not available, you will have to retrieve the base64-encoded password for Argo CD manually (see instructions below) and decode it with some other tool.

### Instructions
1. Create a kubernetes cluster with `k3d`, called "personal-cloud" (or any name you want), with a single node.

        k3d cluster create --no-lb personal-cloud  
   The `kubectl` configuration will automatically be updated and its context switched to this new kubernetes cluster.
1. Install Argo CD according to the configuration provided in this repo.

        helm install argo-cd argo-cd/ --create-namespace --namespace argocd --version 7.7.11 --dependency-update --wait
	* To access the cluster, you need to configure a host name to connect to the external IP address of this cluster. You can find the external IP address with this command.

             kubectl get services -n kube-system traefik -o "jsonpath={.status.loadBalancer.ingress[].ip}"
        You can add this external IP address to your hosts file (e.g. `/etc/hosts` on Linux) to map it to a host name. It may look something like this.

            192.168.1.1  argocd.private.cloud grpc.argocd.private.cloud nextcloud.private.cloud
        The cluster is configured to use `personal.cloud` as hostname and defines a sub-domain for each application. This is why multiple hostnames are defined in the example above. This also means that it only works locally, where you can define this hostname for this external IP address.
        If you want to change this hostname, you will need to change this in every `values.yaml` file. Since this needs to be stored in the repo to be picked up by the cluster, you'll need to fork this repo and update the hostnames in that forked repo. With a forked repo, you'll also need to update the git repo URLs in YAML files. Those should be the ones in the `personal-cloud` folder and in the root of this repo.
1. The default username for the UI is "admin" and the default password is stored in base64-encoded form as a secret in the cluster and can be retrieved with the following command.

        kubectl get secret -n argocd argocd-initial-admin-secret -o "jsonpath={.data.password}" | base64 -d
1. The Argo CD UI is now available at http://argocd.private.cloud

### Automation
There is script called `setup.sh` in the repo which performs all steps described above. It is recommended to use that to automatically set up and configure the cluster.

## Usage

You can install the entire suite of cloud applications with this command from the root of this repo (where `personal-cloud.yaml` is).
```shell
kubectl apply -f personal-cloud.yaml
```

You can also do this [from the Argo CD UI](https://argo-cd.readthedocs.io/en/stable/getting_started/#creating-apps-via-ui). You can follow the steps there but make sure to use the URL to this repo as "Repository URL" in the Source section and set the path to `personal-cloud`. You can also set the "Sync Policy" in the General section to `Automatic` and enable `Prune Resources` and `Self-Heal` to ensure that everything is automatically updated to match the git repo. Other than this, select the in-cluster URL as "Cluster URL" in the Destination section and set the namespace to `default`, same as described in the documentation.

If you plan to install applications separately, instead of with the "personal-cloud" app, you may want to configure the git repository in Argo CD. This makes it possible to select it as a source when adding an app, instead of having to repeatedly copy-paste it from somewhere. You can make the git repo available with this command (where `git-repo.yaml` is in the root of this repo).
```shell
kubectl apply -f git-repo.yaml
```

## Troubleshooting
For troubleshooting, you can install and enable [Telepresence](https://www.telepresence.io/docs/install/client). This will make all services available to the host machine through their cluster-internal hostname so you can access things for which no ingress was defined. This takes the form of `<resource-name>.<namespace-name>`, e.g. you can use `http://argocd-server.argocd` to access the Argo CD UI which is installed in the `argocd` namespace and is called `argocd-server`. You can see what is available in the `argocd` namespace with `kubectl get services -n argocd`. 

You can configure the cluster with `telepresence helm install` which is only needed once. You can then connect to the cluster with `telepresence connect`.
