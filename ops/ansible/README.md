# Ansible — VPS & Infrastructure Bootstrapping

This directory contains Ansible playbooks for bootstrapping lab infrastructure.

## Structure

```
ops/ansible/
├── ansible.cfg              # Ansible configuration
├── inventory/
│   ├── hosts.yml            # Host definitions
│   └── group_vars/all/      # Shared variables (incl. vault)
├── playbooks/
│   └── bootstrap.yml        # Full VPS bootstrap
└── roles/
    ├── common/              # Base system hardening
    ├── tailscale/           # Tailscale installation & auth
    └── k3s/                 # K3s agent install & cluster join
```

## Usage

```bash
cd ops/ansible
ansible-playbook playbooks/bootstrap.yml -i inventory/hosts.yml
```

Secrets (Tailscale auth keys, K3s tokens) are stored in `group_vars/all/vault.yml`, encrypted with Ansible Vault. Decrypt with `ansible-vault view --vault-password-file .vault_pass group_vars/all/vault.yml` (vault password file is gitignored).

## Nodes

| Host | Role | IP | Notes |
|------|------|----|-------|
| salad-playground | K3s server + control node | 192.168.0.69 (LAN), 100.109.95.108 (TS) | Home-lab router, Pi-hole |
| racknerd-vps | K3s agent (worker) | 192.210.150.73 (public), 100.116.9.62 (TS) | Public-facing reverse-proxy node |