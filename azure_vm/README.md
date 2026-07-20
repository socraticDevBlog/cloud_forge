![Terraform](https://img.shields.io/badge/terraform-%235835CC.svg?style=for-the-badge&logo=terraform&logoColor=white)
![Ansible](https://img.shields.io/badge/ansible-%231A1918.svg?style=for-the-badge&logo=ansible&logoColor=white)
![Nginx](https://img.shields.io/badge/nginx-%23009639.svg?style=for-the-badge&logo=nginx&logoColor=white)

# Azure Debian VM with Terraform

This project provisions a hardened Debian VM on Azure with Docker, Docker Compose, UFW, and Fail2ban.

## Prerequisites

- make (optionnal but recommended)
- terraform
- ansible

Before using Terraform, make sure you have:

- An Azure subscription and access to create resources
- A separate Azure Storage Account with a container for Terraform state
- The Blob Storage Contributor role assigned to your account for that storage account/container
- Terraform installed locally
- An RSA SSH public key available on your machine (for example, ~/.ssh/id_rsa.pub)
- Your home public IP address, so SSH access can be restricted to your own network

## Azure backend setup

Terraform uses an Azure Storage Account backend to store state.

1. Create a new Storage Account in Azure.
2. Create a container inside it, for example: tfstate.
3. Grant your user the Blob Storage Contributor role on that storage account/container.
4. Copy backend.tf.example to backend.tf and update the backend values.

## Local configuration

1. Copy terraform.tfvars.example to terraform.tfvars.
2. Update the values in terraform.tfvars:
   - resource_group_name
   - prefix
   - admin_username
   - ssh_public_key_path (must point to your RSA public key)
   - allowed_ssh_source (set this to your home public IP, for example 203.0.113.5/32)

## Deploy virtual machine

Run the following commands from this folder:

```bash
make terraform-init
make terraform-plan
make terraform-apply
```

## Configure virtual machine

```
make ansible-playbook
```

## Test configurations

```
make healthcheck

# expect
<!-- Created <absolute path>/cloud_forge/debian_ansible/inventory.ini
{"healthy":true}%  -->
```

## Notes

- Do not leave SSH open to the Internet without restriction.
- Use a specific CIDR for allowed_ssh_source instead of 0.0.0.0/0 or \*.
- The VM is configured to use SSH key authentication only.

## recommended

- use [tfswitch](https://tfswitch.warrensbox.com/Installation/) to manage your
  Terraform CLI
