# Building and running kubernetes in nix

0. Re-organize repositories. Move all repositories to their own cargo project

1. Create a package for rust servers. Done in each specific repository

    - interesting [thread](https://old.reddit.com/r/rust/comments/mmbfnj/nixifying_a_rust_project/) on nix-ifying a rust project
    - Use [crate2nix](https://github.com/kolloch/crate2nix) for building rust projects
        - blog [post](https://www.srid.ca/rust-nix) using crate2nix

2. Turn my package into a container image. Also done in each specific repository

    - Use `pkgs.dockerTools.buildLayeredImage` which builds a docker container. Done by including the rust package, and then running the binary.
        - Example [flake.nix](https://github.com/wagdav/thewagner.net/blob/fcda05cf33ca24ed97a0a71a9139de72ecdc90c9/flake.nix#L52-L75) with corresponding blog [post](https://thewagner.net/blog/2021/02/25/building-container-images-with-nix/)
    - How`buildLayeredImage` works:
        - blog post from author [graham christensen](https://grahamc.com/blog/nix-and-layered-docker-images) and [pull request](https://github.com/NixOS/nixpkgs/pull/47411)
        - [nixpkgs manual](https://nixos.org/manual/nixpkgs/stable/)

3. Create a NixOS configuration to run the [kubernetes service](https://nixos.wiki/wiki/Kubernetes). Done in the base daysquare repository

    - kubernetes service [source](https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/services/cluster/kubernetes/default.nix)
    - Interesting hackernews [discussion](https://news.ycombinator.com/item?id=22858558) on nix with kubernetes
    - Good inspiration from [kubenix](https://github.com/xtruder/kubenix)
    - tweagio blog on setting up [kubernetes](https://www.tweag.io/blog/2019-03-07-configuring-and-testing-kubernetes-clusters/)

If local:

4.
    1. Kubernetes on a local container

If cloud:

4.
    1. Build a base NixOS image for cloud using [nixos-generators](https://github.com/nix-community/nixos-generators)
    2. Use terraform with terranix to provision cloud resources with out base image
    3. Use [deploy-rs](https://github.com/serokell/deploy-rs) (blog [post](https://serokell.io/blog/deploy-rs)) for deploying kubernetes configuration

# Kubernetes notes

## Control Plane

Sources: [concepts](https://kubernetes.io/docs/concepts/overview/components/)

- manages the cluster: schedules applications, maintains state, scales apps, rolls out updates

### kube-apiserver

- designed to scale horizontally (dpeloying more instances)
- can run multiple instances and balance traffice between them
- Exposes Kubernetes API

### etcd

- consistent and highly-available key value store used as backing store for cluster data
- Have a back-up plan for data

### kube-scheduler

- watches for newly created pods with no assigned node, and selects a node for them to run on

### kube-controller-manager

- Component that runs controller processes
- Each controller is a separate process but they are compiled into a single binary -> run in a single process
- some types of controllers:
    - node controller, job controller, endpoitns controller, etc.

## nodes

Sources: [concepts](https://kubernetes.io/docs/concepts/overview/components/)

- a vm or computer that runs applications (aka containers)
- A kubernetes cluster should have a minimum of three nodes

### kubelet

- Ensures that containers are running on the pod
- Takes in `PodSpecs`

### kube-proxy

- Network proxy that runs on each node in cluster implementing service concept

### containers

- kubernetes interacts with containers using the Container Runtime Interface
- Each node should have a container runtime
- cri-o and containerd are runtimes that implement the CRI spec [source](https://www.tutorialworks.com/difference-docker-containerd-runc-crio-oci/)
    - the runtimes use the Open Container Inititive (OCI) spec to run a container
        - Primary one is `runc` but `youki` looks interesting
- docker vs cri-o vs containerd [link](https://computingforgeeks.com/docker-vs-cri-o-vs-containerd/)

## kubernetes api 

- can call using `kubectl` or other cli tools. or using REST calls
- API server uses an OpenAPI sec at `/openapi/v2` endpoint
- Persistence: stores serialized state of objects by writing into etcd

Sources: [concepts](https://kubernetes.io/docs/concepts/overview/kubernetes-api/)

## objects

Sources: [concepts](https://kubernetes.io/docs/concepts/overview/working-with-objects/)

- persistent entities in kubernetes system: used to represent state of cluster
    - What containerized apps are running and on which nodes
    - Resources available to apps
    - Policies around apps behave
- an object is a *record of intent*. once created kubernetes will work to ensure that the object exists.
- work with objects using kubernetes api


### Spec and Status

- Almost every kubernetes object contains two nested object fields: `spec` and `status`
- The `spec` is set when creating the object and describes the `desired state`
- the `status` describes the current state of the object. It is supplied and updated by Kubernetes

### Describing object

- Need to provide the object's spec and some basic information about object.
- API request must include the description as JSON in request body (`kubectl` convets a yaml file to json when making request)

#### General fields

In `.yaml` file need:

- `apiVersion`: version of kubernetes API being used
- `kind`: kind of object to create
- `metadata`: data to help uniquely identify object
    - `name`: Only one object of a given kind can have a given name at a time. `/api/v1/pods/some-name`.
        - Some commonly used name constraints: DNS subdomain, RFC 1123 and RFC 1035 label names, path segment names. [Source](https://kubernetes.io/docs/concepts/overview/working-with-objects/names/#dns-subdomain-names)
    - `UID`: unique across whole cluster. generated by kubernetes and used to distinguish between historical occurrences of similar entities
    - `namespace` (optional): Provide a scope for names. Names must be unique within a namespace but not across namespaces. Namescapes can't be nested
        - Source: [link](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/)
        - Can set using the `kubctl` `--namespace` flag
        - Four default namespaces:
            - `default`:  default namespace
            - `kube-system`: namespace for objectes created by Kubernetes
            - `kube-public`: readable by all users (mostly reserved for cluster usage, in case that some resources be visible and readable publicly through whole cluster)
            - `kube-node-lease`: Holds Lease objects associated with each node
        - Not all objects are in a namespace:
            - Check for those in a namespace `kubectl api-resources --namespaced=true`
            - Check for those not: `kubectl api-resources --namespace=false`
    - `labels` (optional): key/value pairs used to specify identifying attributes meanginful to users, but don't affect core system
        - Can be attached at creation time and added/modified at any time
        - each key must be unique for the object. their [syntax](https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/#syntax-and-character-set)
        - Labels are used to organize structures of objects and have selectors for identifying
            - Equality-based and set-based requirements [link](https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/#label-selectors)
    - `annotations` (optional): key/value pairs used to specify non-identifying attributes. [syntax](https://kubernetes.io/docs/concepts/overview/working-with-objects/annotations/#syntax-and-character-set)
- `spec`: state desired for object. Format for object spec is specific to object kind

Can select resources based on the value of fields using a [field selector](https://kubernetes.io/docs/concepts/overview/working-with-objects/field-selectors/)


### Types of objects

#### Lease

[Reference](https://kubernetes.io/docs/reference/kubernetes-api/cluster-resources/lease-v1/)

### Management with kubectl

kubectl [guide](https://kubectl.docs.kubernetes.io/guides/)

Three types:

1. Imperative commands: operate on live objects in cluster
2. Imperative object configuration: kubectl specifies operations and acts on files
3. Declarative object configuration: operations are detected automatically. Act on directories

## Container Networking Interface

Discussion of AWS VPC CNI [link](https://github.com/aws/amazon-vpc-cni-k8s/issues/176)

## starting applications

- on deployment tell control plane to start application containers
- control plane schedules containers to run on the cluster's nodes
- nodes communicate with control plane using [Kubernetes API](https://kubernetes.io/docs/tutorials/kubernetes-basics/create-cluster/cluster-intro/) which control plane exposes

- node
- load balancing
- ingress
- service mesh

- Envoy for load balancing. Treasure trove from their [blog](https://blog.envoyproxy.io/archive)
- Contour for ingress? need to learn more: [site](https://projectcontour.io/)
- Services meshes ([linkerd](https://linkerd.io/)?)

sources:

- [kubernetes components](https://kubernetes.io/docs/concepts/overview/componeynts/)
- [kubernetes api](https://kubernetes.io/docs/concepts/overview/kubernetes-api/)

# Terraform Notes

## Terraform Block

`terraform {}` block contains Terraform settings. Include the providers Terraform uses to provision infrastracture

Each provider has a source attribute (default installs from Terraform Register)
Version is optional but recommended as otherwise defaults to latest version

```
terraform {
    required_providers {
        google = {
            source = "hashicorp/google"
            version = "3.5.0"
        }
    }
}
```



## Provider Block


## Terranix

A Nix way to create `terraform.json` files [link](https://github.com/terranix/terranix)


# Deploying Kubernetes

Deploy using NixOps?

- https://releases.nixos.org/nixops/nixops-1.5/manual/manual.html#idm140737316139648

From [kubernetes the hard way](https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/03-compute-resources.md)

## Design

Use [contour](https://projectcontour.io/) for ingress.
Use [linkerd](https://linkerd.io/) for service mesh
Use [cri-o](https://cri-o.io/) for container runtime
Investigate network overlays (flannel and calico)


## Provisioning (manually or with terraform):


The Virtual Private Cloud Network:

1. Create a virtual private cloud
2. Provision a subnet with an IP address range large enough to assign a private IP address to each node

Firewall:

1. Create a firewall rule that allows internal communication across all protocols
2. Create a firewall rule that allows external SSH, ICMP, and HTTPS

Public IP Address:

1. Allocate a static IP address that attaches to load balancer fronting the Kubernetes API Servers

Compute Instances (all NixOS):

1. Ptovision three compute instances for control plane
2. Provision two compute instances for workers

Terraform NixOS (https://github.com/tweag/terraform-nixos)


