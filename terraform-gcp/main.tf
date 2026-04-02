provider "google" {
  credentials = file("${path.module}/credentials.json")
  project     = var.project_id
  region      = var.gcp_region
  zone        = var.gcp_zone
}

locals {
  wg0_conf = replace(
    templatefile("${path.module}/templates/wg0.conf.tftpl", {
      gcp_private_key      = var.gcp_private_key
      blackview_public_key = var.blackview_public_key
      wireguard_port       = var.wireguard_port
      peer_tunnel_ip       = var.wireguard_peer_tunnel_ip
    }),
    "\r",
    "",
  )

  # Strip CR: Windows-sourced templates otherwise yield exit 127 (bad shebang / command not found) on Linux.
  startup_script = replace(
    templatefile("${path.module}/templates/startup.sh.tftpl", {
      wg0_conf                 = local.wg0_conf
      minecraft_port           = var.minecraft_port
      wireguard_peer_tunnel_ip = var.wireguard_peer_tunnel_ip
      # .tftpl does not treat $$ like HCL strings; pass a literal $ for awk/bash.
      dollar = "$"
    }),
    "\r",
    "",
  )
}

resource "google_compute_network" "lab" {
  name                    = "${var.instance_name}-vpc"
  auto_create_subnetworks = true
}

resource "google_compute_firewall" "wireguard" {
  name    = "${var.instance_name}-udp-wireguard"
  network = google_compute_network.lab.name

  allow {
    protocol = "udp"
    ports    = [tostring(var.wireguard_port)]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["lab-edge"]
}

resource "google_compute_firewall" "minecraft" {
  name    = "${var.instance_name}-tcp-minecraft"
  network = google_compute_network.lab.name

  allow {
    protocol = "tcp"
    ports    = [tostring(var.minecraft_port)]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["lab-edge"]
}

# SSH over Identity-Aware Proxy (does not expose :22 to the public internet)
resource "google_compute_firewall" "iap_ssh" {
  name    = "${var.instance_name}-iap-ssh"
  network = google_compute_network.lab.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["lab-edge"]
}

resource "google_compute_instance" "edge" {
  name         = var.instance_name
  machine_type = "e2-micro"
  zone         = var.gcp_zone

  # Required for DNAT / forwarding to WireGuard peers (in addition to sysctl on the guest).
  can_ip_forward = true

  tags = ["lab-edge"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 30
      type  = "pd-standard"
    }
  }

  network_interface {
    network = google_compute_network.lab.name
    access_config {}
  }

  metadata_startup_script = local.startup_script

  service_account {
    email = google_service_account.edge.email
    scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring.write",
    ]
  }

  depends_on = [
    google_project_iam_member.edge_log_writer,
  ]
}

resource "google_service_account" "edge" {
  account_id   = replace("${var.instance_name}-sa", "_", "-")
  display_name   = "Lab edge VM"
  description    = "Service account for ${var.instance_name}"
}

resource "google_project_iam_member" "edge_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.edge.email}"
}
