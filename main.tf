resource "libvirt_network" "net" {
  name      = var.cluster_name
  mode      = "nat"
  autostart = true
  domain    = var.domain
  addresses = [var.subnet]

  dhcp {
    enabled = false
  }

  dns {
    enabled    = true
    local_only = true
  }
}

resource "libvirt_pool" "pool" {
  name = var.cluster_name
  type = "dir"
  path = "/var/lib/libvirt/${var.cluster_name}/images"
}

resource "libvirt_volume" "cp_volume" {
  for_each = var.nodes.controlplane
  name     = "${each.key}.${var.cluster_name}.rootfs.${var.domain}"
  size     = 16106127360
  pool     = var.cluster_name

  depends_on = [libvirt_pool.pool]
}

resource "libvirt_volume" "worker_volume" {
  for_each = var.nodes.workers
  name     = "${each.key}.${var.cluster_name}.rootfs.${var.domain}"
  size     = 16106127360
  pool     = var.cluster_name

  depends_on = [libvirt_pool.pool]
}

resource "libvirt_volume" "storage_volume" {
  for_each = var.nodes.workers
  name     = "${each.key}.${var.cluster_name}.storage.${var.domain}"
  size     = 26843545600
  pool     = var.cluster_name

  depends_on = [libvirt_pool.pool]
}

resource "libvirt_domain" "worker_node" {
  for_each  = var.nodes.workers
  name      = "${each.key}.${var.cluster_name}.${var.domain}"
  autostart = true
  vcpu      = each.value.cpus
  memory    = each.value.memory

  lifecycle {
    ignore_changes = [
      nvram,
    ]
  }

  console {
    type        = "pty"
    target_port = "0"
  }

  cpu {
    mode = "host-passthrough"
  }

  disk {
    file = abspath("${path.module}/_out/talos.iso")
  }

  disk {
    volume_id = libvirt_volume.worker_volume[each.key].id
  }

  disk {
    volume_id = libvirt_volume.storage_volume[each.key].id
  }

  boot_device {
    dev = ["cdrom"]
  }

  network_interface {
    network_name   = var.cluster_name
    addresses      = [each.value.ip]
    wait_for_lease = true
  }

  depends_on = [
    libvirt_volume.worker_volume,
    #libvirt_volume.storage_volume,
    libvirt_network.net
  ]
}

resource "libvirt_domain" "cp_node" {
  for_each  = var.nodes.controlplane
  name      = "${each.key}.${var.cluster_name}.${var.domain}"
  autostart = true
  vcpu      = each.value.cpus
  memory    = each.value.memory

  lifecycle {
    ignore_changes = [
      nvram,
    ]
  }

  console {
    type        = "pty"
    target_port = "0"
  }

  cpu {
    mode = "host-passthrough"
  }

  disk {
    file = abspath("${path.module}/_out/talos.iso")
  }

  disk {
    volume_id = libvirt_volume.cp_volume[each.key].id
  }

  boot_device {
    dev = ["cdrom"]
  }

  network_interface {
    network_name   = var.cluster_name
    addresses      = [each.value.ip]
    wait_for_lease = true
  }

  depends_on = [
    libvirt_volume.cp_volume,
    libvirt_network.net
  ]
}
resource "talos_machine_secrets" "this" {}

data "talos_machine_configuration" "controlplane" {
  cluster_name     = var.cluster_name
  cluster_endpoint = "https://${var.nodes.controlplane.cp01.ip}:6443"
  machine_type     = "controlplane"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
}

data "talos_machine_configuration" "worker" {
  cluster_name     = var.cluster_name
  cluster_endpoint = "https://${var.nodes.controlplane.cp01.ip}:6443"
  machine_type     = "worker"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
}

data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = [for node in libvirt_domain.cp_node : node.network_interface[0].addresses[0]]

  nodes = concat(
    [for node in libvirt_domain.cp_node : node.network_interface[0].addresses[0]],
    [for node in libvirt_domain.worker_node : node.network_interface[0].addresses[0]]
  )
}

resource "talos_machine_configuration_apply" "controlplane" {
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  for_each                    = libvirt_domain.cp_node
  node                        = each.value.network_interface[0].addresses[0]

  config_patches = [
    yamlencode({
      machine = {
        install = {
          disk = "/dev/vda"
        }
        network = {
          hostname = "${each.value.name}"
        }
      }
      cluster = {
        apiServer = {
          admissionControl = [
            {
              name = "PodSecurity",
              configuration = {
                exemptions = {
                  namespaces = [
                    "ingress-nginx",
                    "cert-manager"
                  ]
                }
              }
            }
          ]
        }
      }
    }),
  ]
}

resource "talos_machine_configuration_apply" "worker" {
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker.machine_configuration
  for_each                    = libvirt_domain.worker_node
  node                        = each.value.network_interface[0].addresses[0]

  config_patches = [
    yamlencode({
      machine = {
        install = {
          disk = "/dev/vda"
        }
        network = {
          hostname = "${each.value.name}"
        }
        nodeLabels = {
          "openebs.io/engine" = "mayastor"
        }
        sysctls = {
          "vm.nr_hugepages" = "1024"
        }
      }
    }),
  ]
}

resource "talos_machine_bootstrap" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = [for node in libvirt_domain.cp_node : node.network_interface[0].addresses[0]][0]

  depends_on = [talos_machine_configuration_apply.controlplane]
}

data "talos_cluster_kubeconfig" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = [for node in libvirt_domain.cp_node : node.network_interface[0].addresses[0]][0]
  wait                 = true
}
