output "instance_name" {
  description = "Compute Engine instance name."
  value       = google_compute_instance.edge.name
}

output "instance_external_ip" {
  description = "Public IP for WireGuard Endpoint= and Minecraft clients (after DNAT to home)."
  value       = google_compute_instance.edge.network_interface[0].access_config[0].nat_ip
}

output "instance_zone" {
  description = "Zone of the edge instance."
  value       = google_compute_instance.edge.zone
}

output "wireguard_listen_port" {
  description = "UDP port opened for WireGuard."
  value       = var.wireguard_port
}
