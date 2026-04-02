# Replace WireGuard placeholders before terraform apply. Do not commit real secrets;
# use git update-index --skip-worktree terraform-gcp/terraform.tfvars after editing locally if needed.

# Must match the GCP project where terraform-lab-sa and credentials.json were created.
project_id = "gns3-test-480909"

# Base64 WireGuard private key for the GCP VM [Interface] (wg genkey)
gcp_private_key = "REPLACE_WITH_GCP_WG_PRIVATE_KEY"

# Base64 WireGuard public key for the home / Blackview peer
blackview_public_key = "REPLACE_WITH_BLACKVIEW_WG_PUBLIC_KEY"

# Optional overrides (defaults match README / main.tf)
# gcp_region              = "us-central1"
gcp_zone = "us-central1-c"
# instance_name           = "lab-edge"
# wireguard_port          = 51820
# minecraft_port          = 25565
# wireguard_peer_tunnel_ip = "10.0.0.2"
