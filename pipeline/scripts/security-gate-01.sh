#!/bin/bash

set -euo pipefail

echo "🔐 Running Security Gate..."

# -----------------------------
# File paths
# -----------------------------
GITLEAKS_FILE="reports/gitleaks/gitleaks-report.json"
SONAR_FILE="reports/sonar/sonar-report.json"
TRIVY_FILE="reports/trivy/trivy-report.json"
TRIVY_K8S_FILE="reports/trivy-k8s/trivy-k8s-report.json"
CHECKOV_FILE="reports/checkov/checkov-report.json"

# -----------------------------
# Safe jq wrapper
# -----------------------------
safe_jq_count() {
  local file=$1
  local query=$2

  if [ -f "$file" ]; then
    jq "$query" "$file" 2>/dev/null || echo 0
  else
    echo 0
  fi
}

# -----------------------------
# Aggregate counts
# -----------------------------
GITLEAKS_COUNT=$(safe_jq_count "$GITLEAKS_FILE" '. | length')

SONAR_COUNT=$(safe_jq_count "$SONAR_FILE" \
  '[.issues[] | select(.severity=="CRITICAL" or .severity=="BLOCKER")] | length')

TRIVY_COUNT=$(safe_jq_count "$TRIVY_FILE" \
  '[.Results[].Vulnerabilities[]? | select(.Severity=="CRITICAL" or .Severity=="HIGH")] | length')

TRIVY_K8S_COUNT=$(safe_jq_count "$TRIVY_K8S_FILE" \
  '[.Results[].Misconfigurations[]? | select(.Severity=="CRITICAL" or .Severity=="HIGH")] | length')

CHECKOV_COUNT=$(safe_jq_count "$CHECKOV_FILE" '.summary.failed // 0')

DEVSECOPS_TOTAL=$((GITLEAKS_COUNT + TRIVY_COUNT + TRIVY_K8S_COUNT + CHECKOV_COUNT))

if [ "$DEVSECOPS_TOTAL" -gt 0 ]; then
  STATUS="❌ FAILED"
else
  STATUS="✅ PASSED"
fi

# -----------------------------
# Build comment
# -----------------------------
COMMENT=$(cat <<EOF
## 🔐 Security Gate Report

### 🔴 DevSecOps-owned (BLOCKING)
| Scanner | Findings |
|--------|----------|
| Gitleaks | $GITLEAKS_COUNT |
| Trivy (Image) | $TRIVY_COUNT |
| Trivy (K8s) | $TRIVY_K8S_COUNT |
| Checkov | $CHECKOV_COUNT |

➡️ **Total Blocking Issues:** $DEVSECOPS_TOTAL

---

### 🟡 AppSec-owned (NON-BLOCKING)
| Scanner | Findings |
|--------|----------|
| SonarCloud (CRITICAL/BLOCKER) | $SONAR_COUNT |

➡️ These findings are routed to AppSec for review.

📩 Please submit via AppSec Intake (see docs/security-gate-policy.md)

---

### 🚦 Gate Status: $STATUS
EOF
)

echo "$COMMENT"

# -----------------------------
# Post PR comment
# -----------------------------
if [ "${GITHUB_EVENT_NAME:-}" = "pull_request" ]; then
  echo "💬 Posting PR comment..."

  curl -s -H "Authorization: token $GITHUB_TOKEN" \
    -H "Content-Type: application/json" \
    -X POST \
    -d "$(jq -nc --arg body "$COMMENT" '{body: $body}')" \
    "https://api.github.com/repos/$GITHUB_REPOSITORY/issues/$PR_NUMBER/comments"
fi

# -----------------------------
# Enforce gate
# -----------------------------
echo "Blocking issues: $DEVSECOPS_TOTAL"

if [ "$DEVSECOPS_TOTAL" -gt 0 ]; then
  echo "❌ Security gate failed"
  exit 1
else
  echo "✅ Security gate passed"
fi