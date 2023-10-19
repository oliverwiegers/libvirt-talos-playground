variable "cluster_name" {
  description = "A string containing the cluster name."
  type        = string
  default     = "homelab"
}

variable "subnet" {
  description = "A string containing the cluster subnet."
  type        = string
  default     = "10.5.0.0/24"
}

variable "domain" {
  description = "A string containing the DNS domain name for the cluster."
  type        = string
  default     = "example.com"
}

variable "nodes" {
  description = "A map of nodes."
  type = object({
    controlplane = map(object({
      cpus   = number
      memory = number
      ip     = string
    }))
    workers = map(object({
      cpus   = number
      memory = number
      ip     = string
    }))
  })
  default = {
    controlplane = {
      "cp01" = {
        cpus   = 2
        memory = 2048
        ip     = "10.5.0.2"
      }
    }
    workers = {
      "worker01" = {
        cpus   = 4
        memory = 2048
        ip     = "10.5.0.3"
      },
      "worker02" = {
        cpus   = 4
        memory = 2048
        ip     = "10.5.0.4"
      },
      "worker03" = {
        cpus   = 4
        memory = 2048
        ip     = "10.5.0.5"
      }
    }
  }
}
