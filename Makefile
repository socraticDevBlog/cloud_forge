SHELL := /bin/bash

ROOT_DIR := $(CURDIR)
TERRAFORM_DIR := $(ROOT_DIR)/azure_vm
ANSIBLE_DIR := $(ROOT_DIR)/debian_ansible
INVENTORY_FILE := $(ANSIBLE_DIR)/inventory.ini

.PHONY: help terraform-init terraform-plan terraform-apply ansible-inventory ansible-core-playbook ansible-deploy-joplin

help:
	@echo "Available commands:"
	@echo ""
	@echo "terraform applies to directory: ${TERRAFORM_DIR}"
	@echo "ansible executes over directory: ${ANSIBLE_DIR}"
	@echo "" && echo ""
	@echo "  make terraform-init"
	@echo "  make terraform-plan"
	@echo "  make terraform-apply"
	@echo "  make ansible-inventory"
	@echo "  make ansible-core-playbook"
	@echo "  make ansible-deploy-joplin"

terraform-init:
	cd $(TERRAFORM_DIR) && terraform init

terraform-plan:
	cd $(TERRAFORM_DIR) && terraform plan

terraform-apply:
	cd $(TERRAFORM_DIR) && terraform apply -auto-approve

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

ansible-core-playbook: ansible-inventory
	ansible-playbook -i $(INVENTORY_FILE) $(ANSIBLE_DIR)/provision-nginx.yml --ask-vault-pass

ansible-deploy-joplin: ansible-inventory
	ansible-playbook -i $(INVENTORY_FILE) $(ANSIBLE_DIR)/deploy-joplin.yml --ask-vault-pass
