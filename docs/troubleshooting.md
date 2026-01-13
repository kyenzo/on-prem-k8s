# Troubleshooting Guide

Common issues and their solutions for the on-premises Kubernetes cluster.

## Table of Contents

- [VM Issues](#vm-issues)
- [Ansible Issues](#ansible-issues)
- [Kubernetes Issues](#kubernetes-issues)
- [Networking Issues](#networking-issues)
- [Performance Issues](#performance-issues)

## VM Issues

### VMs Won't Start

**Symptom**: `vagrant up` fails or VMs don't boot

**Solutions**:

1. Check VirtualBox installation:
   ```bash
   vboxmanage --version
   ```

2. Ensure VT-x/AMD-V is enabled in BIOS

3. Check for conflicting networks:
   ```bash
   vboxmanage list hostonlyifs
   ```

4. Remove and recreate VMs:
   ```bash
   vagrant destroy -f
   vagrant up
   ```

### SSH Connection Timeout

**Symptom**: `vagrant ssh` hangs or times out

**Solutions**:

1. Check VM is running:
   ```bash
   vboxmanage list runningvms
   ```

2. Restart networking:
   ```bash
   vagrant reload
   ```

3. Check SSH keys:
   ```bash
   ls -la .vagrant/machines/*/virtualbox/private_key
   ```

### Insufficient Memory

**Symptom**: VMs crash or fail to start with memory errors

**Solutions**:

1. Reduce VM memory in Vagrantfile:
   ```ruby
   CONTROL_PLANE_MEMORY = 2048  # Instead of 4096
   WORKER_MEMORY = 2048
   ```

2. Close other applications to free RAM

3. Start VMs one at a time:
   ```bash
   vagrant up control-plane-1
   vagrant up worker-1
   vagrant up worker-2
   ```

## Ansible Issues

### Connection Refused

**Symptom**: `ansible all -m ping` fails with connection refused

**Solutions**:

1. Ensure VMs are running:
   ```bash
   vagrant status
   ```

2. Test SSH manually:
   ```bash
   vagrant ssh control-plane-1
   ```

3. Check SSH keys in inventory:
   ```bash
   cat ansible/inventory/hosts.yml
   ```

4. Regenerate SSH keys:
   ```bash
   vagrant ssh-config
   ```

### Permission Denied (publickey)

**Symptom**: Ansible can't authenticate to VMs

**Solutions**:

1. Check private key paths in inventory match Vagrant's:
   ```bash
   ls -la .vagrant/machines/control-plane-1/virtualbox/private_key
   ```

2. Update inventory if needed:
   ```yaml
   ansible_ssh_private_key_file: ../.vagrant/machines/control-plane-1/virtualbox/private_key
   ```

### Task Timeout

**Symptom**: Ansible tasks hang or timeout

**Solutions**:

1. Increase timeout in ansible.cfg:
   ```ini
   [defaults]
   timeout = 60
   ```

2. Run with increased verbosity:
   ```bash
   ansible-playbook playbooks/01-prepare-nodes.yml -vvv
   ```

3. Check VM resources (CPU/RAM)

### Package Installation Fails

**Symptom**: apt/yum package installation fails

**Solutions**:

1. Update apt cache manually:
   ```bash
   vagrant ssh control-plane-1
   sudo apt update
   ```

2. Check internet connectivity:
   ```bash
   vagrant ssh control-plane-1
   ping -c 3 google.com
   ```

3. Retry with explicit cache update:
   ```bash
   ansible-playbook playbooks/01-prepare-nodes.yml --tags packages
   ```

## Kubernetes Issues

### kubeadm init Fails

**Symptom**: Control plane initialization fails

**Solutions**:

1. Check prerequisites:
   ```bash
   # SSH into control plane
   vagrant ssh control-plane-1

   # Verify swap is off
   free -h | grep Swap

   # Verify containerd is running
   sudo systemctl status containerd

   # Check kernel modules
   lsmod | grep br_netfilter
   lsmod | grep overlay
   ```

2. Review kubeadm pre-flight checks:
   ```bash
   sudo kubeadm init --dry-run
   ```

3. Reset and retry:
   ```bash
   sudo kubeadm reset -f
   # Then re-run playbook
   ansible-playbook playbooks/04-init-control-plane.yml
   ```

### Nodes Not Ready

**Symptom**: `kubectl get nodes` shows NotReady status

**Solutions**:

1. Check CNI installation:
   ```bash
   kubectl get pods -n kube-system | grep calico
   ```

2. View kubelet logs:
   ```bash
   vagrant ssh worker-1
   sudo journalctl -u kubelet -f
   ```

3. Reinstall CNI:
   ```bash
   ansible-playbook playbooks/06-install-cni.yml
   ```

4. Check node conditions:
   ```bash
   kubectl describe node worker-1
   ```

### Pods Stuck in Pending

**Symptom**: Pods remain in Pending state

**Solutions**:

1. Check pod events:
   ```bash
   kubectl describe pod <pod-name>
   ```

2. Verify node resources:
   ```bash
   kubectl top nodes  # Requires metrics-server
   kubectl describe nodes
   ```

3. Check for taints:
   ```bash
   kubectl get nodes -o json | jq '.items[].spec.taints'
   ```

4. Remove unwanted taints:
   ```bash
   kubectl taint nodes control-plane-1 node-role.kubernetes.io/control-plane:NoSchedule-
   ```

### Pods in CrashLoopBackOff

**Symptom**: System pods repeatedly crashing

**Solutions**:

1. Check pod logs:
   ```bash
   kubectl logs -n kube-system <pod-name>
   ```

2. Check events:
   ```bash
   kubectl get events -n kube-system --sort-by='.lastTimestamp'
   ```

3. Verify containerd:
   ```bash
   vagrant ssh control-plane-1
   sudo systemctl status containerd
   sudo crictl ps -a
   ```

### ImagePullBackOff

**Symptom**: Pods can't pull container images

**Solutions**:

1. Check internet connectivity:
   ```bash
   vagrant ssh worker-1
   ping -c 3 registry.k8s.io
   ```

2. Verify containerd config:
   ```bash
   sudo cat /etc/containerd/config.toml | grep sandbox_image
   ```

3. Pull image manually:
   ```bash
   sudo crictl pull nginx:alpine
   ```

## Networking Issues

### Cannot Access API Server

**Symptom**: `kubectl` commands fail with connection refused

**Solutions**:

1. Verify kubeconfig:
   ```bash
   export KUBECONFIG=$(pwd)/ansible/kubeconfig
   kubectl config view
   ```

2. Check API server is running:
   ```bash
   vagrant ssh control-plane-1
   sudo crictl ps | grep kube-apiserver
   ```

3. Verify API server port:
   ```bash
   curl -k https://192.168.56.10:6443
   ```

4. Check firewall (shouldn't be an issue on local VMs):
   ```bash
   sudo iptables -L -n | grep 6443
   ```

### Pod-to-Pod Communication Fails

**Symptom**: Pods can't communicate with each other

**Solutions**:

1. Check Calico pods:
   ```bash
   kubectl get pods -n kube-system -l k8s-app=calico-node
   ```

2. Verify IP forwarding:
   ```bash
   vagrant ssh worker-1
   sysctl net.ipv4.ip_forward
   ```

3. Check Calico configuration:
   ```bash
   kubectl get ippool -o yaml
   ```

4. Restart Calico:
   ```bash
   kubectl delete pod -n kube-system -l k8s-app=calico-node
   ```

### DNS Resolution Fails

**Symptom**: Pods can't resolve service names

**Solutions**:

1. Check CoreDNS pods:
   ```bash
   kubectl get pods -n kube-system -l k8s-app=kube-dns
   ```

2. Test DNS from a pod:
   ```bash
   kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup kubernetes.default
   ```

3. Check CoreDNS logs:
   ```bash
   kubectl logs -n kube-system -l k8s-app=kube-dns
   ```

4. Verify DNS service:
   ```bash
   kubectl get svc -n kube-system kube-dns
   ```

## Performance Issues

### Slow VM Performance

**Symptom**: VMs are sluggish or unresponsive

**Solutions**:

1. Check host resources:
   ```bash
   # Mac
   top
   ```

2. Reduce VM count:
   ```bash
   vagrant halt worker-2  # Temporarily stop one worker
   ```

3. Increase VM resources in Vagrantfile

4. Enable VirtualBox paravirtualization:
   ```ruby
   vb.customize ["modifyvm", :id, "--paravirtprovider", "kvm"]
   ```

### High CPU Usage

**Symptom**: CPU at 100% on host or VMs

**Solutions**:

1. Check what's consuming CPU:
   ```bash
   vagrant ssh control-plane-1
   top
   ```

2. Review kubelet resource usage:
   ```bash
   sudo systemctl status kubelet
   ```

3. Limit pod resources:
   ```yaml
   resources:
     limits:
       cpu: "500m"
       memory: "512Mi"
   ```

### Disk Space Issues

**Symptom**: Out of disk space errors

**Solutions**:

1. Check disk usage:
   ```bash
   vagrant ssh control-plane-1
   df -h
   ```

2. Clean up images:
   ```bash
   sudo crictl rmi --prune
   ```

3. Clean up containers:
   ```bash
   sudo crictl rm $(sudo crictl ps -a -q)
   ```

4. Expand VM disk in Vagrantfile

## Debug Commands

### Kubernetes Debugging

```bash
# Cluster info
kubectl cluster-info
kubectl cluster-info dump

# Node details
kubectl describe node <node-name>
kubectl get nodes -o wide

# Pod debugging
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace> --previous

# Events
kubectl get events --all-namespaces --sort-by='.lastTimestamp'

# Resource usage (requires metrics-server)
kubectl top nodes
kubectl top pods -A

# Network policies
kubectl get networkpolicies -A

# Service endpoints
kubectl get endpoints -A
```

### System Debugging

```bash
# Container runtime
sudo crictl ps
sudo crictl pods
sudo crictl images
sudo crictl logs <container-id>

# System services
sudo systemctl status kubelet
sudo systemctl status containerd
sudo journalctl -u kubelet -f
sudo journalctl -u containerd -f

# Network debugging
ip addr show
ip route show
iptables -L -n -v -t nat
```

### Ansible Debugging

```bash
# Verbose output
ansible-playbook playbooks/01-prepare-nodes.yml -v
ansible-playbook playbooks/01-prepare-nodes.yml -vvv

# Check mode (dry run)
ansible-playbook playbooks/01-prepare-nodes.yml --check

# Specific tags
ansible-playbook playbooks/01-prepare-nodes.yml --tags common

# Skip tags
ansible-playbook playbooks/01-prepare-nodes.yml --skip-tags packages

# Limit to specific hosts
ansible-playbook playbooks/01-prepare-nodes.yml --limit control-plane-1

# Step mode (interactive)
ansible-playbook playbooks/01-prepare-nodes.yml --step
```

## Complete Cluster Reset

If all else fails, completely reset:

```bash
# 1. Destroy VMs
vagrant destroy -f

# 2. Remove generated files
rm -f ansible/kubeconfig
rm -f ansible/kubeadm_join_command.sh
rm -f ansible/ansible.log

# 3. Clean VirtualBox
vboxmanage list vms | grep k8s | awk '{print $2}' | xargs -I {} vboxmanage unregistervm {} --delete

# 4. Start fresh
vagrant up
cd ansible
ansible-playbook playbooks/01-prepare-nodes.yml
# ... continue with remaining playbooks
```

## Getting Help

If issues persist:

1. Check Ansible logs: `cat ansible/ansible.log`
2. Review Vagrant logs: `vagrant up --debug`
3. Check kubelet logs: `sudo journalctl -u kubelet -n 100`
4. Review containerd logs: `sudo journalctl -u containerd -n 100`

## Common Error Messages

| Error | Cause | Solution |
|-------|-------|----------|
| `[ERROR CRI]: container runtime is not running` | containerd not started | `sudo systemctl start containerd` |
| `[ERROR Swap]: swap is not disabled` | Swap is enabled | `sudo swapoff -a` |
| `[ERROR FileContent--proc-sys-net-bridge-bridge-nf-call-iptables]` | Kernel module not loaded | `sudo modprobe br_netfilter` |
| `Unable to connect to the server: dial tcp: lookup` | DNS resolution issue | Check /etc/resolv.conf |
| `error: no configuration has been provided` | KUBECONFIG not set | `export KUBECONFIG=path/to/kubeconfig` |
