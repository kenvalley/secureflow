
# # ---

# # ### `pipeline/scripts/security-gate.sh`

# # ### **aggregation + PR comment engine**.

# # It:
# # - reads all tool outputs
# # - computes pass/fail
# # - posts GitHub PR comment (optional)

# # ---
# # ## Script
# # ```bash id="secgate1"



# #!/bin/bash

# set -e

# echo "🔍 Running Security Gate Aggregation..."

# # -----------------------------
# # Load results
# # -----------------------------

# GITLEAKS_FILE="gitleaks-report.json"
# SONAR_FILE="sonar-report.json"
# TRIVY_FILE="trivy-report.json"
# CHECKOV_FILE="checkov-report.json"

# # -----------------------------
# # GITLEAKS (hard fail)
# # -----------------------------
# GITLEAKS_COUNT=$(jq '. | length' $GITLEAKS_FILE 2>/dev/null || echo 0)

# # -----------------------------
# # SONAR (critical/blocker only)
# # -----------------------------
# SONAR_COUNT=$(jq '[.issues[] | select(.severity=="CRITICAL" or .severity=="BLOCKER")] | length' $SONAR_FILE)

# # -----------------------------
# # TRIVY (HIGH + CRITICAL)
# # -----------------------------
# TRIVY_COUNT=$(jq '[.Results[].Vulnerabilities[]? | select(.Severity=="CRITICAL" or .Severity=="HIGH")] | length' $TRIVY_FILE)

# # -----------------------------
# # CHECKOV (failed checks)
# # -----------------------------
# CHECKOV_COUNT=$(jq '.summary.failed // 0' $CHECKOV_FILE)

# # -----------------------------
# # Summary
# # -----------------------------
# echo "=========================="
# echo "SECURITY GATE SUMMARY"
# echo "=========================="
# echo "Secrets (Gitleaks): $GITLEAKS_COUNT"
# echo "SAST (Sonar): $SONAR_COUNT"
# echo "Container (Trivy): $TRIVY_COUNT"
# echo "IaC (Checkov): $CHECKOV_COUNT"
# echo "=========================="

# TOTAL=$((GITLEAKS_COUNT + SONAR_COUNT + TRIVY_COUNT + CHECKOV_COUNT))

# # -----------------------------
# # Decision
# # -----------------------------
# if [ "$TOTAL" -gt 0 ]; then
#   echo "❌ SECURITY GATE FAILED"
#   exit 1
# else
#   echo "✅ SECURITY GATE PASSED"
# fi






# ### Optional: Post a comment on the PR with the results (if running in GitHub Actions)
# ### This requires the `gh` CLI tool and appropriate permissions.
# if [ -n "$GITHUB_EVENT_NAME" ]; then
#   gh pr comment "$PR_NUMBER" -b "
# ## 🔐 Security Gate Report

# - Gitleaks: $GITLEAKS_COUNT
# - SonarCloud Critical: $SONAR_COUNT
# - Trivy: $TRIVY_COUNT
# - Checkov: $CHECKOV_COUNT

# ### Status: $([ "$TOTAL" -gt 0 ] && echo "❌ FAILED" || echo "✅ PASSED")
# "
# fi