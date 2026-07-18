variable "location" {
  description = "Azure region to deploy into"
  type        = string
  default     = "eastus"
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rg-cloudforge"
}

variable "prefix" {
  description = "Prefix used for naming resources"
  type        = string
  default     = "cloudforge"
}

variable "vm_size" {
  description = "Azure VM size (B2ms = 2 vCPU / 8GB RAM, burstable)"
  type        = string
  default     = "Standard_B2ms"
}

variable "admin_username" {
  description = "Admin username for SSH login"
  type        = string
  default     = "azureadmin"
}

variable "ssh_public_key_path" {
  description = "Path to your local SSH public key file"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "os_disk_size_gb" {
  description = "OS disk size in GB"
  type        = number
  default     = 128
}

variable "os_disk_storage_type" {
  description = "Managed disk storage type"
  type        = string
  default     = "Premium_LRS"
}

variable "allowed_ssh_source" {
  description = "CIDR allowed to reach SSH (22). Restrict this to your home/office IP, e.g. \"203.0.113.5/32\"."
  type        = string
  default     = "203.0.113.5/32"

  validation {
    condition     = can(cidrhost(var.allowed_ssh_source, 0)) && var.allowed_ssh_source != "*" && var.allowed_ssh_source != "0.0.0.0/0"
    error_message = "allowed_ssh_source must be a specific CIDR such as 203.0.113.5/32; do not use '*' or 0.0.0.0/0."
  }
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default = {
    project     = "cloudforge-services"
    environment = "personal"
    managed_by  = "terraform"
  }
}
