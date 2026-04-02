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

variable "laptop_public_key" {
  description = "WireGuard public key of the roaming laptop peer (Lenovo LOQ)."
  type        = string
}

variable "gcp_region" {
  description = "GCP region for the static IP and (by convention) the edge VM. Default us-west1 after us-central1 capacity issues; override as needed."
  type        = string
  default     = "us-west1"
}

variable "gcp_zone" {
  description = "GCP zone within the region (must match gcp_region)."
  type        = string
  default     = "us-west1-a"
}

variable "instance_name" {
  description = "Name of the Compute Engine VM."
  type        = string
  default     = "lab-edge"
}

variable "machine_type" {
  description = "GCE machine type. Use e2-micro for Always Free when stock allows; fall back to e2-small if zones report capacity errors."
  type        = string
  default     = "e2-micro"
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

variable "blackview_ssh_host" {
  description = "LAN host for local-exec WireGuard sync (null_resource.sync_blackview_vpn)."
  type        = string
  default     = "192.168.0.69"
}

variable "blackview_ssh_user" {
  description = "SSH user on the Blackview host for WireGuard sync."
  type        = string
  default     = "salad"
}
