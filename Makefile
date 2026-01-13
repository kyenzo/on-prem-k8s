.PHONY: help up provision ansible verify destroy clean status ssh-control ssh-worker1 ssh-worker2

help:
	@echo "On-Prem Kubernetes Cluster Management"
	@echo ""
	@echo "Available targets:"
	@echo "  make up          - Start VMs with Vagrant"
	@echo "  make provision   - Run all Ansible playbooks sequentially"
	@echo "  make verify      - Verify cluster health"
	@echo "  make status      - Show VM and cluster status"
	@echo "  make destroy     - Destroy all VMs"
	@echo "  make clean       - Clean generated files"
	@echo "  make ssh-control - SSH into control plane"
	@echo "  make ssh-worker1 - SSH into worker-1"
	@echo "  make ssh-worker2 - SSH into worker-2"
	@echo ""
	@echo "Full setup:"
	@echo "  ./setup-cluster.sh"

up:
	vagrant up

provision:
	cd ansible && \
	ansible-playbook playbooks/01-prepare-nodes.yml && \
	ansible-playbook playbooks/02-install-container-runtime.yml && \
	ansible-playbook playbooks/03-install-kubernetes.yml && \
	ansible-playbook playbooks/04-init-control-plane.yml && \
	ansible-playbook playbooks/05-join-workers.yml && \
	ansible-playbook playbooks/06-install-cni.yml

verify:
	cd ansible && ansible-playbook playbooks/99-verify-cluster.yml

status:
	@echo "=== VM Status ==="
	@vagrant status
	@echo ""
	@if [ -f ansible/kubeconfig ]; then \
		echo "=== Cluster Status ==="; \
		KUBECONFIG=ansible/kubeconfig kubectl get nodes; \
		echo ""; \
		KUBECONFIG=ansible/kubeconfig kubectl get pods -A | head -20; \
	else \
		echo "Cluster not yet initialized (kubeconfig not found)"; \
	fi

destroy:
	vagrant destroy -f

clean:
	rm -f ansible/kubeconfig
	rm -f ansible/kubeadm_join_command.sh
	rm -f ansible/ansible.log

ssh-control:
	vagrant ssh control-plane-1

ssh-worker1:
	vagrant ssh worker-1

ssh-worker2:
	vagrant ssh worker-2
