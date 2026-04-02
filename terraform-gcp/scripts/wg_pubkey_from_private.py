#!/usr/bin/env python3
"""Read JSON on stdin: {\"private_key\": \"<base64 wg private>\"}. Print JSON: {\"pubkey\": \"...\"}."""
import base64
import json
import sys

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric.x25519 import X25519PrivateKey


def main() -> None:
    data = json.load(sys.stdin)
    b64 = data.get("private_key", "").strip()
    if not b64 or "REPLACE" in b64:
        print(json.dumps({"pubkey": "", "error": "invalid_or_placeholder_private_key"}))
        sys.exit(0)
    raw = base64.b64decode(b64)
    if len(raw) != 32:
        print(json.dumps({"pubkey": "", "error": "private_key_must_decode_to_32_bytes"}))
        sys.exit(0)
    priv = X25519PrivateKey.from_private_bytes(raw)
    pub = priv.public_key().public_bytes(
        encoding=serialization.Encoding.Raw,
        format=serialization.PublicFormat.Raw,
    )
    out = base64.b64encode(pub).decode("ascii")
    print(json.dumps({"pubkey": out}))


if __name__ == "__main__":
    main()
