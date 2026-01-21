# -*- mode: ruby -*-
# vi: set ft=ruby :

# On-Prem Kubernetes Cluster Configuration
# 1 Control Plane + 2 Worker Nodes
# Configured for Apple Silicon (M1/M2/M3) using QEMU

VAGRANT_API_VERSION = "2"

# Cluster configuration
CONTROL_PLANE_COUNT = 1
WORKER_COUNT = 2

# VM Resources
CONTROL_PLANE_MEMORY = "4G"
CONTROL_PLANE_CPUS = 2
WORKER_MEMORY = "4G"
WORKER_CPUS = 2

# Base box - ARM64 Ubuntu for Apple Silicon
BOX_IMAGE = "perk/ubuntu-22.04-arm64"

# SSH port base (each VM gets a unique port)
SSH_PORT_BASE = 50022

Vagrant.configure(VAGRANT_API_VERSION) do |config|
  config.vm.box = BOX_IMAGE
  config.vm.box_check_update = false

  # Disable default synced folder (not well supported with QEMU)
  config.vm.synced_folder ".", "/vagrant", disabled: true

  # Control Plane Node(s)
  (1..CONTROL_PLANE_COUNT).each do |i|
    config.vm.define "control-plane-#{i}" do |node|
      node.vm.hostname = "control-plane-#{i}"

      node.vm.provider "qemu" do |qe|
        qe.memory = CONTROL_PLANE_MEMORY
        qe.smp = CONTROL_PLANE_CPUS
        qe.ssh_port = SSH_PORT_BASE + i - 1
        # Use Apple Hypervisor Framework for native ARM64 performance
        qe.machine = "virt,accel=hvf,highmem=off"
        qe.cpu = "host"
        qe.net_device = "virtio-net-device"
      end

      # Shell provisioning to set up /etc/hosts
      node.vm.provision "shell", inline: <<-SHELL
        # Get the VM's IP for reference
        echo "127.0.0.1 control-plane-#{i}" >> /etc/hosts
        echo "# Cluster nodes will be added after all VMs are up" >> /etc/hosts
      SHELL
    end
  end

  # Worker Nodes
  (1..WORKER_COUNT).each do |i|
    config.vm.define "worker-#{i}" do |node|
      node.vm.hostname = "worker-#{i}"

      node.vm.provider "qemu" do |qe|
        qe.memory = WORKER_MEMORY
        qe.smp = WORKER_CPUS
        qe.ssh_port = SSH_PORT_BASE + CONTROL_PLANE_COUNT + i - 1
        # Use Apple Hypervisor Framework for native ARM64 performance
        qe.machine = "virt,accel=hvf,highmem=off"
        qe.cpu = "host"
        qe.net_device = "virtio-net-device"
      end

      # Shell provisioning to set up /etc/hosts
      node.vm.provision "shell", inline: <<-SHELL
        echo "127.0.0.1 worker-#{i}" >> /etc/hosts
      SHELL
    end
  end
end
