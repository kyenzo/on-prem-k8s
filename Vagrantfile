# -*- mode: ruby -*-
# vi: set ft=ruby :

# On-Prem Kubernetes Cluster Configuration
# 1 Control Plane + 2 Worker Nodes
# Configured for Ubuntu Server with libvirt/KVM

VAGRANT_API_VERSION = "2"

# Cluster configuration
CONTROL_PLANE_COUNT = 1
WORKER_COUNT = 2

# Network configuration
NETWORK_PREFIX = "192.168.56"
CONTROL_PLANE_IP_START = 10
WORKER_IP_START = 20

# VM Resources
CONTROL_PLANE_MEMORY = 4096
CONTROL_PLANE_CPUS = 2
WORKER_MEMORY = 4096
WORKER_CPUS = 2

# Base box - Ubuntu 22.04 for libvirt
BOX_IMAGE = "generic/ubuntu2204"

Vagrant.configure(VAGRANT_API_VERSION) do |config|
  config.vm.box = BOX_IMAGE
  config.vm.box_check_update = false

  # Control Plane Node(s)
  (1..CONTROL_PLANE_COUNT).each do |i|
    config.vm.define "control-plane-#{i}" do |node|
      node.vm.hostname = "control-plane-#{i}"
      node.vm.network "private_network", ip: "#{NETWORK_PREFIX}.#{CONTROL_PLANE_IP_START + i - 1}"

      node.vm.provider "libvirt" do |lv|
        lv.memory = CONTROL_PLANE_MEMORY
        lv.cpus = CONTROL_PLANE_CPUS
        lv.driver = "kvm"
        lv.nested = true
      end

      # Shell provisioning to set up /etc/hosts
      node.vm.provision "shell", inline: <<-SHELL
        echo "#{NETWORK_PREFIX}.#{CONTROL_PLANE_IP_START} control-plane-1" >> /etc/hosts
        echo "#{NETWORK_PREFIX}.#{WORKER_IP_START} worker-1" >> /etc/hosts
        echo "#{NETWORK_PREFIX}.#{WORKER_IP_START + 1} worker-2" >> /etc/hosts
      SHELL
    end
  end

  # Worker Nodes
  (1..WORKER_COUNT).each do |i|
    config.vm.define "worker-#{i}" do |node|
      node.vm.hostname = "worker-#{i}"
      node.vm.network "private_network", ip: "#{NETWORK_PREFIX}.#{WORKER_IP_START + i - 1}"

      node.vm.provider "libvirt" do |lv|
        lv.memory = WORKER_MEMORY
        lv.cpus = WORKER_CPUS
        lv.driver = "kvm"
        lv.nested = true
      end

      # Shell provisioning to set up /etc/hosts
      node.vm.provision "shell", inline: <<-SHELL
        echo "#{NETWORK_PREFIX}.#{CONTROL_PLANE_IP_START} control-plane-1" >> /etc/hosts
        echo "#{NETWORK_PREFIX}.#{WORKER_IP_START} worker-1" >> /etc/hosts
        echo "#{NETWORK_PREFIX}.#{WORKER_IP_START + 1} worker-2" >> /etc/hosts
      SHELL
    end
  end
end

