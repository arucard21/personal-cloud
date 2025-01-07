# Personal Cloud

A suite of personal cloud applications that are self-hosted in a Kubernetes cluster.

This repo provides a GitOps approach for self-hosting these applications by being the declarative source of truth for the Kubernetes cluster. Any changes made to the repo will automatically be synchronzed to the cluster.

## Installed cloud applications
- [Nextcloud](https://nextcloud.com/)

## Repo structure
```
├── applications
│   └── production
│       └── personal-cloud.yaml
├── charts
│   ├── <contains Helm charts that are created or customized for this cluster>
├── infrastructure
│   └── production
│       └── personal-cloud-infrastructure.yaml
```
This GitOps repo is structured with three main folders at the root, `applications`, `charts`, and `infrastructure`. This is based on best practices for the GitOps repo structure. This includes separating the normal applications from the infrastructure, and the best practice is evey to keep them in separate repos. Though that is excessive for a home setup. The Helm charts are also kept in one place to make them easier to maintain. Both the `application` and `infrastructure` folder represent the state their own part of the cluster.

The `charts` folder contains all Helm charts that could not be used directly from a Helm repo. This is usually because it was created for this cluster or needed to be customized beyond what can be done through its values. The `argo-cd` chart is an exception since it is included with only its values modified. This is because it needs to be installed both manually and again with Argo CD and needs those values to remain consistent.

The `infrastructure` and `applications` folders each contain a separate folder for each environment. The cluster only has a `production` environment here but you could add a another folder for staging or testing here. If you have multiple Kubernetes clusters, you can also add a hierarchical layer here for the cluster, e.g. `applications/cluster1/production`. 

The `production` folder, and any other folder for an environment, contains an Argo CD Application resource defined according to the [app-of-apps pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/#app-of-apps-pattern), `personal-cloud.yaml` and `personal-cloud-infrastructure.yaml`. This is a single application that groups together multiple other applications. From the `infrastructure` folder, this defines all applications needed as infrastructure. These will ensure that normal applications can be used correctly. Inside the `applications` folder then, the `production` folder defines an app-of-apps for all normal applications that should be installed for the personal cloud.

## Requirements
- a Kubernetes cluster
- A hostname for the cluster
    - This repo uses a base hostname `personal.cloud` by default and uses sub-domains for each of the applications, e.g. http://argocd.personal.cloud and http://nextcloud.personal.cloud . These hostnames will need to be configured to point to the external IP address of the cluster.

If you don't have a Kubernetes cluster yet, you can follow the instructions below. There are many ways to create a kubernetes cluster. These instructions describe only one specific way of doing this. It results in a single-node cluster, which is typically not recommended for enterprise production environments but should be sufficient for home users.

### Tools used
- [`docker`](https://docs.docker.com/engine/install/)
- [`k3d`](https://k3d.io/stable/#installation)
- [`kubectl`](https://kubernetes.io/docs/tasks/tools/#kubectl)
- [`helm`](https://helm.sh/docs/intro/install/)
- `base64` 

### Creating a Kubernetes cluster

You first need to install `docker`. I would recommend using [Docker Engine](https://docs.docker.com/engine/install/) since it is open-source. [Docker Desktop](https://docs.docker.com/get-started/get-docker/) should also work and it provides a GUI which may make it easier to use. It's not open-source but should be free to use for most home users.

For creating the Kubernetes cluster, you need to install [`k3d`](https://k3d.io/stable/#installation). You can create the cluster with the following command.
```shell
k3d cluster create --no-lb --k3s-arg="--disable=traefik@server:0" personal-cloud
```
The `--no-lb` parameter disables the external loadbalancer which distributes traffic across multiple nodes. It is not needed here since we only have a single node.
The next parameter, `--k3s-arg="--disable=traefik@server:0"`, disables the default ingress controller ([Traefik]([url](https://k3d.io/stable/usage/k3s/?h=traefik#traefik-in-k3d))). It will be replaced with a service mesh (Istio) which should provide more features and will be managed by Argo CD.

## Usage
### Fork this repo
In general, a GitOps repo represents the state of your cluster. So you should fork this repo and use the fork to represent the state of your cluster. That way, you can make changes specific to your cluster in the fork, like changing the hostnames used in the cluster.

After forking this repo, you will need to update `infrastructure/production/personal-cloud-infrastructure.yaml` and `applications/production/personal-cloud.yaml`. You need to change the repoURL to the URL of your forked repo. You may also have to update the repo URL elsewhere within those 2 YAML files. Make sure that all URLs to this repo are replaced with URLS to the forked repo.

You can also change the hostnames in these 2 YAML files. They are configured in different places but just have to replace the `*.personal.cloud` hostnames with your own. For example, if you want to change the hostname to `example.com`, you would change `argocd.personal.cloud` to `argocd.example.com`. Of course, you still need to ensure that this hostname points to your cluster's IP address. There are instructions for this further below.

### Install Argo CD
This GitOps repo uses Argo CD to synchronize the repo to the cluster. The repo contains a Helm chart for Argo CD which is configured for this repo. So you must first install [`Helm`](https://helm.sh/docs/intro/install/). Then you can install Argo CD with the following command.
```shell
helm install argo-cd chart/argo-cd/ --create-namespace --namespace argocd --set "global.domain=argocd.personal.cloud" --set "argo-cd.server.ingress.enabled=false" --dependency-update --wait
```
If you want to use a different hostname for your cluster, make sure to change it for `global.domain`. The ingress is also disabled for Argo CD because there is no ingress controller installed yet. It will be enabled again after the ingress controller is available.

### Install infrastructure
Now that Argo CD is installed in the cluster, you can use it to install the infrastructure needed to run the personal cloud applications. You need to install [`kubectl`](https://kubernetes.io/docs/tasks/tools/#kubectl) for this. Then you can install the infrastructure with the following command.
```shell
kubectl apply -f  infrastructure/production/personal-cloud-infrastructure.yaml
```
Make sure that the git repo URL and hostname in this YAML file match your needs. You can now point the hostname for Argo CD, `argocd.personal.cloud` by default, to the cluster's external IP address. See further below for instructions on how this can be done. Once configured, you can access the Argo CD UI with that hostname, http://argocd.personal.cloud by default. Note that accessing it with the IP address will not work since routing in the cluster is based on the hostname.

The default username for the UI is `admin` and the default password is stored in base64-encoded form as a secret in the cluster and can be retrieved with the following command.
```shell
kubectl get secret -n argocd argocd-initial-admin-secret -o "jsonpath={.data.password}" | base64 -d
```

### Install applications
You can install the applications with the following command.
```shell
kubectl apply -f applications/production/personal-cloud.yaml
```
Again, make sure that the git repo URL and hostanme in this YAML file match your needs. As before, you can now point the hostname for Nextcloud, `nextcloud.personal.cloud` by default, to the cluster's external address to access it, which would be http://nextcloud.personal.cloud by default.

## Configure hostnames
You can find the cluster's external IP address with the following command.
```shell
kubectl get services -n istio-system istio-gateway -o "jsonpath={.status.loadBalancer.ingress[].ip}"
```
There are different ways to configure the hostname with this IP address, based on how you want to access it.

The instructions below provide some guidance on how to do this but there is a lot of variability in networking. So detailed instructions are not possible. The rough instructions are to first make sure your cluster's IP address is reachable from wherever you want to access it from. Then you need to configure DNS resolution to recognize your hostname and map it to the IP address that leads to your cluster (which is not always the same as the IP address you can find with the command above).

### Local machine access
If you want to access it only from the machine where the cluster is running, you can add this external IP address to your hosts file (e.g. `/etc/hosts` on Linux) to map it to a hostname. It may look something like this.
```shell
192.168.1.1  argocd.private.cloud nextcloud.private.cloud
```
Make sure to use the actual IP address of the cluster and the hostnames that you configured in the repo.

### Local network access
If you want to access it only from your local network, you will first need to ensure that the external IP address of the cluster is reachable from the local network. 
You could [configure k3d networking](https://k3d.io/v5.0.0/design/networking/?h=network#host-network) to use `host` mode for its Docker network. This makes the cluster reachable from the host network but it requires that the ports used by the cluster are available on the host. You'll need to add `--network host` to the k3d command used to create the cluster.

You can also enable the external loadbalancer for k3d and configure it to forward a specific port on the host to the cluster, as [documented for exposing services](https://k3d.io/v5.0.0/usage/exposing_services/). 

Either of these options make the cluster's external IP address reachable from the network. But to configure the hostname for that IP address, you will need to run and use a local DNS server. There are different ways to do this, so more detailed instructions can't be given.

### Internet access
If you want to access it from the internet, you will also need to ensure that the external IP address of the cluster is reachable from the internet. This means you will need to make it reachable from your local network, e.g. by setting the network to `host` mode, as described in the previous section. Then you will need to make it reachable from outside your local network, i.e. the internet. Typically, you can just configure port forwarding in your router. Though if you use IPv6, your local machine can usually be directly addressed from the internet. 

Then you need to configure DNS for your hostname. You can easily configure the different subdomains for each application in the cluster by using a [wildcard DNS record](https://en.wikipedia.org/wiki/Wildcard_DNS_record) for your base hostname. Using the default hostname as example, the wildcard DNS record would be for `*.private.cloud`. This ensures that any subdomains will go to the same IP address and you don't have to create a new DNS record for every application.

### Automation
There is script called `setup.sh` in the repo which performs all steps from creating the kubernetes cluster with k3d to installing the personal cloud applications.

## Troubleshooting
For troubleshooting, you can install and enable [Telepresence](https://www.telepresence.io/docs/install/client). This will make all services available to the host machine through their cluster-internal hostname so you can access things for which no ingress was defined. This takes the form of `<resource-name>.<namespace-name>`, e.g. you can use `http://argocd-server.argocd` to access the Argo CD UI which is installed in the `argocd` namespace and is called `argocd-server`. You can see what is available in the `argocd` namespace with `kubectl get services -n argocd` or `telepresence list -n argocd`. 

You can configure the cluster with `telepresence helm install` which is only needed once. You can then connect to the cluster with `telepresence connect`.
