# Libvirt Talos Playground

This repository contains a simple Terraform configuration to run a local Talos
OS Kubernetes cluster in libvrirt/kvm VMs.

## Usage

### Cluster Setup

The default configuration will setup a cluster consisting of **one
controlplane** node and **3 worker** nodes. The in cluster domain will be set to
**example.com**.
You can change this by editing the [variables.tf](./variables.tf) acourding to
your needs.

```bash
git clone https://github.com/oliverwiegers/libvrirt-talos-playground
cd libvrirt-talos-playground
./bin/download-talos-iso

terraform init
terraform apply -auto-approve
```

### Client Setup

```bash
terraform output -raw talosconfig > ./talosconfig
terraform output -raw kubeconfig > ./talosconfig

talosctl config merge ./talosconfig
rm ./taloscofig

# Copy kubeconfig where you store those. For example:
cp kubeconfig ~/.kube/configs
rm ./kubeconfig
```

## Requirements

### Cluster

- Terraform
- libvirt

### Client

- kubectl
- [talosctl](https://www.talos.dev/v1.5/introduction/getting-started/)
