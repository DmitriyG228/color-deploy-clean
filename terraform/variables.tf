variable "linode_token" {
  description = "Linode API token"
  type        = string
  sensitive   = true
}

variable "region" {
  description = "Linode region (e.g., us-ord)"
  type        = string
  default     = "us-ord"
}

variable "instance_type" {
  description = "Linode instance type (e.g., g6-standard-6 = 6 vCPU, 16 GB RAM, 320 GB storage)"
  type        = string
  default     = "g6-standard-6"
}

variable "ssh_public_key" {
  description = "SSH public key for VM access (optional)"
  type        = string
  default     = ""
}

variable "project_slug" {
  description = "Project identifier used for VM label and tags (e.g. vexa-transcription-gateway, my-api)"
  type        = string
  default     = "app"
}

variable "vm_label" {
  description = "Override VM label when color is empty (optional)"
  type        = string
  default     = ""
}

variable "color" {
  description = "Stack color: e.g. 'blue', 'green', 'canary'. Use '' for single-VM (no color)."
  type        = string
  default     = ""

  validation {
    condition     = var.color == "" || (length(var.color) > 0 && can(regex("^[a-z0-9][a-z0-9-]*$", var.color)))
    error_message = "color must be '' or a non-empty lowercase alphanumeric string (hyphens allowed)."
  }
}
