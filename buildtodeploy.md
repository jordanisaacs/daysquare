Building and running kubernetes in nix:

[crate2nix](https://github.com/kolloch/crate2nix) for building rust projects with nix

- blog [post](https://www.srid.ca/rust-nix) using crate2nix
- interesting [thread](https://old.reddit.com/r/rust/comments/mmbfnj/nixifying_a_rust_project/) on nix-ifying a rust project

Once have a package of the project, use `pkgs.dockerTools.buildLayeredImage` which builds a docker container. Done by including the rust package, and then running the binary.

- Example [flake.nix](https://github.com/wagdav/thewagner.net/blob/fcda05cf33ca24ed97a0a71a9139de72ecdc90c9/flake.nix#L52-L75)
    - corresponding blog [post](https://thewagner.net/blog/2021/02/25/building-container-images-with-nix/)
- How buildLayeredImage works:
    = blog post from author [graham christensen](https://grahamc.com/blog/nix-and-layered-docker-images) and [pull request](https://github.com/NixOS/nixpkgs/pull/47411)
    - [nixpkgs manual](https://nixos.org/manual/nixpkgs/stable/)

Now with all of our packages are being run as a docker container, can use them in kubernetes. Create a container that runs the [kubernetes service](https://nixos.wiki/wiki/Kubernetes)

- kubernetes service [source](https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/services/cluster/kubernetes/default.nix)
- Interesting hackernews [discussion](https://news.ycombinator.com/item?id=22858558) on nix with kubernetes
- Good inspiration from [kubenix](https://github.com/xtruder/kubenix)
- tweagio blog on setting up [kubernetes](https://www.tweag.io/blog/2019-03-07-configuring-and-testing-kubernetes-clusters/)

Organization:
- Move all daysquare-frontend/daysquare-shared/daysquare-backend into their own cargo projects
    - daysquare-shared becomes a cargo source pointing to github
    - daysquare-frontend and daysquare-backend has a flake.nix that builds their binary and a docker image
- daysquare repo becomes the flake that setups of kubernetes in a container

Kubernetes configuration:

Topics:

- control plane
    - manages the cluster: schedules applications, maintains state, scales apps, rolls out updates
    - kube-apiserver
        - designed to scale horizontally (dpeloying more instances)
        - can run multiple instances and balance traffice between them
        - Exposes Kubernetes API
    - etcd
        - consistent and highly-available key value store used as backing store for cluster data
        - Have a back-up plan for data
    - kube-scheduler
        - watches for newly created pods with no assigned node, and selects a node for them to run on
    - kube-controller-manager
        - Component that runs controller processes
        - Each controller is a separate process but they are compiled into a single binary -> run in a single process
        - some types of controllers:
            - node controller, job controller, endpoitns controller, etc.
- nodes
    - a vm or computer
    - workers that run applications (aka docker containers)
    - A kubernetes cluster should have  aminimum of three nodes
    - kubelet
        - Ensures that containers are running on the pod
        - Takes in `PodSpecs`
    - kube-proxy
        - Network proxy that runs on each node in cluster implementing service concept
    - containers
        - kubernetes interacts with containers using the Container Runtime Interface
            - cri-o and containerd are runtimes that implement the CRI spec [source](https://www.tutorialworks.com/difference-docker-containerd-runc-crio-oci/)
                - the runtimes use the Open Container Inititive (OCI) spec to run a container
                    - Primary one is `runc` but `youki`
            - docker vs cri-o vs containerd [link](https://computingforgeeks.com/docker-vs-cri-o-vs-containerd/)
- kubernetes api 
    - can call using `kubectl` or other cli tools. or using REST calls
    - API server uses an OpenAPI sec at `/openapi/v2` endpoint
    - Persistence: stores serialized state of objects by writing into etcd
- objects
    - persistent entities in kubernetes system: used to represent state of cluster
        - What containerized apps are running and on which nodes
        - Resources available to apps
        - Policies around apps behave
    - an object is a letter of intent
    

- starting applications
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

- [kubernetes components](https://kubernetes.io/docs/concepts/overview/components/)
- [kerbenetes api](https://kubernetes.io/docs/concepts/overview/kubernetes-api/)
