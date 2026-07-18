output "public_ip_address" {
  description = "Public IP address of the VM"
  value       = azurerm_public_ip.this.ip_address
}

output "ssh_command" {
  description = "Ready-to-use SSH command"
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.this.ip_address}"
}

output "resource_group" {
  description = "Resource group name (for az cli lookups / teardown)"
  value       = azurerm_resource_group.this.name
}
