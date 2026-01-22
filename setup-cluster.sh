#!/bin/bash

# On-Prem Kubernetes Cluster Setup Script
# Automates the entire cluster deployment process
# For Ubuntu Server with Vagrant + libvirt/KVM

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}→ $1${NC}"
}

check_prerequisites() {
    print_header "Checking Prerequisites"

    local missing_deps=0

    if ! command -v vagrant &> /dev/null; then
        print_error "Vagrant is not installed"
        missing_deps=1
    else
        print_success "Vagrant found: $(vagrant --version)"
    fi

    if ! command -v virsh &> /dev/null; then
        print_error "libvirt is not installed"
        missing_deps=1
    else
        print_success "libvirt found: $(virsh --version)"
    fi

    if ! vagrant plugin list | grep -q vagrant-libvirt; then
        print_error "vagrant-libvirt plugin is not installed"
        missing_deps=1
    else
        print_success "vagrant-libvirt plugin found"
    fi

    if ! command -v ansible &> /dev/null; then
        print_error "Ansible is not installed"
        missing_deps=1
    else
        print_success "Ansible found: $(ansible --version | head -n1)"
    fi

    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed"
        missing_deps=1
    else
        print_success "kubectl found: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
    fi

    if [ $missing_deps -eq 1 ]; then
        print_error "Please install missing dependencies first"
        echo ""
        echo "Run the prerequisites installation script on your Ubuntu server"
        exit 1
    fi

    print_success "All prerequisites met!"
    echo ""
}

provision_vms() {
    print_header "Provisioning VMs with Vagrant (libvirt)"

    if vagrant status | grep -q "running"; then
        print_info "VMs are already running"
        read -p "Do you want to reprovision? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            vagrant reload --provision
        fi
    else
        print_info "Starting VMs..."
        vagrant up --provider=libvirt
        print_success "VMs provisioned successfully"
    fi
    echo ""
}

run_ansible_playbooks() {
    print_header "Running Ansible Playbooks"

    cd ansible

    local playbooks=(
        "01-prepare-nodes.yml:Preparing nodes"
        "02-install-container-runtime.yml:Installing containerd"
        "03-install-kubernetes.yml:Installing Kubernetes components"
        "04-init-control-plane.yml:Initializing control plane"
        "05-join-workers.yml:Joining worker nodes"
        "06-install-cni.yml:Installing Calico CNI"
        "99-verify-cluster.yml:Verifying cluster"
    )

    for playbook_info in "${playbooks[@]}"; do
        IFS=':' read -r playbook description <<< "$playbook_info"
        print_info "$description..."

        if ansible-playbook "playbooks/$playbook"; then
            print_success "$description completed"
        else
            print_error "$description failed"
            echo "Run with verbose mode for details:"
            echo "  ansible-playbook playbooks/$playbook -vvv"
            exit 1
        fi
    done

    cd ..
    echo ""
}

configure_kubectl() {
    print_header "Configuring kubectl Access"

    if [ -f "ansible/kubeconfig" ]; then
        export KUBECONFIG="$(pwd)/ansible/kubeconfig"
        print_success "Kubeconfig found at: $(pwd)/ansible/kubeconfig"

        echo ""
        print_info "Testing cluster access..."
        if kubectl get nodes > /dev/null 2>&1; then
            print_success "Successfully connected to cluster"
            echo ""
            kubectl get nodes
        else
            print_error "Failed to connect to cluster"
            exit 1
        fi
    else
        print_error "Kubeconfig file not found"
        exit 1
    fi

    echo ""
}

show_completion_message() {
    print_header "Cluster Setup Complete!"

    echo ""
    echo "Your Kubernetes cluster is ready!"
    echo ""
    echo "To access the cluster, run:"
    echo -e "  ${GREEN}export KUBECONFIG=$(pwd)/ansible/kubeconfig${NC}"
    echo ""
    echo "Useful commands:"
    echo "  kubectl get nodes"
    echo "  kubectl get pods -A"
    echo "  kubectl cluster-info"
    echo ""
    echo "To SSH into nodes:"
    echo "  vagrant ssh control-plane-1"
    echo "  vagrant ssh worker-1"
    echo "  vagrant ssh worker-2"
    echo ""
    echo "To destroy the cluster:"
    echo "  vagrant destroy -f"
    echo ""
}

# Main execution
main() {
    echo ""
    print_header "On-Prem Kubernetes Cluster Setup"
    print_info "Ubuntu Server + Vagrant + libvirt/KVM"
    echo ""

    check_prerequisites
    provision_vms
    run_ansible_playbooks
    configure_kubectl
    show_completion_message
}

# Run main function
main
