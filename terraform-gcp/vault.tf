# Vault (reachable from HCP Terraform Agent pods at cluster DNS).
# Set TF_VAR_vault_token in the workspace, or leave unset to use TF variable fallbacks below.
variable "vault_addr" {
  type        = string
  description = "Vault API address. In-cluster agent: http://vault.vault.svc.cluster.local:8200"
  default     = "http://vault.vault.svc.cluster.local:8200"
}

variable "vault_token" {
  type        = string
  sensitive   = true
  nullable    = true
  default     = null
  description = "Vault token for KV reads. When null/empty, WireGuard secrets come from gcp_private_key / *_public_key / gcp_vm_ssh_private_key variables instead."
}

variable "vault_skip_tls_verify" {
  type        = bool
  description = "Set true only for lab HTTP Vault without TLS."
  default     = false
}

variable "vault_key_wg_private_key" {
  type        = string
  description = "KV v2 secret/terraform field for the GCP endpoint WireGuard private key."
  default     = "wg-private-key"
}

variable "vault_key_blackview_public_key" {
  type        = string
  description = "KV v2 secret/terraform field for the Blackview peer WireGuard public key."
  default     = "blackview-public-key"
}

variable "vault_key_laptop_public_key" {
  type        = string
  description = "KV v2 secret/terraform field for the laptop peer public key (optional if vault omits it)."
  default     = "laptop-wg-public-key"
}

variable "vault_key_vm_ssh_private_key" {
  type        = string
  description = "KV v2 secret/terraform field for PEM private key used to SSH to the GCE instance (internal IP)."
  default     = "gcp-vm-ssh-private-key"
}

provider "vault" {
  address         = var.vault_addr
  token           = coalesce(var.vault_token, "unused-local-only")
  skip_tls_verify = var.vault_skip_tls_verify
}

locals {
  use_vault = var.vault_token != null && trimspace(var.vault_token) != ""
}

data "vault_kv_secret_v2" "terraform_secrets" {
  count = local.use_vault ? 1 : 0
  mount = "secret"
  name  = "terraform"
}

locals {
  _vault_map = local.use_vault ? data.vault_kv_secret_v2.terraform_secrets[0].data : {}

  # Effective secrets: Vault when token set, else root module variables (variables.tf).
  wg_private_key = local.use_vault ? local._vault_map[var.vault_key_wg_private_key] : var.gcp_private_key

  blackview_public_key = local.use_vault ? local._vault_map[var.vault_key_blackview_public_key] : var.blackview_public_key

  laptop_public_key = local.use_vault ? try(local._vault_map[var.vault_key_laptop_public_key], var.laptop_public_key) : var.laptop_public_key

  vm_ssh_private_key = local.use_vault ? local._vault_map[var.vault_key_vm_ssh_private_key] : var.gcp_vm_ssh_private_key
}
