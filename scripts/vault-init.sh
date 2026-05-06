#!/bin/bash
# scripts/vault-init.sh
# Run this after any cluster restart to re-initialise Vault dev mode
# Usage: bash scripts/vault-init.sh

set -e

echo "Initialising Vault dev mode..."

kubectl exec -it vault-0 -n vault -- sh -c '
export VAULT_TOKEN=root
export VAULT_ADDR=http://127.0.0.1:8200

vault auth enable kubernetes 2>/dev/null || true

vault write auth/kubernetes/config \
  kubernetes_host="https://${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT}" \
  kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
  token_reviewer_jwt=@/var/run/secrets/kubernetes.io/serviceaccount/token

vault secrets enable -path=secureflow kv-v2 2>/dev/null || true

vault kv put secureflow/auth-service \
  db_host="auth-db" db_port="5432" db_name="authdb" \
  db_user="authuser" db_password="authpass123" \
  jwt_secret="super-secret-key-123"

vault kv put secureflow/transaction-service \
  db_host="transaction-db" db_port="5432" db_name="transactiondb" \
  db_user="txuser" db_password="txpass123" \
  auth_service_url="http://auth-service:5001"

vault kv put secureflow/frontend \
  session_secret="changeme" \
  auth_service_url="http://auth-service:5001" \
  transaction_service_url="http://transaction-service:5002"

vault policy write auth-service-policy - <<EOF
path "secureflow/data/auth-service" {
  capabilities = ["read"]
}
EOF

vault policy write transaction-service-policy - <<EOF
path "secureflow/data/transaction-service" {
  capabilities = ["read"]
}
EOF

vault policy write frontend-policy - <<EOF
path "secureflow/data/frontend" {
  capabilities = ["read"]
}
EOF

vault write auth/kubernetes/role/auth-service-role \
  bound_service_account_names=auth-service-sa \
  bound_service_account_namespaces=secureflow \
  policies=auth-service-policy \
  ttl=1h

vault write auth/kubernetes/role/transaction-service-role \
  bound_service_account_names=transaction-service-sa \
  bound_service_account_namespaces=secureflow \
  policies=transaction-service-policy \
  ttl=1h

vault write auth/kubernetes/role/frontend-role \
  bound_service_account_names=frontend-sa \
  bound_service_account_namespaces=secureflow \
  policies=frontend-policy \
  ttl=1h

echo "Vault initialisation complete"
'