# On-Premises Kubernetes Cluster with Ansible

A production-ready, bare-metal Kubernetes cluster deployed on KVM/libvirt VMs using Vagrant and Ansible. This project demonstrates infrastructure-as-code best practices for managing on-premises Kubernetes environments.

## Project Overview

This repository contains automated infrastructure code to provision and configure a 3-node Kubernetes cluster:
- 1 Control Plane node
- 2 Worker nodes
- containerd as container runtime
- Calico CNI for pod networking

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                   Ubuntu Server (EC2)                        │
│                   IP: 16.174.10.6                           │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │              libvirt/KVM Hypervisor                     │ │
│  │         Private Network: 192.168.56.0/24               │ │
│  │                                                         │ │
│  │   ┌─────────────┐                                      │ │
│  │   │ Control     │                                      │ │
│  │   │ Plane       │  192.168.56.10                       │ │
│  │   │ (4GB/2CPU)  │                                      │ │
│  │   └─────┬───────┘                                      │ │
│  │         │                                               │ │
│  │   ┌─────┴──────────────────┐                           │ │
│  │   │                        │                           │ │
│  │ ┌─▼──────────┐      ┌──────▼────┐                      │ │
│  │ │ Worker-1   │      │ Worker-2  │                      │ │
│  │ │ (4GB/2CPU) │      │ (4GB/2CPU)│                      │ │
│  │ │ .56.20     │      │ .56.21    │                      │ │
│  │ └────────────┘      └───────────┘                      │ │
│  │                                                         │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Tech Stack

- **Host OS**: Ubuntu 22.04 LTS (EC2)
- **Virtualization**: Vagrant + libvirt/KVM
- **Guest OS**: Ubuntu 22.04 LTS
- **Orchestration**: Ansible (modular roles architecture)
- **Kubernetes**: v1.28.x (kubeadm)
- **Container Runtime**: containerd v1.7.x
- **CNI**: Calico v3.27.x

## Prerequisites

The Ubuntu server must have the following installed:
- KVM and libvirt
- Vagrant with vagrant-libvirt plugin
- Ansible
- kubectl

See the infrastructure repository for the prerequisites installation script.

## Quick Start

### 1. Clone the Repository

```bash
git clone <repository-url>
cd on-prem-k8s
```

### 2. Provision VMs

```bash
vagrant up --provider=libvirt
```

This will create 3 Ubuntu VMs with the following specs:
- Control Plane: 4GB RAM, 2 CPUs, IP 192.168.56.10
- Worker-1: 4GB RAM, 2 CPUs, IP 192.168.56.20
- Worker-2: 4GB RAM, 2 CPUs, IP 192.168.56.21

### 3. Run Ansible Playbooks

Execute the playbooks sequentially:

```bash
cd ansible

# 1. Prepare all nodes (disable swap, load kernel modules, install packages)
ansible-playbook playbooks/01-prepare-nodes.yml

# 2. Install containerd on all nodes
ansible-playbook playbooks/02-install-container-runtime.yml

# 3. Install Kubernetes components (kubeadm, kubelet, kubectl)
ansible-playbook playbooks/03-install-kubernetes.yml

# 4. Initialize control plane
ansible-playbook playbooks/04-init-control-plane.yml

# 5. Join worker nodes
ansible-playbook playbooks/05-join-workers.yml

# 6. Install Calico CNI
ansible-playbook playbooks/06-install-cni.yml

# 7. Verify cluster health
ansible-playbook playbooks/99-verify-cluster.yml
```

Or use the automated setup script:

```bash
./setup-cluster.sh
```

### 4. Access the Cluster

Configure kubectl to access your cluster:

```bash
export KUBECONFIG=$(pwd)/ansible/kubeconfig
kubectl get nodes
kubectl get pods -A
```

Expected output:
```
NAME              STATUS   ROLES           AGE   VERSION
control-plane-1   Ready    control-plane   10m   v1.28.0
worker-1          Ready    <none>          8m    v1.28.0
worker-2          Ready    <none>          8m    v1.28.0
```

## Project Structure

```
on-prem-k8s/
├── Vagrantfile                          # VM definitions (libvirt/KVM)
├── Makefile                             # Convenience commands
├── setup-cluster.sh                     # Automated setup script
├── ansible/
│   ├── ansible.cfg                      # Ansible configuration
│   ├── inventory/
│   │   ├── hosts.yml                    # Inventory file
│   │   └── group_vars/
│   │       ├── all.yml                  # Global variables
│   │       ├── control_plane.yml        # Control plane vars
│   │       └── workers.yml              # Worker vars
│   ├── roles/
│   │   ├── common/                      # OS preparation
│   │   ├── container_runtime/           # containerd setup
│   │   ├── kubernetes_bootstrap/        # K8s components
│   │   ├── control_plane/               # Control plane init
│   │   ├── worker_node/                 # Worker join
│   │   └── cni_plugin/                  # Calico CNI
│   └── playbooks/
│       ├── 01-prepare-nodes.yml
│       ├── 02-install-container-runtime.yml
│       ├── 03-install-kubernetes.yml
│       ├── 04-init-control-plane.yml
│       ├── 05-join-workers.yml
│       ├── 06-install-cni.yml
│       └── 99-verify-cluster.yml
└── docs/
    ├── architecture.md
    └── troubleshooting.md
```

## Makefile Commands

```bash
make help        # Show available commands
make up          # Start VMs with Vagrant (libvirt)
make provision   # Run all Ansible playbooks
make verify      # Verify cluster health
make status      # Show VM and cluster status
make destroy     # Destroy all VMs
make clean       # Clean generated files
make ssh-control # SSH into control plane
make ssh-worker1 # SSH into worker-1
make ssh-worker2 # SSH into worker-2
```

## Configuration

### Customize Variables

Edit `ansible/inventory/group_vars/all.yml` to customize:

```yaml
# Kubernetes version
kubernetes_version: "1.28"

# Network configuration
pod_network_cidr: "10.244.0.0/16"
service_cidr: "10.96.0.0/12"

# CNI Plugin
cni_plugin: calico
calico_version: "v3.27.0"
```

### Modify VM Resources

Edit `Vagrantfile`:

```ruby
CONTROL_PLANE_MEMORY = 4096
CONTROL_PLANE_CPUS = 2
WORKER_MEMORY = 4096
WORKER_CPUS = 2
```

## Future Enhancements

Planned features for portfolio expansion:

1. **MetalLB** - LoadBalancer implementation for bare-metal
2. **Local Storage Provisioner** - Dynamic persistent volume provisioning
3. **Ansible Molecule** - Testing framework for infrastructure code
4. **Multi-cluster networking** - Tunnel to EKS cluster
5. **Monitoring Stack** - Prometheus + Grafana
6. **GitOps** - ArgoCD integration

## Troubleshooting

See [docs/troubleshooting.md](docs/troubleshooting.md) for common issues and solutions.

## License

MIT

## Author

Evgeni S - Portfolio Project
