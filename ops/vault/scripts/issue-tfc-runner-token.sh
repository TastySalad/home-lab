#!/usr/bin/env bash
# Usage (from a machine that can reach Vault with an admin-capable token):
#   export VAULT_ADDR=http://vault.vault.svc.cluster.local:8200   # or your Vault URL
#   export VAULT_TOKEN=s.xxx
#   bash ops/vault/scripts/issue-tfc-runner-token.sh
#
# Writes tfc-runner-policy from the repo policy file (set POLICY_FILE if cwd differs), then prints a new orphan periodic token.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
POLICY_FILE="${POLICY_FILE:-$ROOT/ops/vault/policies/tfc-runner-policy.hcl}"

if [[ -z "${VAULT_TOKEN:-}" ]]; then
  echo "error: set VAULT_TOKEN to a token that can write policies and create orphan tokens" >&2
  exit 1
fi

vault policy write tfc-runner-policy "$POLICY_FILE"

# Orphan periodic token: renewable on a 24h schedule (TFC agent / Terraform renews via provider).
vault token create \
  -orphan \
  -policy=tfc-runner-policy \
  -period=24h \
  -renewable=true \
  -display-name=tfc-terraform-cloud \
  -field=token
