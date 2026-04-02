variable "project_id" {
  description = "GCP project ID where resources are created."
  type        = string
}

variable "gcp_private_key" {
  description = "WireGuard private key for this GCP instance (Interface section). Keep secret; pass via TF_VAR or encrypted tfvars."
  type        = string
  sensitive   = true
}

variable "blackview_public_key" {
  description = "WireGuard public key of the home / Blackview peer."
  type        = string
}

variable "gcp_region" {
  description = "GCP region (us-central1 aligns with common Always Free e2-micro usage)."
  type        = string
  default     = "us-central1"
}

variable "gcp_zone" {
  description = "GCP zone within the region."
  type        = string
  default     = "us-central1-c"
}

variable "instance_name" {
  description = "Name of the Compute Engine VM."
  type        = string
  default     = "lab-edge"
}

variable "wireguard_port" {
  description = "UDP port for WireGuard."
  type        = number
  default     = 51820
}

variable "minecraft_port" {
  description = "TCP port exposed for Minecraft (firewall + DNAT target on the peer tunnel IP)."
  type        = number
  default     = 25565
}

variable "wireguard_peer_tunnel_ip" {
  description = "Tunnel IP of the home peer inside wg0 (DNAT destination for Minecraft)."
  type        = string
  default     = "10.0.0.2"
}
