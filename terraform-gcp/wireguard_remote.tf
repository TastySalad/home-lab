# Configure WireGuard on the GCP VM over SSH (internal IP). Intended for HCP Terraform Agent runs
# that can reach the VPC (e.g. agent on home network with existing path to GCE internal address).
variable "gcp_vm_ssh_user" {
  type        = string
  description = "Linux user on the GCE instance for SSH (Debian cloud image default is often the first metadata key user)."
  default     = "debian"
}

variable "gcp_vm_ssh_private_key" {
  type        = string
  sensitive   = true
  default     = ""
  description = "PEM private key for SSH to the edge VM when not using Vault (see vault_key_vm_ssh_private_key)."
}

variable "wireguard_remote_provisioner_enabled" {
  type        = bool
  description = "If true and vm_ssh_private_key is non-empty, apply wg0.conf over SSH and restart wg-quick@wg0."
  default     = true
}

variable "wireguard_verify_ping" {
  type        = bool
  description = "If true, run local-exec ping from the agent after remote WireGuard configuration."
  default     = true
}

variable "wireguard_ping_target" {
  type        = string
  description = "WireGuard tunnel IP on the GCP side (see templates/wg0.conf.tftpl Address)."
  default     = "10.0.0.1"
}

locals {
  wireguard_ssh_configured = var.wireguard_remote_provisioner_enabled && trimspace(local.vm_ssh_private_key) != ""
}

resource "null_resource" "wireguard_gcp_vm_configure" {
  count = local.wireguard_ssh_configured ? 1 : 0

  triggers = {
    instance_id    = google_compute_instance.edge.id
    internal_ip    = google_compute_instance.edge.network_interface[0].network_ip
    wg_conf_sha256 = sha256(local.wg0_conf)
  }

  connection {
    type        = "ssh"
    user        = var.gcp_vm_ssh_user
    private_key = trimspace(local.vm_ssh_private_key)
    host        = google_compute_instance.edge.network_interface[0].network_ip
    timeout     = "5m"
  }

  provisioner "file" {
    destination = "/tmp/wg0.conf.terraform"
    content     = local.wg0_conf
  }

  provisioner "remote-exec" {
    inline = [
      "sudo DEBIAN_FRONTEND=noninteractive apt-get update -qq",
      "(dpkg -s wireguard-tools >/dev/null 2>&1 || dpkg -s wireguard >/dev/null 2>&1) || sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq wireguard-tools wireguard",
      "sudo install -d -m 700 /etc/wireguard",
      "sudo mv /tmp/wg0.conf.terraform /etc/wireguard/wg0.conf",
      "sudo chmod 600 /etc/wireguard/wg0.conf",
      "sudo systemctl enable wg-quick@wg0",
      "sudo systemctl restart wg-quick@wg0 2>/dev/null || sudo systemctl start wg-quick@wg0",
    ]
  }

  depends_on = [
    google_compute_instance.edge,
  ]
}

resource "null_resource" "wireguard_tunnel_ping" {
  count = var.wireguard_verify_ping && local.wireguard_ssh_configured ? 1 : 0

  depends_on = [null_resource.wireguard_gcp_vm_configure]

  triggers = {
    verify_hash = sha256("${null_resource.wireguard_gcp_vm_configure[0].id}:${var.wireguard_ping_target}")
  }

  provisioner "local-exec" {
    interpreter = ["/bin/sh", "-c"]
    command     = "ping -c 3 -W 3 ${var.wireguard_ping_target}"
  }
}
