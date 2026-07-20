SHELL := /bin/bash

ROOT_DIR := $(CURDIR)
TERRAFORM_DIR := $(ROOT_DIR)/azure_vm
ANSIBLE_DIR := $(ROOT_DIR)/debian_ansible
INVENTORY_FILE := $(ANSIBLE_DIR)/inventory.ini

.PHONY: help terraform-init terraform-plan terraform-apply terraform-destroy ansible-inventory ansible-playbook ansible-check healthcheck tls-check ansible-vault-encrypt-vars-example

help:
	@echo "Available commands:"
	@echo ""
	@echo "terraform applies to directory: ${TERRAFORM_DIR}"
	@echo "ansible executes over directory: ${ANSIBLE_DIR}"
	@echo "" && echo ""
	@echo "  make terraform-init"
	@echo "  make terraform-plan"
	@echo "  make terraform-apply"
	@echo "  make terraform-destroy"
	@echo "  make ansible-inventory"
	@echo "  make ansible-playbook"
	@echo "  make ansible-check"
	@echo "  make ansible-vault-encrypt-vars-example"
	@echo "  make healthcheck"
	@echo "  make tls-check"

terraform-init:
	cd $(TERRAFORM_DIR) && terraform init

terraform-plan:
	cd $(TERRAFORM_DIR) && terraform plan

terraform-apply:
	cd $(TERRAFORM_DIR) && terraform apply -auto-approve

terraform-destroy:
	cd $(TERRAFORM_DIR) && terraform destroy -auto-approve

ansible-inventory:
	@mkdir -p $(ANSIBLE_DIR)
	@IP=$$(cd $(TERRAFORM_DIR) && terraform output -raw public_ip_address 2>/dev/null || true); \
	USER=$$(cd $(TERRAFORM_DIR) && terraform output -raw admin_username 2>/dev/null || true); \
	if [ -z "$$IP" ]; then \
		echo "Unable to determine public IP from terraform output"; \
		exit 1; \
	fi; \
	if [ -z "$$USER" ]; then \
		USER="azureadmin"; \
	fi; \
	printf '[servers]\n%s ansible_user=%s ansible_become=true\n' "$$IP" "$$USER" > $(INVENTORY_FILE)
	@echo "Created $(INVENTORY_FILE)"

ansible-playbook: ansible-inventory
	ansible-playbook -i $(INVENTORY_FILE) $(ANSIBLE_DIR)/provision-nginx.yml --ask-vault-pass

ansible-check: ansible-inventory
	ansible -i $(INVENTORY_FILE) all -m ping

ansible-vault-encrypt-vars-example:
	ansible-vault encrypt $(ANSIBLE_DIR)/vars/vars.yml.example

healthcheck: ansible-inventory
	@IP=$$(cd $(TERRAFORM_DIR) && terraform output -raw public_ip_address 2>/dev/null || true); \
	if [ -z "$$IP" ]; then \
		echo "Unable to determine public IP from terraform output"; \
		exit 1; \
	fi; \
	curl -fsS "http://$$IP/healthz"

tls-check:
	@echo "Checking HTTPS endpoint for cloudforge.socratic.dev..."
	@curl -I -sS https://cloudforge.socratic.dev/healthz || true
	@echo ""
	@echo "Certificate details:"
	@echo | openssl s_client -connect cloudforge.socratic.dev:443 -servername cloudforge.socratic.dev 2>/dev/null | openssl x509 -noout -dates -subject -issuer || true
