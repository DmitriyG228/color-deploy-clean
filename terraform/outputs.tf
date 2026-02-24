output "color" {
  description = "Stack color (e.g. blue, green, canary) or empty"
  value       = var.color
}

output "vm_public_ip" {
  description = "Public IP address of the VM"
  value       = one(linode_instance.vm.ipv4)
}

output "vm_api_url" {
  description = "API URL (http://<ip>:8000)"
  value       = "http://${one(linode_instance.vm.ipv4)}:8000"
}

output "vm_ssh_command" {
  description = "SSH command to access the VM"
  value       = "ssh root@${one(linode_instance.vm.ipv4)}"
}
