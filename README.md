# Hybrid cloud–home lab

This monorepo holds **GCP edge infrastructure** (Terraform) and **home Kubernetes manifests** for a Minecraft server reachable through a WireGuard tunnel.

## Layout

| Path | Purpose |
|------|--------|
| `terraform-gcp/` | GCP: `e2-micro` (Debian 12, 30 GB `pd-standard`), WireGuard, DNAT for Minecraft |
| `k8s-manifests/` | `itzg/minecraft-server` Deployment + LoadBalancer Service (MetalLB-friendly) |

## Architecture

1. A small VM in **us-central1** runs WireGuard (`wg0`, tunnel `10.0.0.1/24`).
2. Inbound **TCP 25565** on the VM’s public interface is **DNAT** to the home peer at **`10.0.0.2:25565`** (WireGuard IP you assign on the Blackview / home side).
3. **POSTROUTING MASQUERADE** on **`wg0`** is applied as specified for NAT traversal on the tunnel.
4. At home, Kubernetes exposes Minecraft on **25565** (Service → pods); the GCP DNAT targets that port on `10.0.0.2`.

Clients connect to the **GCP public IP**, **TCP 25565**; traffic is forwarded over WireGuard to your cluster.

## Prerequisites

- GCP project with billing enabled (Always Free still requires a billing account).
- [Terraform](https://www.terraform.io/) ≥ 1.5. On Windows, if `terraform` is missing from PATH: `winget install Hashicorp.Terraform` (then reopen the terminal), or install from [Terraform downloads](https://developer.hashicorp.com/terraform/install).
- **`terraform-gcp/credentials.json`**: JSON key for **`terraform-lab-sa`** (created via `gcloud`; listed in `.gitignore`). The Google provider loads it with `file("${path.module}/credentials.json")`.
- WireGuard keys: one **private** key for the GCP side (`gcp_private_key`) and the home peer’s **public** key (`blackview_public_key`).
- Home cluster with **MetalLB** (or another LoadBalancer implementation) if you use `type: LoadBalancer` as written.

## Terraform (`terraform-gcp/`)

1. Ensure **`credentials.json`** exists (service account **`terraform-lab-sa`**) and is **never** committed.
2. Edit **`terraform.tfvars`**: set **`gcp_private_key`** and **`blackview_public_key`** (committed defaults are placeholders). **`project_id`** should match the project where the key was issued.
3. The automation SA needs, at minimum, **`roles/compute.admin`**, **`roles/iam.serviceAccountUser`**, and **`roles/logging.logWriter`**. Creating the VM’s own service account and project IAM bindings also requires **`roles/iam.serviceAccountAdmin`** and **`roles/resourcemanager.projectIamAdmin`** (grant these on `terraform-lab-sa` if `terraform apply` returns permission errors).
4. Optionally override `gcp_region` / `gcp_zone` (defaults: `us-west1` / `us-west1-a`; `e2-micro` stock varies—try another zone/region or `machine_type = "e2-small"` if apply fails). **`google_compute_address.vpn_static_ip`** reserves the NAT IP; outputs **`gcp_public_ip`** match **`instance_external_ip`**.
5. Initialize and apply:

```bash
cd terraform-gcp
terraform init
terraform plan
terraform apply
```

6. Note `instance_external_ip` from outputs; use it as **`Endpoint`** on the **home** WireGuard client and for Minecraft **Server Address** in the game client.

### Generated automation

- **`templates/wg0.conf.tftpl`** is rendered via `templatefile` and written to `/etc/wireguard/wg0.conf` on first boot.
- **`templates/startup.sh.tftpl`** installs **WireGuard** and **iptables-persistent**, enables **IPv4 forwarding**, brings up **`wg0`**, applies **DNAT** and **MASQUERADE**, and saves **iptables** rules.

The startup script resolves the **WAN** interface from **`ip route show default`** (with a fallback) so it works when GCE uses **`ens4`** instead of **`eth0`**.

**Template note:** Terraform **`.tftpl`** files do **not** treat `$$` like normal HCL strings. Literal **`$`** for **awk** (`$5`) and bash (**`$WAN_IF`**) is passed via a template variable **`dollar`** in **`main.tf`** so the guest script is not corrupted (mistaken `$$` in bash expands to the shell PID and breaks **iptables** `-i`).

**Blackview sync:** When **`gcp_private_key`** is a real WireGuard key (not a placeholder), Terraform runs **`null_resource.sync_blackview_vpn`** after the edge instance exists: it renders **`templates/blackview-wg-sync.sh.tftpl`** under **`.generated/`** (gitignored) and pipes it over **SSH** (`-o StrictHostKeyChecking=no`) to **`salad@192.168.0.69`** (override with **`blackview_ssh_host`** / **`blackview_ssh_user`**), updating **`Endpoint`** and **`[Peer] PublicKey`** in **`/etc/wireguard/wg0.conf`**, then **`wg-quick down wg0`** / **`up`**. Requires **Python** + **`pip install cryptography`** on the workstation running **`terraform apply`**.

### SSH

Firewall allows **TCP 22** only from **Google IAP** (`35.235.240.0/20`). Use [IAP TCP forwarding](https://cloud.google.com/iap/docs/using-tcp-forwarding) or the console **SSH** button.

## Kubernetes (`k8s-manifests/`)

```bash
kubectl apply -f k8s-manifests/
```

Manifests are prefixed (`00-`, `10-`, `20-`) so a directory apply creates the namespace before workloads. To use **NodePort** instead of MetalLB, change `spec.type` in `20-service.yaml` to `NodePort` and optionally set `spec.ports[0].nodePort`.

- **Deployment**: `itzg/minecraft-server` with `EULA=TRUE` and a `emptyDir` volume for `/data` (replace with a `PersistentVolumeClaim` for real persistence).
- **Service**: `LoadBalancer` on port **25565**; add a MetalLB annotation if you assign a fixed LB IP.

Ensure the **home WireGuard peer** uses tunnel address **`10.0.0.2/24`** (or change `wireguard_peer_tunnel_ip` in Terraform and keep DNAT consistent).

## Verification status (lab)

Last engineering check: **2026-04-02** (automated from the dev workstation + IAP).

| Item | Result |
|------|--------|
| **GCP edge** | Reserved IP **`google_compute_address.vpn_static_ip`**; run **`terraform output -raw gcp_public_ip`** for the current address. Last apply used **`us-west1-a`** (moved from **`us-central1`** when **`e2-micro`** was unavailable). **WireGuard** listens on **UDP port 51820** on that IP. |
| **`wg-quick@wg0` on GCP** | **Up**; **`sudo wg show`** lists the home peer key and **`AllowedIPs 10.0.0.2/32`**. |
| **WireGuard handshake** | After **`terraform apply`** with real keys, **`null_resource.sync_blackview_vpn`** should set **Blackview** **`Endpoint`** to **`gcp_public_ip`**. Otherwise set **`Endpoint`** manually to **`terraform output -raw gcp_public_ip`**. |
| **NAT / forwarding** | **`iptables -t nat`**: **DNAT** `ens4` **TCP 25565 → `10.0.0.2:25565`**; **POSTROUTING MASQUERADE** on **`wg0`**. (An earlier startup used literal `$$` in bash, which broke the `-i` interface name; **Terraform + `startup.sh.tftpl` are fixed**; a **one-time iptables remediation** was applied on the running VM.) |
| **Ping / `nc` from GCP to `10.0.0.2`** | **Fails** until the tunnel is up (**“Destination Host Unreachable”** / **“No route to host”** is expected with the peer offline). |
| **Blackview → `10.0.0.1`** | Run locally after the client shows a handshake: **`ping -c 3 10.0.0.1`**. |
| **Minecraft path** | From the edge after handshake: **`nc -zv 10.0.0.2 25565`** should succeed if something listens on the home peer at **25565/tcp**. |
| **Home `kubectl` (192.168.0.69)** | **`kubectl get svc -A \| grep minecraft`** requires a kubeconfig **`salad`** can read (e.g. copy **`/etc/rancher/k3s/k3s.yaml`** with **`--write-kubeconfig-mode 644`** or add the user to the right group). No `minecraft` Service was confirmed from this environment. |

**Logs:** If **`wg0`** misbehaves on the VM: **`sudo journalctl -u wg-quick@wg0 -b --no-pager`**. Serial / startup: first boot previously logged **`Script "startup-script" failed with error: exit status 127`** due to **CRLF / `$$`** issues; that is addressed in **`main.tf`** (**`replace(..., "\r", "")`**) and the **`dollar`** template variable.

**Terraform:** Changing **`metadata_startup_script`** forces **instance replacement**. After pulling these fixes, run **`terraform apply`** when you are ready to recycle the VM (watch for **per-zone `e2-micro` stockouts**).

## Security notes

- Never commit **`credentials.json`**, **`.tfstate*`**, real WireGuard **private** keys, or **`.kube/config`**. If **`terraform.tfvars`** contains real secrets, stop tracking local changes (`git update-index --skip-worktree terraform-gcp/terraform.tfvars`) or keep overrides in an untracked `*.auto.tfvars` file.
- Rotate keys if they are ever exposed; restrict GCP firewall `source_ranges` if you do not need the whole internet on **25565**.

## License

Repository contents are provided as infrastructure-as-code examples; use and adapt under your own policies.
