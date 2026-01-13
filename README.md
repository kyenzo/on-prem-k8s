# On-Premises Kubernetes Cluster with Ansible

A production-ready, bare-metal Kubernetes cluster deployed on VirtualBox VMs using Vagrant and Ansible. This project demonstrates infrastructure-as-code best practices for managing on-premises Kubernetes environments.

## Project Overview

This repository contains automated infrastructure code to provision and configure a 3-node Kubernetes cluster:
- 1 Control Plane node
- 2 Worker nodes
- containerd as container runtime
- Calico CNI for pod networking

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                   Your Mac                           │
│  kubectl → kubeconfig (192.168.56.10:6443)          │
└─────────────────────────────────────────────────────┘
                         │
        ┌────────────────┴────────────────┐
        │     VirtualBox VMs              │
        │  (Private Network 192.168.56.0) │
        │                                  │
   ┌────▼─────────┐                       │
   │ Control      │                       │
   │ Plane        │  192.168.56.10        │
   │ (4GB/2CPU)   │                       │
   └────┬─────────┘                       │
        │                                  │
   ┌────┴──────────────────┐              │
   │                       │              │
┌──▼────────┐       ┌──────▼────┐        │
│ Worker-1  │       │ Worker-2  │        │
│ (4GB/2CPU)│       │ (4GB/2CPU)│        │
│           │       │           │        │
│ .56.20    │       │ .56.21    │        │
└───────────┘       └───────────┘        │
                                          │
└─────────────────────────────────────────┘
```

## Tech Stack

- **Virtualization**: Vagrant + VirtualBox
- **OS**: Ubuntu 22.04 LTS
- **Orchestration**: Ansible (modular roles architecture)
- **Kubernetes**: v1.28.x (kubeadm)
- **Container Runtime**: containerd v1.7.x
- **CNI**: Calico v3.27.x

## Prerequisites

Ensure you have the following installed on your Mac:

```bash
# VirtualBox
brew install --cask virtualbox

# Vagrant
brew install --cask vagrant

# Ansible
brew install ansible

# kubectl (for cluster management)
brew install kubectl
```

Verify installations:
```bash
vboxmanage --version
vagrant --version
ansible --version
kubectl version --client
```

## Quick Start

### 1. Clone the Repository

```bash
git clone <repository-url>
cd on-prem-k8s
```

### 2. Provision VMs

```bash
vagrant up
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

### 4. Access the Cluster

Configure kubectl to access your cluster:

```bash
export KUBECONFIG=$(pwd)/kubeconfig
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
├── Vagrantfile                          # VM definitions
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
├── docs/
│   ├── architecture.md
│   └── troubleshooting.md
└── README.md
```

## Key Features

### Modular Ansible Roles

Each role is self-contained with:
- `tasks/main.yml` - Main task definitions
- `defaults/main.yml` - Default variables
- `handlers/main.yml` - Event handlers
- `templates/` - Configuration templates

### Idempotent Operations

All Ansible tasks are idempotent - you can safely re-run playbooks without side effects.

### Production Patterns

- Swap disabled for Kubernetes compatibility
- Kernel modules properly configured (overlay, br_netfilter)
- Sysctl parameters for networking
- containerd with systemd cgroup driver
- Calico for production-grade networking

## Configuration

### Customize Variables

Edit [`ansible/inventory/group_vars/all.yml`](ansible/inventory/group_vars/all.yml) to customize:

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

Edit [`Vagrantfile`](Vagrantfile):

```ruby
CONTROL_PLANE_MEMORY = 4096
CONTROL_PLANE_CPUS = 2
WORKER_MEMORY = 4096
WORKER_CPUS = 2
```

## Testing & Verification

### Run Verification Playbook

```bash
ansible-playbook playbooks/99-verify-cluster.yml
```

This playbook:
- Checks all nodes are Ready
- Verifies all system pods are Running
- Creates a test nginx deployment
- Validates pod scheduling across workers

### Manual Verification

```bash
export KUBECONFIG=$(pwd)/ansible/kubeconfig

# Check nodes
kubectl get nodes -o wide

# Check system pods
kubectl get pods -n kube-system

# Check Calico pods
kubectl get pods -n kube-system -l k8s-app=calico-node

# Deploy test workload
kubectl create deployment nginx --image=nginx:alpine --replicas=3
kubectl get pods -o wide
```

## Troubleshooting

### VMs not starting
```bash
# Check VirtualBox status
vboxmanage list runningvms

# Restart VMs
vagrant reload
```

### Ansible connection issues
```bash
# Test connectivity
ansible all -m ping

# SSH into VMs manually
vagrant ssh control-plane-1
vagrant ssh worker-1
```

### Pods not scheduling
```bash
# Check node status
kubectl describe nodes

# Check CNI pods
kubectl get pods -n kube-system -l k8s-app=calico-node

# Check for taints
kubectl get nodes -o json | jq '.items[].spec.taints'
```

### Reset cluster
```bash
# Destroy VMs
vagrant destroy -f

# Start fresh
vagrant up
cd ansible
ansible-playbook playbooks/01-prepare-nodes.yml
# ... continue with other playbooks
```

## Future Enhancements (Phase 2)

Planned features for portfolio expansion:

1. **MetalLB** - LoadBalancer implementation for bare-metal
2. **Local Storage Provisioner** - Dynamic persistent volume provisioning
3. **Ansible Molecule** - Testing framework for infrastructure code
4. **Multi-cluster networking** - Submariner for EKS connectivity
5. **Monitoring Stack** - Prometheus + Grafana
6. **GitOps** - ArgoCD integration

## Management Commands

```bash
# Start VMs
vagrant up

# Stop VMs
vagrant halt

# SSH into nodes
vagrant ssh control-plane-1
vagrant ssh worker-1
vagrant ssh worker-2

# Check VM status
vagrant status

# Destroy all VMs
vagrant destroy -f

# Re-provision with Ansible
vagrant provision
```

## Contributing

This is a portfolio project demonstrating:
- Infrastructure as Code (IaC) best practices
- Ansible role development and modular design
- Kubernetes bare-metal deployment
- Production-ready configuration patterns

## License

MIT

## Author

Evgeni S - Portfolio Project

## Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)
- [Calico Documentation](https://docs.projectcalico.org/)
- [containerd Documentation](https://containerd.io/)

