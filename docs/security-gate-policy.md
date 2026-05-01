# Security Gate Policy

## 1. Overview

This document defines the security scanning ownership model, enforcement rules, and exception handling process for the SecureFlow CI/CD pipeline.

The goal is to ensure consistent enforcement of security controls across:
- application code
- infrastructure-as-code
- container images
- Kubernetes manifests

---

## 2. Ownership Matrix

| Scanner | Tool | Owned By | Purpose |
|--------|------|----------|--------|
| Secrets Detection | Gitleaks | DevSecOps | Detect exposed credentials, API keys |
| SAST | SonarCloud | AppSec | Code vulnerabilities and logic flaws |
| Container CVEs | Trivy (image scan) | DevSecOps | OS/package vulnerabilities in containers |
| Kubernetes Misconfig | Trivy (config) | DevSecOps | Kubernetes security posture |
| Terraform Misconfig | Checkov | DevSecOps | IaC policy and cloud misconfigurations |

---

## 3. Enforcement Model

### 3.1 Hard-Fail Rules (Build fails immediately)

These issues block pull requests and deployments:

- Any secrets detected (Gitleaks)
- ANY CRITICAL or BLOCKER vulnerabilities (SonarCloud)
- HIGH or CRITICAL CVEs (Trivy image scan)
- ANY failed Checkov check (Terraform misconfiguration)
- ANY CRITICAL or HIGH Kubernetes misconfiguration (Trivy config)

---

### 3.2 Soft-Fail Rules (reported but do not block build)

- SonarCloud: MAJOR / MINOR issues
- Trivy: LOW severity CVEs
- Code smells or maintainability issues
- Non-critical Terraform best-practice warnings

---

## 4. Exception Handling Process

Exceptions are only allowed when:

- Fix requires architectural change
- False positive confirmed by AppSec
- Risk is explicitly accepted

### Exception Workflow

1. Developer opens **Security Exception Request**
2. AppSec reviews within SLA (48–72 hours)
3. Decision recorded:
   - Approved exception (time-bound)
   - Rejected (must fix)
4. Exception documented in:
   - `security-exceptions.json`
   - PR comment

### Exception Format

```json
{
  "id": "SEC-123",
  "scanner": "trivy",
  "severity": "HIGH",
  "resource": "python:3.9-slim",
  "reason": "False positive due to patched base image",
  "approved_by": "appsec-team",
  "expiry": "2026-12-31"
}