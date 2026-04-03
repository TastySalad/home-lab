# Terraform Cloud / HCP Terraform agent — least privilege for KV v2 at mount "secret".
# Apply (from repo root): vault policy write tfc-runner-policy ./ops/vault/policies/tfc-runner-policy.hcl

# KV v2 secret payloads (read only)
path "secret/data/terraform" {
  capabilities = ["read"]
}

path "secret/data/threat-intel/*" {
  capabilities = ["read"]
}

# KV v2 metadata (versions, custom metadata); required for some clients that list/read metadata
path "secret/metadata/terraform" {
  capabilities = ["list", "read"]
}
