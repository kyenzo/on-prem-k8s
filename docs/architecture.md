# Architecture Documentation

## System Architecture

### High-Level Overview

This project implements a production-like Kubernetes cluster on local VirtualBox VMs, demonstrating bare-metal deployment patterns.

```
┌──────────────────────────────────────────────────────────────┐
│                        Host Machine (Mac)                     │
│                                                               │
│  ┌─────────────┐      ┌──────────────┐                      │
│  │   Vagrant   │──────│  VirtualBox  │                      │
│  └─────────────┘      └──────┬───────┘                      │
│                               │                               │
│  ┌─────────────┐              │                              │
│  │   Ansible   │──────────────┤                              │
│  └─────────────┘              │                              │
│                               │                               │
│  ┌─────────────┐              │                              │
│  │   kubectl   │──────────────┤                              │
│  └─────────────┘              │                              │
└───────────────────────────────┼───────────────────────────────┘
                                │
        ┌───────────────────────┼────────────────────────┐
        │    Private Network (192.168.56.0/24)          │
        │                       │                        │
        │  ┌────────────────────▼─────────────────┐     │
        │  │     control-plane-1                  │     │
        │  │     192.168.56.10                    │     │
        │  │  ┌────────────────────────────────┐  │     │
        │  │  │  kube-apiserver                │  │     │
        │  │  │  kube-controller-manager       │  │     │
        │  │  │  kube-scheduler                │  │     │
        │  │  │  etcd                          │  │     │
        │  │  └────────────────────────────────┘  │     │
        │  │  ┌────────────────────────────────┐  │     │
        │  │  │  containerd                    │  │     │
        │  │  │  kubelet                       │  │     │
        │  │  │  calico-node                   │  │     │
        │  │  └────────────────────────────────┘  │     │
        │  └──────────────────────────────────────┘     │
        │                                                │
        │  ┌────────────────────┐  ┌──────────────────┐ │
        │  │    worker-1        │  │    worker-2      │ │
        │  │  192.168.56.20     │  │  192.168.56.21   │ │
        │  │ ┌────────────────┐ │  │ ┌──────────────┐ │ │
        │  │ │  containerd    │ │  │ │  containerd  │ │ │
        │  │ │  kubelet       │ │  │ │  kubelet     │ │ │
        │  │ │  kube-proxy    │ │  │ │  kube-proxy  │ │ │
        │  │ │  calico-node   │ │  │ │  calico-node │ │ │
        │  │ └────────────────┘ │  │ └──────────────┘ │ │
        │  └────────────────────┘  └──────────────────┘ │
        │                                                │
        └────────────────────────────────────────────────┘
```

## Network Architecture

### Network Topology

- **Host-Only Network**: 192.168.56.0/24
  - Control Plane: 192.168.56.10
  - Worker-1: 192.168.56.20
  - Worker-2: 192.168.56.21

- **Pod Network (Calico)**: 10.244.0.0/16
  - Overlay network for pod-to-pod communication
  - BGP-based routing (Calico default)

- **Service Network**: 10.96.0.0/12
  - ClusterIP range for Kubernetes services
  - kube-apiserver: 10.96.0.1

### Network Flow

1. **kubectl → API Server**
   ```
   Mac (kubectl) → 192.168.56.10:6443 → kube-apiserver
   ```

2. **Pod-to-Pod Communication**
   ```
   Pod A (10.244.1.5) → Calico vRouter → Pod B (10.244.2.10)
   ```

3. **Service Access**
   ```
   Pod → ClusterIP (10.96.x.x) → kube-proxy (iptables) → Backend Pods
   ```

## Component Architecture

### Control Plane Components

| Component | Purpose | Port |
|-----------|---------|------|
| kube-apiserver | REST API for cluster management | 6443 |
| etcd | Key-value store for cluster state | 2379-2380 |
| kube-controller-manager | Manages controllers (deployment, replicaset, etc.) | 10257 |
| kube-scheduler | Assigns pods to nodes | 10259 |

### Node Components

| Component | Purpose | All Nodes |
|-----------|---------|-----------|
| kubelet | Node agent, manages pod lifecycle | Yes |
| kube-proxy | Network proxy, implements Services | Yes |
| containerd | Container runtime (CRI) | Yes |
| calico-node | CNI plugin, pod networking | Yes |

## Data Flow

### Deployment Flow

```
User: kubectl apply -f deployment.yaml
  ↓
kube-apiserver (validates, stores in etcd)
  ↓
kube-controller-manager (creates ReplicaSet)
  ↓
kube-scheduler (selects nodes for pods)
  ↓
kubelet (worker nodes) (pulls images, starts containers)
  ↓
containerd (creates containers)
  ↓
calico (assigns IP, configures networking)
```

### Request Flow (Service → Pod)

```
Client Request
  ↓
Service (ClusterIP: 10.96.x.x)
  ↓
kube-proxy (iptables rules)
  ↓
Pod IP (10.244.x.x)
  ↓
containerd (container process)
```

## Storage Architecture

### Current State (Phase 1)

- No persistent storage provisioner
- EmptyDir volumes (pod-local, ephemeral)
- HostPath volumes (node-local, not recommended)

### Future State (Phase 2)

- Local path provisioner for persistent volumes
- Dynamic volume provisioning
- StorageClass definitions

## Security Architecture

### Authentication & Authorization

- **API Server**: Certificate-based authentication
- **kubelet**: Node authorization
- **RBAC**: Role-Based Access Control (default)

### Network Security

- **Calico Network Policies**: Future implementation
- **Pod Security Standards**: Future implementation
- **Private network**: Isolated from internet by default

### Secrets Management

- **Kubernetes Secrets**: Base64 encoded (not encrypted at rest)
- **Future**: External secrets management (Vault, Sealed Secrets)

## High Availability Considerations

### Current Limitations

- Single control plane node (SPOF)
- Single etcd instance
- No load balancer for API server

### Future HA Architecture

```
                    ┌──────────────┐
                    │  HAProxy/    │
                    │  keepalived  │
                    └──────┬───────┘
                           │
         ┌─────────────────┼─────────────────┐
         │                 │                 │
    ┌────▼────┐      ┌─────▼────┐     ┌─────▼────┐
    │ Control │      │ Control  │     │ Control  │
    │ Plane 1 │      │ Plane 2  │     │ Plane 3  │
    └─────────┘      └──────────┘     └──────────┘
         │                 │                 │
    ┌────▼─────────────────▼─────────────────▼────┐
    │         etcd cluster (3 instances)           │
    └──────────────────────────────────────────────┘
```

## Ansible Architecture

### Role Design Pattern

Each role follows Ansible best practices:

```
role_name/
├── tasks/main.yml          # Main task list
├── handlers/main.yml       # Event handlers
├── defaults/main.yml       # Default variables (lowest priority)
├── vars/main.yml           # Role variables (not used yet)
├── templates/              # Jinja2 templates
└── files/                  # Static files
```

### Execution Flow

```
Playbook Execution
  ↓
1. Gather Facts (ansible setup)
  ↓
2. Load Variables (group_vars, host_vars, defaults)
  ↓
3. Execute Tasks (sequential)
  ↓
4. Trigger Handlers (at end of play)
  ↓
5. Post Tasks (if defined)
```

### Idempotency Pattern

All tasks are designed to be idempotent:

```yaml
- name: Check if resource exists
  stat:
    path: /etc/kubernetes/admin.conf
  register: resource_check

- name: Create resource
  command: kubeadm init
  when: not resource_check.stat.exists
```

## VM Architecture

### Resource Allocation

| Node Type | vCPU | RAM | Disk | IP |
|-----------|------|-----|------|-----|
| Control Plane | 2 | 4GB | 64GB | .10 |
| Worker-1 | 2 | 4GB | 64GB | .20 |
| Worker-2 | 2 | 4GB | 64GB | .21 |

### System Requirements

**Minimum Host Requirements:**
- CPU: 6+ cores (to allocate 2 per VM)
- RAM: 16GB (12GB for VMs + 4GB for host)
- Disk: 50GB free space
- Virtualization: VT-x/AMD-V enabled

## Scalability

### Current Capacity

- Max pods per node: 110 (kubelet default)
- Estimated pod capacity: ~300 pods (3 nodes)
- Suitable for: Development, testing, portfolio demos

### Scaling Options

**Horizontal Scaling:**
- Add worker nodes by modifying Vagrantfile
- Run worker join playbook for new nodes

**Vertical Scaling:**
- Increase VM resources in Vagrantfile
- Requires VM recreation (`vagrant destroy && vagrant up`)

## Monitoring Points (Future)

```
┌─────────────────────────────────────────┐
│           Prometheus                    │
│  (metrics collection & alerting)        │
└────┬─────────────────────────┬──────────┘
     │                         │
┌────▼────────┐          ┌─────▼───────┐
│ node-       │          │ kube-state- │
│ exporter    │          │ metrics     │
└─────────────┘          └─────────────┘
     │                         │
┌────▼─────────────────────────▼─────────┐
│         Kubernetes Cluster             │
└────────────────────────────────────────┘
     │
┌────▼────────┐
│  Grafana    │
│ (dashboards)│
└─────────────┘
```

## Deployment Pipeline (Future)

```
Git Push
  ↓
GitHub Actions
  ↓
ArgoCD (GitOps)
  ↓
Kubernetes Cluster
  ↓
Application Deployment
```

## Backup & Disaster Recovery

### Critical Components

1. **etcd Backup**
   ```bash
   ETCDCTL_API=3 etcdctl snapshot save backup.db
   ```

2. **Cluster Configuration**
   - Ansible playbooks (version controlled)
   - Kubernetes manifests (Git repository)

3. **Application Data**
   - Persistent Volumes (future implementation)

### Recovery Process

1. Rebuild VMs: `vagrant destroy && vagrant up`
2. Run Ansible playbooks: Sequential execution
3. Restore etcd snapshot (if needed)
4. Redeploy applications

## References

- [Kubernetes Architecture](https://kubernetes.io/docs/concepts/architecture/)
- [Calico Architecture](https://docs.projectcalico.org/reference/architecture/)
- [containerd Architecture](https://github.com/containerd/containerd/blob/main/docs/architecture.md)
- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)
