output "instance_name" {
  description = "Compute Engine instance name."
  value       = google_compute_instance.edge.name
}

output "gcp_public_ip" {
  description = "Reserved static external IP for WireGuard and Minecraft (same as instance NAT)."
  value       = google_compute_address.vpn_static_ip.address
}

output "gcp_wireguard_public_key" {
  description = "WireGuard public key for the GCP [Interface], derived from gcp_private_key."
  value       = nonsensitive(local.gcp_wireguard_public_key_derived)
}

output "instance_external_ip" {
  description = "Alias for gcp_public_ip (NAT on the edge instance)."
  value       = google_compute_address.vpn_static_ip.address
}

output "instance_zone" {
  description = "Zone of the edge instance."
  value       = google_compute_instance.edge.zone
}

output "wireguard_listen_port" {
  description = "UDP port opened for WireGuard."
  value       = var.wireguard_port
}

output "blackview_sync_ran" {
  description = "Whether local WireGuard sync resources were created (requires valid gcp_private_key and Python)."
  value       = local.blackview_sync_enabled
}
