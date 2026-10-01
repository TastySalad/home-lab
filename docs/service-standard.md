# Service Access Standard + Punch-List

_Last updated: 2026-10-01 (Salad's home-lab standardization)._

## The Standard (what every service must have)

1. **HTTPS only** — TLS terminated by the Tailscale Operator (`ts-<svc>` pod, port 443). No plain-HTTP tailnet exposure.
2. **Tailnet-only** — never exposed beyond the `manatee-ruffe.ts.net` tailnet (unless explicitly a public game, e.g. Minecraft).
3. **Auth** — at least one gate:
   - **App login** (built-in) where the app has one — e.g. Odysseus.
   - **Bearer API token** (nginx `auth_request`) where the app has none — e.g. llama-swap.
   - Tailnet membership is always the outer gate.
4. **Clean MagicDNS name** — `https://<service>.manatee-ruffe.ts.net`. No raw `host:port` in normal use.
5. **GitOps** — manifests in `k8s-manifests/<service>/` (its own subdir), ArgoCD app in `ops/argocd/applications/<service>.yaml`, `prune+selfHeal`. Git is the source of truth.
6. **Secrets out of git** — tokens/passwords live in k8s Secrets, created imperatively and rotated out-of-band.

## Service Inventory (current)

| Service | URL | Backend | Auth | State |
|---|---|---|---|---|
| **Odysseus** (AI workspace) | `https://odysseus.manatee-ruffe.ts.net` | nginx pod → host app `192.168.0.1:7000` | app login | ✅ up |
| **llama-swap** (brain) | `https://llama.manatee-ruffe.ts.net` | nginx pod + auth sidecar → `192.168.0.233:11434` | Bearer token | ✅ up |
| Netdata | `https://netdata.manatee-ruffe.ts.net` | DaemonSet | — | ✅ up |
| CTI Scan | `https://cti.manatee-ruffe.ts.net` | k3s | — | ✅ up |
| L0p4Map | `https://l0p4map.manatee-ruffe.ts.net` | k3s | — | ✅ up |
| CVE Report | `https://cve-report.manatee-ruffe.ts.net` | k3s | — | ✅ up |
| Diagrams | `https://diagrams.manatee-ruffe.ts.net` | nginx hostPath | — | ✅ up |
| Home dashboard | `https://home.manatee-ruffe.ts.net` | nginx hostPath | — | ✅ up |
| ArgoCD | `https://argocd.manatee-ruffe.ts.net` | k3s | ArgoCD login | ✅ up |
| Hermes Dashboard | `http://salad-playground.manatee-ruffe.ts.net:9119` | `tailscale serve` → `127.0.0.1:9119` | ⚠️ **none** | ⚠️ plain-HTTP |
| Minecraft | `mc.salad-playground.party:25565` | VPS hostNetwork | (public game) | ✅ up |

## llama-swap token

- Stored in k8s Secret `llama/token` (namespace `llama`), **not** in git.
- Operator copy (mode 600): `/home/salad/.llama-token`.
- **Use:** `Authorization: Bearer <token>` header.
- **Rotate:**
  ```bash
  kubectl -n llama create secret generic llama-token \
    --from-literal=token=$(openssl rand -hex 24) \
    --dry-run=client -o yaml | kubectl apply -f -
  cp /home/salad/.llama-token /home/salad/.llama-token.bak   # back up old
  kubectl -n llama rollout restart deploy/llama-proxy
  ```

## 📋 Punch-List — remaining plain-HTTP / no-auth services

Ordered by risk. Each is currently **plain HTTP and/or unauthenticated** — not yet on the standard.

1. ~~**llama-swap plain-HTTP tailnet serve on `8383` — still live, NO auth.**~~ ✅ **RESOLVED 2026-10-01** —
   the `http://…:8383` → `192.168.0.233:11434` no-auth serve was removed (`sudo tailscale serve reset`
   then `sudo tailscale serve --bg 9119` to restore the hermes serve). The brain is now reachable
   only via `https://llama.manatee-ruffe.ts.net` with a Bearer token.
2. **⚠️ Hermes Dashboard `:9119` — plain HTTP, no auth** (`tailscale serve` → `127.0.0.1:9119`).
   Put it on `https://hermes.manatee-ruffe.ts.net` (Tailscale Operator ingress) with a
   Bearer-token `auth_request` gate (same pattern as llama).
3. **Netdata / CTI / L0p4Map / CVE-Report / Diagrams / Home** — HTTPS + tailnet-only ✅, but **no per-service auth** (anyone on the tailnet can read). Add a Bearer-token or app-login gate where the app doesn't already have one, to fully meet "everything with auth".
4. **Minecraft** — intentionally public (game). Fine, but note it's the one exception to tailnet-only.

## GitOps layout convention (for all future services)

```
k8s-manifests/<service>/
  namespace.yaml
  nginx-configmap.yaml     # if reverse-proxying a LAN/backend
  auth-configmap.yaml      # if a Bearer-token gate is needed
  deployment.yaml
  service.yaml
  ingress.yaml             # tailscale.com/hostname + ingressClassName: tailscale
ops/argocd/applications/<service>.yaml   # path: k8s-manifests/<service>, prune+selfHeal
```
Each service in its **own subdir** — keeps it isolated from the legacy `lab-core`
bundle app (which points at the non-recursive `k8s-manifests/` top level and has no
filter, so it would otherwise claim/prune any loose top-level manifest).
