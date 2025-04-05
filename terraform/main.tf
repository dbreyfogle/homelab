# [[ Upload VM image ]]

resource "proxmox_virtual_environment_file" "nixos-generator" {
  content_type = "iso"
  datastore_id = "local"
  node_name    = var.node_name
  source_file {
    path      = "../result/nixos.qcow2"
    file_name = "nixos-generator.img"
  }
}

# [[ Create K3s nodes ]]

resource "proxmox_virtual_environment_vm" "k3s_server_vm" {
  count     = var.num_servers
  name      = "k3s-server-${count.index}"
  node_name = var.node_name
  vm_id     = var.start_vm_id + count.index
  on_boot   = true

  agent {
    enabled = true
  }

  cpu {
    cores = 2
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = 4096
  }

  disk {
    datastore_id = "local-lvm"
    file_id      = proxmox_virtual_environment_file.nixos-generator.id
    interface    = "scsi0"
    discard      = "on"
    ssd          = true
    backup       = false
    size         = 75
  }

  network_device {
    bridge  = "vmbr0"
    vlan_id = var.vlan_id
  }
}

# [[ Generate K3s token ]]

resource "random_password" "k3s_token" {
  length  = 32
  special = false
}

resource "hcp_vault_secrets_secret" "k3s_token" {
  app_name     = "homelab"
  secret_name  = "k3s_token"
  secret_value = random_password.k3s_token.result
}

# [[ Deploy with nixos-anywhere ]]

locals {
  init_server_ip = proxmox_virtual_environment_vm.k3s_server_vm[0].ipv4_addresses[1][0]
}

module "deploy" {
  source = "github.com/nix-community/nixos-anywhere//terraform/all-in-one"
  count  = var.num_servers

  nixos_system_attr      = ".#nixosConfigurations.k3s-server.config.system.build.toplevel"
  nixos_partitioner_attr = ".#nixosConfigurations.k3s-server.config.system.build.diskoScript"

  target_host = proxmox_virtual_environment_vm.k3s_server_vm[count.index].ipv4_addresses[1][0]
  instance_id = proxmox_virtual_environment_vm.k3s_server_vm[count.index].ipv4_addresses[1][0]

  special_args = {
    terraform = {
      serverNum  = count.index
      k3sToken   = random_password.k3s_token.result
      serverAddr = "https://${local.init_server_ip}:6443"
    }
  }
}

# [[ Save kubeconfig ]]

resource "null_resource" "kubeconfig" {
  depends_on = [module.deploy]

  provisioner "local-exec" {
    command = <<EOT
      mkdir -p ${path.module}/../secrets
      scp -o StrictHostKeyChecking=no root@${local.init_server_ip}:/etc/rancher/k3s/k3s.yaml ${path.module}/../secrets/k3s.yaml
      sed -i 's/127.0.0.1/${local.init_server_ip}/' ${path.module}/../secrets/k3s.yaml
    EOT
  }
}

data "local_sensitive_file" "kubeconfig" {
  depends_on = [null_resource.kubeconfig]
  filename   = "${path.module}/../secrets/k3s.yaml"
}

resource "hcp_vault_secrets_secret" "kubeconfig" {
  app_name     = "homelab"
  secret_name  = "kubeconfig"
  secret_value = data.local_sensitive_file.kubeconfig.content
}
