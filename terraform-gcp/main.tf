locals {
  # Prefer explicit path; else credentials.json next to this module; else ADC (GOOGLE_APPLICATION_CREDENTIALS / TFC env).
  gcp_credentials_json = var.gcp_credentials_file != null ? file(var.gcp_credentials_file) : (
    fileexists("${path.module}/credentials.json") ? file("${path.module}/credentials.json") : null
  )
}

provider "google" {
  credentials = local.gcp_credentials_json
  project     = var.project_id
  region      = var.gcp_region
  zone        = var.gcp_zone
}

# Derive the GCP WireGuard public key from gcp_private_key (Python + cryptography; same as wg pubkey).
data "external" "gcp_wg_public_key" {
  program = ["python", "${path.module}/scripts/wg_pubkey_from_private.py"]
  query = {
    private_key = local.wg_private_key
  }
}

locals {
  wg0_conf = replace(
    templatefile("${path.module}/templates/wg0.conf.tftpl", {
      gcp_private_key      = local.wg_private_key
      blackview_public_key = local.blackview_public_key
      laptop_public_key    = local.laptop_public_key
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

  gcp_wireguard_public_key_derived = try(data.external.gcp_wg_public_key.result.pubkey, "")
  blackview_sync_enabled           = local.gcp_wireguard_public_key_derived != ""
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

resource "google_compute_address" "vpn_static_ip" {
  name         = "${var.instance_name}-vpn-ip"
  project      = var.project_id
  region       = var.gcp_region
  address_type = "EXTERNAL"
  network_tier = "PREMIUM"
}

resource "google_compute_instance" "edge" {
  name         = var.instance_name
  machine_type = var.machine_type
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
    access_config {
      nat_ip       = google_compute_address.vpn_static_ip.address
      network_tier = "PREMIUM"
    }
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
    google_compute_address.vpn_static_ip,
  ]
}

resource "google_service_account" "edge" {
  account_id   = replace("${var.instance_name}-sa", "_", "-")
  display_name = "Lab edge VM"
  description  = "Service account for ${var.instance_name}"
}

resource "google_project_iam_member" "edge_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.edge.email}"
}

resource "local_file" "blackview_wg_sync" {
  count = local.blackview_sync_enabled ? 1 : 0

  filename             = abspath("${path.module}/.generated/blackview-wg-sync.sh")
  file_permission      = "0644"
  directory_permission = "0755"
  content = replace(
    templatefile("${path.module}/templates/blackview-wg-sync.sh.tftpl", {
      endpoint_host = google_compute_address.vpn_static_ip.address
      wg_port       = var.wireguard_port
      gcp_pubkey    = local.gcp_wireguard_public_key_derived
    }),
    "\r",
    "",
  )
}

resource "null_resource" "sync_blackview_vpn" {
  count = local.blackview_sync_enabled ? 1 : 0

  triggers = {
    instance_id = google_compute_instance.edge.id
    static_ip   = google_compute_address.vpn_static_ip.address
    pubkey      = local.gcp_wireguard_public_key_derived
  }

  depends_on = [
    google_compute_instance.edge,
    google_compute_address.vpn_static_ip,
    local_file.blackview_wg_sync,
  ]

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-NoProfile", "-Command"]
    # Remote tr strips CR from script (local_file may use CRLF on Windows).
    command = "$p = '${replace(local_file.blackview_wg_sync[0].filename, "'", "''")}'.Replace('\\', '/'); Get-Content -LiteralPath $p -Raw | ssh -o BatchMode=yes -o StrictHostKeyChecking=no ${var.blackview_ssh_user}@${var.blackview_ssh_host} \"tr -d '\\r' | bash -s\""
  }
}
