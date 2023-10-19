terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.7.1"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "0.3.4"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}
