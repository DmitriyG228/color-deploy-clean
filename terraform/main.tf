terraform {
  required_providers {
    linode = {
      source  = "linode/linode"
      version = "~> 3.0.0"
    }
  }
}

provider "linode" {
  token = var.linode_token
}

resource "linode_sshkey" "main" {
  count   = var.ssh_public_key != "" ? 1 : 0
  label   = "${var.project_slug}-ssh-key"
  ssh_key = var.ssh_public_key
}

data "linode_images" "ubuntu" {
  filter {
    name   = "label"
    values = ["Ubuntu 24.04 LTS"]
  }
  latest = true
}

locals {
  vm_label = var.color != "" ? "${var.project_slug}-${var.color}" : (var.vm_label != "" ? var.vm_label : "${var.project_slug}-vm")
  vm_tags   = var.color != "" ? [var.project_slug, "vm", "color-${var.color}"] : [var.project_slug, "vm"]
}

resource "linode_instance" "vm" {
  label           = local.vm_label
  region          = var.region
  type            = var.instance_type
  image           = "linode/ubuntu24.04"
  authorized_keys = var.ssh_public_key != "" ? [var.ssh_public_key] : []
  tags            = local.vm_tags

  lifecycle {
    ignore_changes = [image, migration_type, resize_disk]
  }
}
