# On-Prem Kubernetes Cluster Configuration
# 1 Control Plane + 2 Worker Nodes

VAGRANT_API_VERSION = "2"

# Cluster configuration
CONTROL_PLANE_COUNT = 1
WORKER_COUNT = 2
NETWORK_PREFIX = "192.168.56"
CONTROL_PLANE_IP_START = 10
WORKER_IP_START = 20

# VM Resources
CONTROL_PLANE_MEMORY = 4096
CONTROL_PLANE_CPUS = 2
WORKER_MEMORY = 4096
WORKER_CPUS = 2

# Base box
BOX_IMAGE = "ubuntu/jammy64"  # Ubuntu 22.04 LTS

Vagrant.configure(VAGRANT_API_VERSION) do |config|
  config.vm.box = BOX_IMAGE
  config.vm.box_check_update = false

  # Control Plane Node(s)
  (1..CONTROL_PLANE_COUNT).each do |i|
    config.vm.define "control-plane-#{i}" do |node|
      node.vm.hostname = "control-plane-#{i}"
      node.vm.network "private_network", ip: "#{NETWORK_PREFIX}.#{CONTROL_PLANE_IP_START + i - 1}"

      node.vm.provider "virtualbox" do |vb|
        vb.name = "k8s-control-plane-#{i}"
        vb.memory = CONTROL_PLANE_MEMORY
        vb.cpus = CONTROL_PLANE_CPUS

        # Optimize VirtualBox settings
        vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
        vb.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
        vb.customize ["modifyvm", :id, "--ioapic", "on"]
      end

      # Provision with Ansible only after all VMs are up
      if i == CONTROL_PLANE_COUNT
        node.vm.provision "ansible" do |ansible|
          ansible.limit = "all"
          ansible.playbook = "ansible/playbooks/00-verify-connectivity.yml"
          ansible.inventory_path = "ansible/inventory/hosts.yml"
          ansible.compatibility_mode = "2.0"
        end
      end
    end
  end

  # Worker Nodes
  (1..WORKER_COUNT).each do |i|
    config.vm.define "worker-#{i}" do |node|
      node.vm.hostname = "worker-#{i}"
      node.vm.network "private_network", ip: "#{NETWORK_PREFIX}.#{WORKER_IP_START + i - 1}"

      node.vm.provider "virtualbox" do |vb|
        vb.name = "k8s-worker-#{i}"
        vb.memory = WORKER_MEMORY
        vb.cpus = WORKER_CPUS

        # Optimize VirtualBox settings
        vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
        vb.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
        vb.customize ["modifyvm", :id, "--ioapic", "on"]
      end
    end
  end

  # Common provisioning for all nodes
  config.vm.provision "shell", inline: <<-SHELL
    # Update /etc/hosts for cluster nodes
    echo "#{NETWORK_PREFIX}.#{CONTROL_PLANE_IP_START} control-plane-1" >> /etc/hosts
    echo "#{NETWORK_PREFIX}.#{WORKER_IP_START} worker-1" >> /etc/hosts
    echo "#{NETWORK_PREFIX}.#{WORKER_IP_START + 1} worker-2" >> /etc/hosts
  SHELL
end
