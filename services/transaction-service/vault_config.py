# vault_config.py — add this as a separate file in each service directory
import os

def load_vault_secrets(path="/vault/secrets/config"):
    """
    Load secrets written by Vault Agent Injector into environment variables.
    Falls back gracefully if file doesn't exist (local dev without Vault).
    """
    if not os.path.exists(path):
        return  # running locally without Vault — use existing env vars
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "=" in line:
                key, _, value = line.partition("=")
                os.environ.setdefault(key.strip(), value.strip())