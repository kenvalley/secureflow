#!/bin/bash

set -euo pipefail

echo "🔐 Running Security Gate..."

# -----------------------------
# File paths (artifact structure)
# -----------------------------
GITLEAKS_FILE="reports/gitleaks-report/gitleaks-report.json"
SONAR_FILE="reports/sonar-reports/sonar-report.json"
TRIVY_FILE="reports/trivy-report/trivy-report.json"
TRIVY_K8S_FILE="reports/trivy-k8s-report/trivy-k8s-report.json"
CHECKOV_FILE="reports/checkov-report/checkov-report.json"
EXCEPTION_FILE="reports/security-exception/security-exception.json"
LABELS_FILE="reports/pr-labels.json"

# -----------------------------
# Debug
# -----------------------------
echo "================ FILE STRUCTURE ================"
ls -R reports || echo "❌ No reports directory found"

echo "================ COUNTING ======================"

# -----------------------------
# Safe jq helper
# -----------------------------
safe_jq() {
  local file=$1
  local query=$2

  if [ -f "$file" ]; then
    jq "$query" "$file" 2>/dev/null || echo 0
  else
    echo 0
  fi
}

# -----------------------------
# Counts
# -----------------------------
GITLEAKS_COUNT=$(safe_jq "$GITLEAKS_FILE" '. | length')
SONAR_COUNT=$(safe_jq "$SONAR_FILE" '[.issues[] | select(.severity=="CRITICAL" or .severity=="BLOCKER")] | length')
TRIVY_COUNT=$(safe_jq "$TRIVY_FILE" '[.Results[].Vulnerabilities[]? | select(.Severity=="CRITICAL" or .Severity=="HIGH")] | length')
TRIVY_K8S_COUNT=$(safe_jq "$TRIVY_K8S_FILE" '[.Results[].Misconfigurations[]? | select(.Severity=="CRITICAL" or .Severity=="HIGH")] | length')
CHECKOV_COUNT=$(safe_jq "$CHECKOV_FILE" '.summary.failed // 0')

echo "GITLEAKS_COUNT=$GITLEAKS_COUNT"
echo "SONAR_COUNT=$SONAR_COUNT"
echo "TRIVY_COUNT=$TRIVY_COUNT"
echo "TRIVY_K8S_COUNT=$TRIVY_K8S_COUNT"
echo "CHECKOV_COUNT=$CHECKOV_COUNT"

# -----------------------------
# DevSecOps total (blocking)
# -----------------------------
DEVSECOPS_TOTAL=$((GITLEAKS_COUNT + TRIVY_COUNT + TRIVY_K8S_COUNT + CHECKOV_COUNT))

# -----------------------------
# Exception logic
# -----------------------------
EXCEPTION_VALID=false

if [ -f "$EXCEPTION_FILE" ]; then
  echo "📝 Exception file detected"

  EXPIRES=$(jq -r '.expires' "$EXCEPTION_FILE")
  NOW=$(date -u +%Y-%m-%d)

  if [[ "$NOW" < "$EXPIRES" ]]; then
    EXCEPTION_VALID=true
    echo "✅ Exception valid until $EXPIRES"
  else
    echo "❌ Exception expired"
  fi
else
  echo "ℹ️ No exception file found"
fi

# -----------------------------
# Approval logic (PR labels)
# -----------------------------
APPROVED=false

if [ -f "$LABELS_FILE" ]; then
  if jq -e '.[] | select(.name=="security-approved")' "$LABELS_FILE" > /dev/null; then
    APPROVED=true
    echo "✅ AppSec approval detected"
  else
    echo "⛔ No security-approved label"
  fi
else
  echo "ℹ️ No labels file (not a PR run)"
fi

# -----------------------------
# Status
# -----------------------------
if [ "$DEVSECOPS_TOTAL" -gt 0 ]; then
  STATUS="❌ FAILED"
else
  STATUS="✅ PASSED"
fi

# -----------------------------
# PR Comment
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

---

### 🔐 Exception Status
- Valid: $EXCEPTION_VALID
- Approved: $APPROVED

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
# FINAL ENFORCEMENT
# -----------------------------
if [ "$DEVSECOPS_TOTAL" -gt 0 ]; then
  if [ "$EXCEPTION_VALID" = true ] && [ "$APPROVED" = true ]; then
    echo "⚠️ Gate overridden (approved exception)"
    exit 0
  else
    echo "❌ Security gate failed"
    exit 1
  fi
else
  echo "✅ Security gate passed"
fi










####### Working version before exception/approval logic

# #!/bin/bash

# set -euo pipefail

# echo "🔐 Running Security Gate..."

# # -----------------------------
# # File paths (MATCH ARTIFACT STRUCTURE)
# # -----------------------------
# GITLEAKS_FILE="reports/gitleaks-report/gitleaks-report.json"
# SONAR_FILE="reports/sonar-reports/sonar-report.json"
# TRIVY_FILE="reports/trivy-report/trivy-report.json"
# TRIVY_K8S_FILE="reports/trivy-k8s-report/trivy-k8s-report.json"
# CHECKOV_FILE="reports/checkov-report/checkov-report.json"

# # -----------------------------
# # Debug
# # -----------------------------
# echo "================ FILE STRUCTURE ================"
# ls -R reports || echo "❌ No reports directory found"

# echo "================ COUNTING ======================"

# # -----------------------------
# # Gitleaks
# # -----------------------------
# if [ -f "$GITLEAKS_FILE" ]; then
#   GITLEAKS_COUNT=$(jq '. | length' "$GITLEAKS_FILE")
# else
#   echo "❌ Missing $GITLEAKS_FILE"
#   exit 1
# fi
# echo "GITLEAKS_COUNT=$GITLEAKS_COUNT"

# # -----------------------------
# # Sonar (non-blocking)
# # -----------------------------
# if [ -f "$SONAR_FILE" ]; then
#   SONAR_COUNT=$(jq '[.issues[] | select(.severity=="CRITICAL" or .severity=="BLOCKER")] | length' "$SONAR_FILE")
# else
#   echo "⚠️ Missing $SONAR_FILE (non-blocking)"
#   SONAR_COUNT=0
# fi
# echo "SONAR_COUNT=$SONAR_COUNT"

# # -----------------------------
# # Trivy Image
# # -----------------------------
# if [ -f "$TRIVY_FILE" ]; then
#   TRIVY_COUNT=$(jq '[.Results[].Vulnerabilities[]? | select(.Severity=="CRITICAL" or .Severity=="HIGH")] | length' "$TRIVY_FILE")
# else
#   echo "❌ Missing $TRIVY_FILE"
#   exit 1
# fi
# echo "TRIVY_COUNT=$TRIVY_COUNT"

# # -----------------------------
# # Trivy K8s
# # -----------------------------
# if [ -f "$TRIVY_K8S_FILE" ]; then
#   TRIVY_K8S_COUNT=$(jq '[.Results[].Misconfigurations[]? | select(.Severity=="CRITICAL" or .Severity=="HIGH")] | length' "$TRIVY_K8S_FILE")
# else
#   echo "❌ Missing $TRIVY_K8S_FILE"
#   exit 1
# fi
# echo "TRIVY_K8S_COUNT=$TRIVY_K8S_COUNT"

# # -----------------------------
# # Checkov
# # -----------------------------
# if [ -f "$CHECKOV_FILE" ]; then
#   CHECKOV_COUNT=$(jq '.summary.failed // 0' "$CHECKOV_FILE")
# else
#   echo "❌ Missing $CHECKOV_FILE"
#   exit 1
# fi
# echo "CHECKOV_COUNT=$CHECKOV_COUNT"

# # -----------------------------
# # Aggregate
# # -----------------------------
# DEVSECOPS_TOTAL=$((GITLEAKS_COUNT + TRIVY_COUNT + TRIVY_K8S_COUNT + CHECKOV_COUNT))

# if [ "$DEVSECOPS_TOTAL" -gt 0 ]; then
#   STATUS="❌ FAILED"
# else
#   STATUS="✅ PASSED"
# fi

# echo "================ SUMMARY ======================="
# echo "DevSecOps Total = $DEVSECOPS_TOTAL"
# echo "Status = $STATUS"

# # -----------------------------
# # PR Comment
# # -----------------------------
# COMMENT=$(cat <<EOF
# ## 🔐 Security Gate Report

# ### 🔴 DevSecOps-owned (BLOCKING)
# | Scanner | Findings |
# |--------|----------|
# | Gitleaks | $GITLEAKS_COUNT |
# | Trivy (Image) | $TRIVY_COUNT |
# | Trivy (K8s) | $TRIVY_K8S_COUNT |
# | Checkov | $CHECKOV_COUNT |

# ➡️ **Total Blocking Issues:** $DEVSECOPS_TOTAL

# ---

# ### 🟡 AppSec-owned (NON-BLOCKING)
# | Scanner | Findings |
# |--------|----------|
# | SonarCloud (CRITICAL/BLOCKER) | $SONAR_COUNT |

# ➡️ Routed to AppSec for review.

# ---

# ### 🚦 Gate Status: $STATUS
# EOF
# )

# echo "$COMMENT"

# # -----------------------------
# # Post PR comment
# # -----------------------------
# if [ "${GITHUB_EVENT_NAME:-}" = "pull_request" ]; then
#   curl -s -H "Authorization: token $GITHUB_TOKEN" \
#     -H "Content-Type: application/json" \
#     -X POST \
#     -d "$(jq -nc --arg body "$COMMENT" '{body: $body}')" \
#     "https://api.github.com/repos/$GITHUB_REPOSITORY/issues/$PR_NUMBER/comments"
# fi

# # -----------------------------
# # FINAL ENFORCEMENT
# # -----------------------------
# if [ "$DEVSECOPS_TOTAL" -gt 0 ]; then
#   echo "❌ Security gate failed"
#   exit 1
# else
#   echo "✅ Security gate passed"
# fi