# SecureFlow — Vulnerable Banking Platform

> **This is an INTENTIONALLY INSECURE baseline.**
> Do not deploy to a real cloud account. Run only in an isolated lab or local
> Kubernetes cluster (kind, k3s, minikube).

This repository is the "before" state for the SecureFlow DevSecOps case study.
Your job is to build the security pipeline, remediations, policy enforcement,
secrets management, runtime monitoring, and observability described in the
project brief. What you fork is broken on purpose — every vulnerability listed
in [`VULNERABILITIES.md`](./VULNERABILITIES.md) is real and exploitable.

Read the project brief PDF end-to-end before you touch any code.

---

## Architecture

```
                     ┌────────────────────┐
                     │     frontend       │  Flask + Jinja2 on :5000
                     │  (server-rendered) │
                     └──────┬───────┬─────┘
                            │       │
                 calls       │       │  calls
                            ▼       ▼
            ┌─────────────────┐  ┌──────────────────────┐
            │  auth-service   │  │ transaction-service  │
            │   Flask :5001   │  │    Flask :5002       │
            └────────┬────────┘  └──────────┬───────────┘
                     │                      │
                     ▼                      ▼
              ┌────────────┐          ┌────────────────┐
              │  auth-db   │          │ transaction-db │
              │ postgres   │          │   postgres     │
              └────────────┘          └────────────────┘
```

Three Python/Flask services, two independent PostgreSQL instances, microservices
pattern. Each service has its own database so that per-service Vault policies
(Step 14 of the brief) are meaningful — compromising one service does not grant
access to another service's data.

---

## Quick Start — Docker Compose

```bash
docker-compose up --build

# Services are then available at:
#   frontend              http://localhost:5000
#   auth-service API      http://localhost:5001
#   transaction-service   http://localhost:5002
#   auth-db               localhost:5432
#   transaction-db        localhost:5433
```

Seed users (the password hashes are MD5 — weak on purpose, see AV-05):

| Username | Password   | Role  |
|----------|-----------|-------|
| admin    | admin123  | admin |
| alice    | alice123  | user  |
| bob      | bob123    | user  |

---

## Quick Start — Kubernetes (base manifests)

```bash
kubectl apply -k infra/kubernetes/base

# Everything will apply because there is no admission controller in the way.
# That is the point. One of your tasks is to install OPA Gatekeeper and watch
# the base manifests get rejected.

kubectl get pods -n secureflow -w
```

---

## Example Exploits

Once the stack is running, these should all succeed against the baseline:

```bash
BASE=http://localhost:5001

# AV-01 — SQL injection auth bypass. Logs in as admin with no password.
curl -s -X POST $BASE/login \
  -H 'Content-Type: application/json' \
  -d '{"username": "admin'\''--", "password": "anything"}'

# Save the token from the response, then:
TOKEN=<paste token here>

# TV-01 — IDOR. Read admin's balance from alice's account.
curl -s http://localhost:5002/balance/1 \
  -H "Authorization: Bearer $TOKEN"

# TV-03 — Negative transfer. Drains the recipient.
curl -s -X POST http://localhost:5002/transfer \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"from_account": 2, "to_account": 3, "amount": -500}'

# FV-01 — Reflected XSS via query string.
# Open in browser after logging in as alice:
#   http://localhost:5000/dashboard?msg=<script>alert(document.cookie)</script>
```

---

## What's In This Repository

```
secureflow/
├── .env                              ← IV-04: committed on purpose, 5 secrets
├── docker-compose.yml                ← IV-01/02/03/06/07 + CK-03
├── .gitignore                        ← deliberately does not exclude .env
├── README.md                         ← this file
├── VULNERABILITIES.md                ← the full index keyed to the PDF
├── services/
│   ├── auth-service/                 ← AV-01..AV-08
│   ├── transaction-service/          ← TV-01..TV-07
│   └── frontend/                     ← FV-01..FV-07 (except FV-04)
├── db/
│   ├── auth/init.sql                 ← users schema + seed
│   └── transaction/init.sql          ← accounts, transactions, cards + seed
└── infra/
    ├── kubernetes/base/              ← CK-02..CK-09
    └── terraform/                    ← IV-08, IV-09, IV-10 + the modules Checkov will scan
```

---

## What's NOT In This Repository

Everything in this list is your job to build, based on the project brief:

- `.github/workflows/*` — the GitHub Actions pipeline
- `.gitleaks.toml` — custom Gitleaks rules for Flask/JWT/DB patterns
- `sonar-project.properties` — SonarQube configuration
- `pipeline/scripts/security-gate.sh` — the aggregation script
- Cosign keys and signing workflow
- OPA Gatekeeper ConstraintTemplates and Constraints
- Falco custom rules
- HashiCorp Vault policies, roles, and Agent Injector annotations
- Kubernetes NetworkPolicies
- Hardened Kustomize overlays (the `base/` here is the broken version)
- Prometheus configuration and Grafana dashboards
- OWASP ZAP scan configuration

If you find yourself adding a file and wondering whether it belongs in the
baseline or the solution — it's in the solution. The baseline is broken; you
are what fixes it.

---

## Success Criteria

See Section 9 of the project brief. At the end of two weeks the expected
artefacts include a green 7-stage pipeline, zero committed secrets, zero
CRITICAL CVEs in any service image, zero CRITICAL Checkov findings, zero OPA
Gatekeeper violations, all application exploits in this README returning
400/403, Vault-injected secrets, Falco alerts triggering on intentional test
events, and signed images with SBOM attestations.

---

## Safety Notes

- Do not `terraform apply` the infrastructure module against a real AWS account.
  The IAM policies use `AdministratorAccess` and the RDS instances are publicly
  accessible. Checkov is supposed to catch that before it reaches AWS.
- The `.env` file contains canonical AWS example keys (`AKIAIOSFODNN7EXAMPLE`).
  They are not live credentials but they will trip every secret scanner you
  point at the repo — which is the exercise.
- When you rotate and remove secrets during remediation, remember that deleting
  a file in a later commit does **not** remove the secret from git history. See
  §4.1 of the brief.
# SecureFlow

**A deliberately vulnerable banking application, hardened end-to-end using enterprise-grade DevSecOps practices.**

SecureFlow demonstrates how security controls are designed, automated, and integrated across the full software delivery lifecycle: from secret management and container hardening through to runtime threat detection, infrastructure security, and continuous security observability. It is built as a portfolio project that reflects the practices a production financial services platform would require.

---

## Branch Structure

| Branch | Purpose |
|---|---|
| `main` | Deliberately vulnerable baseline. Intentional misconfigurations, hardcoded secrets, root containers, and security anti-patterns as the starting point for remediation. |
| `devsecops-kenn` | All implementations and remediations live here. Vault integration, hardened containers, CI security gate, Falco rules, Terraform fixes, Grafana dashboards, and everything else documented in this README. |

> **If you are reviewing the DevSecOps implementation, check out `devsecops-kenn`.**

```bash
git checkout devsecops-kenn
```

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Application Architecture](#2-application-architecture)
3. [Security Architecture](#3-security-architecture)
4. [Vulnerability Landscape](#4-vulnerability-landscape)
5. [Phase 1: Secret Management with HashiCorp Vault](#5-phase-1-secret-management-with-hashicorp-vault)
6. [Phase 2: Container Hardening](#6-phase-2-container-hardening)
7. [Phase 3: Kubernetes Hardening](#7-phase-3-kubernetes-hardening)
8. [Phase 4: Runtime Security with Falco](#8-phase-4-runtime-security-with-falco)
9. [Phase 5: Terraform IaC Remediation](#9-phase-5-terraform-iac-remediation)
10. [Phase 6: CI/CD Security Gate](#10-phase-6-cicd-security-gate)
11. [Phase 7: Security Observability](#11-phase-7-security-observability)
12. [Phase 8: DAST with OWASP ZAP](#12-phase-8-dast-with-owasp-zap)
13. [AWS EKS Production Equivalent](#13-aws-eks-production-equivalent)
14. [Repository Structure](#14-repository-structure)
15. [Local Setup](#15-local-setup)
16. [Key Architectural Decisions](#16-key-architectural-decisions)
17. [Lessons Learned](#17-lessons-learned)
18. [Conclusion and Future Improvements](#18-conclusion-and-future-improvements)
19. [Troubleshooting Reference](#19-troubleshooting-reference)
20. [Technology Stack](#20-technology-stack)
21. [Documentation Index](#21-documentation-index)

---

## 1. Project Overview

SecureFlow simulates a real banking platform built from three Python Flask microservices and two PostgreSQL databases, deployed on Kubernetes. The `main` branch ships with textbook security failures: hardcoded secrets, containers running as root, no network isolation between services, outdated vulnerable dependencies, wildcard IAM permissions, and zero runtime visibility after deployment.

The `devsecops-kenn` branch documents the complete remediation journey, implementing the controls a production financial services platform would require. Every control is version-controlled, automated, and enforced through the CI/CD pipeline so security is verified on every push rather than checked manually.

### What This Project Demonstrates

- Shift-left security: vulnerabilities caught at commit time, not in production
- Defence-in-depth: four independent security layers operating at different stages
- Differentiated gate governance: separating DevSecOps-owned blocking controls from AppSec-owned non-blocking controls
- Security as code: every control defined in version-controlled manifests, Helm values, and pipeline YAML
- Security observability: posture measured, visualised, and alerted on continuously

### Security Posture Change

| Dimension | Before | After |
|---|---|---|
| Secrets | Hardcoded in source files, ConfigMaps, and docker-compose | Vault KV v2, injected as files at pod runtime |
| Containers | Root user; no capability drops; mutable image tags | Non-root; all capabilities dropped; digest-pinned images |
| Network | No isolation between services | Default-deny NetworkPolicies with explicit whitelists |
| Runtime detection | None | Falco with 5 custom MITRE ATT&CK-mapped rules |
| CI security | None | 7-stage gate with 5 scanners and differentiated ownership |
| Infrastructure | Public subnets; wildcard IAM; unencrypted S3 | Private subnets; least-privilege IAM; KMS encryption |
| Observability | None | Prometheus, Grafana, and Alertmanager with 8-panel dashboard |

---

## 2. Application Architecture

```
namespace: secureflow
+------------------------------------------------------------------+
|                                                                  |
|  +--------------+     +--------------+     +------------------+ |
|  |   frontend   |---->| auth-service |     | transaction-svc  | |
|  |  Flask :5000 |     |  Flask :5001 |     |   Flask :5002    | |
|  |  (2/2 pods)  |---->|  (2/2 pods)  |     |   (2/2 pods)     | |
|  +--------------+     +------+-------+     +--------+---------+ |
|                               |                     |           |
|                        +------v-------+    +---------v--------+ |
|                        |   auth-db    |    | transaction-db   | |
|                        | Postgres:5432|    |  Postgres:5432   | |
|                        +--------------+    +------------------+ |
+------------------------------------------------------------------+

Each application pod = 2 containers: app container + vault-agent sidecar
Each application pod initialises with: vault-agent-init (init container)
```

### Services

| Service | Port | Responsibility |
|---|---|---|
| frontend | 5000 | User interface; session management; orchestrates API calls to backend services |
| auth-service | 5001 | User registration; login; JWT issuance and validation |
| transaction-service | 5002 | Balance queries; fund transfer processing |
| auth-db | 5432 | PostgreSQL database exclusive to auth-service |
| transaction-db | 5432 | PostgreSQL database exclusive to transaction-service |

---

## 3. Security Architecture

```
Kubernetes Cluster
+----------------------------------------------------------------------+
|                                                                      |
| ns:vault          ns:secureflow        ns:falco     ns:monitoring   |
| +----------+      +--------------+    +----------+  +------------+  |
| | Vault HA |----->| App Services |<---| Falco    |  | Prometheus |  |
| | 3 replicas|     | + databases  |    | DaemonSet|  | Grafana    |  |
| | Raft+KMS |     | NetworkPols  |    |          |  | Alertmgr   |  |
| +----------+      +--------------+    +----+-----+  +-----^------+  |
|                                            |               |        |
|                                       alerts|        scrapes|        |
|                                            v               |        |
|                                      Falco Exporter -> Pushgateway  |
+----------------------------------------------------------------------+

GitHub Actions Pipeline
  Gitleaks      --->  BLOCKING (DevSecOps)
  Trivy Image   --->  BLOCKING (DevSecOps)
  Trivy K8s     --->  BLOCKING (DevSecOps)
  Checkov       --->  BLOCKING (DevSecOps)
  SonarCloud    --->  non-blocking (AppSec)
  OWASP ZAP     --->  non-blocking (AppSec)
```

### Four Layers of Defence

| Layer | Controls | When It Operates |
|---|---|---|
| Secret Management | Vault KV v2; per-service least-privilege policies; Agent Injector | Pre-runtime: secrets injected at pod startup |
| Container Security | Non-root user; dropped capabilities; read-only filesystem; CVE-free images; Cosign signing | Build time and deployment time |
| Kubernetes Runtime | Default-deny NetworkPolicies; security contexts; resource limits; Pod Security Standards | Admission time and runtime |
| Threat Detection | Falco DaemonSet; 5 custom MITRE ATT&CK rules; Prometheus metrics; Alertmanager routing | Continuous runtime monitoring |

---

## 4. Vulnerability Landscape

The following vulnerabilities exist intentionally in `main` and are addressed in `devsecops-kenn`.

### DevSecOps-Owned (Blocking in CI Gate)

| ID | Description | Remediation |
|---|---|---|
| IV-01 | Hardcoded DB passwords in docker-compose and Terraform | Vault KV v2; Terraform sensitive variable with no default |
| IV-03 | Secrets injected as environment variables | Vault Agent file injection to `/vault/secrets/config` |
| IV-08 | AdministratorAccess IAM policy and wildcard inline policy on EKS nodes | Scoped to 3 minimum EKS policies; specific resource ARNs on app policy |
| IV-09 | S3 bucket unencrypted; versioning disabled; public access enabled | KMS encryption; versioning enabled; all public access blocked; access logging |
| IV-10 | EKS nodes in public subnets; public API endpoint; RDS publicly accessible | Private subnets with NAT gateway; private endpoint only; RDS in private subnet |
| CK-01 | Vulnerable base image `python:3.9-slim` with multiple HIGH/CRITICAL CVEs | Upgraded to `python:3.12-slim` with package upgrades |
| CK-02 | All containers running as root (uid 0) | Non-root user `app` at uid 1000; `runAsNonRoot: true` |
| CK-03 | Postgres using mutable image tag that can change silently | Digest-pinned: `postgres:14@sha256:...` |
| CK-04 | Privileged containers with `allowPrivilegeEscalation: true` | `privileged: false`; `allowPrivilegeEscalation: false`; `capabilities.drop: [ALL]` |
| CK-05 | No CPU or memory resource limits on any container | Requests and limits defined on all containers and databases |
| CK-09 | JWT secret and DB passwords in plaintext ConfigMap | All runtime secrets moved to Vault; ConfigMap contains only non-sensitive URLs |

### AppSec-Owned (Non-Blocking; Routed to AppSec Intake)

| ID | Description | Detection Method |
|---|---|---|
| AV-01/02 | SQL Injection on login and registration endpoints | SonarCloud SAST; ZAP DAST |
| AV-07 | Hardcoded JWT signing secret | Gitleaks (secret rotated to Vault) |
| FV-01/02 | Reflected and Stored XSS in frontend templates | SonarCloud SAST; ZAP DAST |
| FV-05 | No CSRF tokens on state-changing forms | ZAP baseline scan |
| FV-06 | Missing X-Frame-Options header (clickjacking risk) | ZAP baseline scan |
| FV-07 | Content Security Policy header not set | ZAP baseline scan |
| TV-01/02 | IDOR: any authenticated user can access any account's data | SonarCloud SAST |

> AppSec-owned findings are **intentional by design**. They demonstrate that the CI gate correctly surfaces and routes them to AppSec review without blocking engineering work on non-security features.

---

## 5. Phase 1: Secret Management with HashiCorp Vault

### Problem

All sensitive values (database passwords, JWT signing keys, session secrets) were hardcoded in source files, docker-compose environment blocks, and Kubernetes ConfigMaps. They were committed to git, visible in `kubectl describe`, and stored in etcd in plaintext.

### Solution Architecture

```
Pod starts
  |
  v
vault-agent-init (init container)
  |  Authenticates to Vault using the pod's ServiceAccount token
  |  Reads secret from secureflow/data/<service-name>
  |  Writes credentials to /vault/secrets/config on a tmpfs volume
  v
App container starts
  |  vault_config.py reads /vault/secrets/config
  |  Loads values into os.environ at startup
  v
vault-agent (sidecar)
     Renews token and refreshes secrets for the pod's lifetime
```

### Vault Secret Paths

```
Vault KV v2, mounted at: secureflow/

secureflow/auth-service        db_host, db_port, db_name, db_user, db_password, jwt_secret
secureflow/transaction-service db_host, db_port, db_name, db_user, db_password, auth_service_url
secureflow/frontend            session_secret, auth_service_url, transaction_service_url
```

### Per-Service Least-Privilege Policy

Each service has its own Vault policy that grants read access only to its own secret path:

```hcl
# auth-service-policy
path "secureflow/data/auth-service" {
  capabilities = ["read"]
}
# auth-service cannot read transaction-service or frontend secrets
```

### Kubernetes Auth Role

```bash
vault write auth/kubernetes/role/auth-service-role \
  bound_service_account_names=auth-service-sa \
  bound_service_account_namespaces=secureflow \
  policies=auth-service-policy \
  ttl=1h
```

### Dev Mode vs Production Mode

| Concern | kind (local) | AWS EKS (production) |
|---|---|---|
| Storage | In-memory; state lost on pod restart | Raft on EBS gp3; permanent across restarts |
| Unseal | Automatic (dev mode) | AWS KMS auto-unseal |
| Initialisation | Not required | One-time `vault operator init` |
| Root token | Hardcoded `root` | Generated at init; stored in AWS Secrets Manager |
| High availability | Not supported | 3 replicas with Raft consensus |
| Audit logging | None | File audit log on persistent EBS volume |

Re-initialisation script for dev mode after cluster restart: `scripts/vault-init.sh`

---

## 6. Phase 2: Container Hardening

### Dockerfile Changes

```dockerfile
# BEFORE
FROM python:3.9-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
CMD ["python", "app.py"]
# Runs as root; no USER directive; no HEALTHCHECK

# AFTER
FROM python:3.12-slim
WORKDIR /app
RUN apt-get update && apt-get upgrade -y --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*
COPY requirements.txt .
RUN pip install -r requirements.txt
RUN groupadd --system app && useradd --system --gid app --no-create-home app
COPY --chown=app:app . .
USER app
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:${PORT}/health')"
CMD ["python", "app.py"]
```

Note: `groupadd` and `useradd` are Debian syntax (used by `python:3.12-slim`). Alpine uses `addgroup` and `adduser` with different flags; they are not interchangeable.

### Package Upgrades That Fixed CVEs

| Package | Before | After | Reason |
|---|---|---|---|
| Base image | `python:3.9-slim` | `python:3.12-slim` | Multiple HIGH/CRITICAL OS-level CVEs |
| PyJWT | 2.8.0 | 2.12.0 | CVE remediation |
| Werkzeug | 2.3.7 | 3.0.3 | HIGH CVE remediation |
| psycopg2-binary | 2.9.5 | 2.9.9 | 2.9.5 has no pre-built wheel for Python 3.12; 2.9.9 ships a binary wheel, avoiding compilation against `pg_config` |

### CVE Reduction Results

| Severity | Before | After |
|---|---|---|
| CRITICAL | 8 | 0 |
| HIGH | 28 | 0 |
| MEDIUM | 14 | 3 (accepted; documented in `.trivyignore`) |

### Kubernetes Security Context

Applied to every application container:

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
  capabilities:
    drop: [ALL]
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 256Mi
```

**Postgres exception:** `readOnlyRootFilesystem: false` because PostgreSQL requires write access for WAL (Write-Ahead Log) files. This exception is documented in `.trivyignore` with justification, using both `KSV014` and `KSV-0014` ID formats because Trivy changed its naming convention between versions. `runAsUser: 999` matches the official Postgres image UID.

### Image Signing with Cosign

```bash
# Sign the image (run from WSL2 Ubuntu; PowerShell has no TTY for the key password prompt)
cosign sign --key cosign.key secureflow/auth-service:latest

# Verify the signature
cosign verify --key cosign.pub secureflow/auth-service:latest
```

On EKS: images are pushed to ECR, signed with Cosign, and referenced by SHA256 digest in the Kustomize overlay. On kind: `imagePullPolicy: Never` combined with `kind load docker-image` is required because kind nodes cannot reach a registry running at `localhost` on the host machine.

---

## 7. Phase 3: Kubernetes Hardening

### Kustomize Structure

```
infra/kubernetes/
  base/
    deployments.yaml           App service deployments with Vault annotations and security contexts
    services.yaml              ClusterIP services for all pods
    databases.yaml             Postgres StatefulSets with hardened security contexts
    configmap.yaml             Non-sensitive configuration only (URLs, port numbers)
    network-policies.yaml      Default-deny ingress/egress + explicit whitelists
    vault-agent-templates.yaml Vault Agent annotation templates
  overlays/
    dev/
      kustomization.yaml       Applies labels, image overrides, and imagePullPolicy patch
```

**Deploy to the cluster:**

```bash
kubectl apply -k infra/kubernetes/overlays/dev/
```

### NetworkPolicies

All policies are defined in `infra/kubernetes/base/network-policies.yaml`.

```
Default rule: DENY ALL ingress and egress for namespace secureflow

Explicit allowlists:
  frontend          --> auth-service:5001         ALLOW
  frontend          --> transaction-service:5002   ALLOW
  auth-service      --> auth-db:5432               ALLOW
  transaction-svc   --> transaction-db:5432         ALLOW
  all secureflow    --> vault namespace:8200        ALLOW (Vault Agent sidecar)
  all secureflow    --> kube-dns:53                 ALLOW (DNS resolution)
```

A compromised auth-service container cannot reach the transaction database or frontend, even within the same cluster. Lateral movement is prevented at the network layer.

### Kustomize Overlay

The dev overlay applies environment-specific configuration without touching base manifests:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: secureflow
resources:
  - ../../base
labels:
  - pairs:
      app: secureflow
      team: devsecops
      environment: dev
    includeSelectors: false
    includeTemplates: true
images:
  - name: secureflow/auth-service
    newTag: latest
    # On EKS this becomes: newDigest: sha256:abc123...
patches:
  - target:
      kind: Deployment
    patch: |-
      - op: replace
        path: /spec/template/spec/containers/0/imagePullPolicy
        value: Never
```

---

## 8. Phase 4: Runtime Security with Falco

### What Falco Does

Falco runs as a DaemonSet (one pod per node) and intercepts Linux syscalls using eBPF. When a container performs a syscall matching a rule, Falco generates an alert. Unlike admission controllers (which prevent bad resources from being created) and image scanners (which identify vulnerabilities at build time), Falco detects malicious behaviour as it happens, after the pod is running.

### Custom Rules

Five custom rules in `infra/kubernetes/falco/secureflow-rules.yaml`, each mapped to a MITRE ATT&CK technique:

| Rule | Priority | MITRE Technique | Trigger Condition |
|---|---|---|---|
| Shell Spawned in SecureFlow Container | WARNING | T1059 | Any shell process (sh, bash, dash) spawned in a secureflow pod |
| Sensitive File Read in SecureFlow Container | CRITICAL | T1083 | Read of `/etc/shadow` or `/etc/passwd` inside a pod |
| Package Manager Executed in SecureFlow Container | ERROR | T1072 | `apt-get`, `pip`, or `npm` executed inside a pod |
| Unexpected Outbound Connection | WARNING | T1071 | Outbound TCP to a port not in the allowlist (53, 80, 443, 5001, 5002, 5432, 8200) |
| Vault Secrets Accessed by Unexpected Process | CRITICAL | T1552 | Any process other than `python3` or `vault` reads `/vault/secrets/` |

### Demonstrating the Rules

```bash
# Trigger 1: Shell spawn; fires WARNING alert
kubectl exec -n secureflow deployment/auth-service -- id

# Trigger 2: Sensitive file read; fires CRITICAL alert
kubectl exec -n secureflow deployment/auth-service -- cat /etc/passwd

# Trigger 3: Package manager; blocked before Falco fires
# readOnlyRootFilesystem: true prevents apt-get from writing to /var/lib/dpkg
# Both controls operate simultaneously; this is defence-in-depth in action
kubectl exec -n secureflow deployment/auth-service -- apt-get install curl
```

### Important Falco Syntax Notes

```yaml
# The rfc_1918_addresses macro does NOT exist in Falco
# The startswith operator is NOT supported for IP address fields (fd.sip)
# Use a port-based allowlist instead:

condition: >
  spawned_process
  and container.image.repository contains "secureflow"
  and not fd.sport in (53, 80, 443, 5001, 5002, 5432, 8200)
```

### gRPC Configuration Note

```yaml
# The grpcOutput key was deprecated and removed in Falco 0.43.x
# Including it causes a schema validation crash at startup
# Remove it entirely; gRPC behaviour is controlled by grpc.enabled

falco:
  grpc:
    enabled: true
    bindAddress: "unix:///var/run/falco/falco.sock"
    threadiness: 8
  # grpcOutput key removed entirely
```

### WSL2 Limitation

On WSL2, the Falco exporter connects to the gRPC socket and logs `ready`, but the Microsoft custom kernel restricts certain eBPF program types so `falco_events_total` Prometheus metrics are not populated. Alerts are confirmed via `kubectl logs -n falco daemonset/falco -c falco`. On AWS EKS with standard Linux kernels, all five rules generate real Prometheus metrics with no workaround required.

---

## 9. Phase 5: Terraform IaC Remediation

All fixes are in `infra/terraform/`. The pipeline runs `bridgecrewio/checkov-action@v12` with `check: CRITICAL`. Result: **0 CRITICAL findings**.

### IV-01: Hardcoded Database Password

```hcl
# BEFORE
variable "db_password" {
  default = "supersecretpassword123"
}

# AFTER
variable "db_password" {
  description = "RDS master password; passed via TF_VAR_db_password environment variable"
  type        = string
  sensitive   = true
  # No default; Terraform errors if not provided at plan/apply time
}
```

### IV-08: Wildcard IAM Permissions

```hcl
# BEFORE: AdministratorAccess on node role + Action:* inline policy

# AFTER: minimum required policies only
resource "aws_iam_role_policy_attachment" "eks_worker_node" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}
resource "aws_iam_role_policy_attachment" "eks_cni" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}
resource "aws_iam_role_policy_attachment" "eks_ecr_read" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# App inline policy scoped to specific resource ARN pattern
resource "aws_iam_role_policy" "app_secrets" {
  policy = jsonencode({
    Statement = [{
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = "arn:aws:secretsmanager:*:*:secret:secureflow/*"
      Effect   = "Allow"
    }]
  })
}
```

### IV-09: S3 Security

```hcl
# AFTER: encryption, versioning, public access blocked, and access logging
resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}
```

### IV-10: Network Exposure

```hcl
# AFTER: private subnets, private endpoint, encrypted RDS
module "eks" {
  subnet_ids              = module.vpc.private_subnets  # was public_subnets
  endpoint_public_access  = false                        # was true
  endpoint_private_access = true
  secrets_encryption_key_arn = var.kms_key_arn
}

resource "aws_db_instance" "main" {
  publicly_accessible  = false   # was true
  storage_encrypted    = true
  kms_key_id           = var.kms_key_arn
  db_subnet_group_name = aws_db_subnet_group.private.name
}
```

---

## 10. Phase 6: CI/CD Security Gate

### Pipeline Structure

All jobs run in parallel. The `security-gate` job waits for all scanners to complete before aggregating results and enforcing the gate decision.

```yaml
# .github/workflows/devsecops-pipeline.yaml
jobs:
  gitleaks-scan:      # Secret detection in codebase; BLOCKING
  sonarcloud-scan:    # SAST code analysis; non-blocking (AppSec-owned)
  trivy-scan:         # Container CVE scanning across all 3 service images; BLOCKING
  trivy-k8s-scan:     # Kubernetes manifest misconfiguration scan; BLOCKING
  checkov-scan:       # Terraform IaC CRITICAL findings; BLOCKING
  security-gate:      # Aggregates results; posts PR comment; enforces gate
    needs: [gitleaks-scan, sonarcloud-scan, trivy-scan, trivy-k8s-scan, checkov-scan]
  push-metrics:       # Pushes scanner counts to Prometheus Pushgateway
    needs: [security-gate]
```

### Differentiated Gate Model

The core principle is that different controls require different enforcement because different teams own them.

```bash
# DevSecOps-owned controls: automated, deterministic, immediately actionable
DEVSECOPS_TOTAL=$((GITLEAKS_COUNT + TRIVY_COUNT + TRIVY_K8S_COUNT + CHECKOV_COUNT))

if [ "$DEVSECOPS_TOTAL" -gt 0 ]; then
  echo "GATE FAILED: $DEVSECOPS_TOTAL blocking finding(s)"
  exit 1
fi

# AppSec-owned controls: visible in PR comment; never block the merge
echo "AppSec findings (non-blocking): SonarCloud=$SONAR_COUNT, ZAP=$ZAP_COUNT"
echo "Routed to AppSec review; no action required to merge"
exit 0
```

### PR Comment Format

Every pipeline run posts a structured comment to the pull request:

```
## Security Gate Report

### DevSecOps-owned (BLOCKING)
| Scanner       | Findings |
|---------------|----------|
| Gitleaks      | 0        |
| Trivy (Image) | 0        |
| Trivy (K8s)   | 0        |
| Checkov       | 0        |

Total Blocking Issues: 0

### AppSec-owned (NON-BLOCKING)
| Scanner    | Findings |
|------------|----------|
| SonarCloud | 4        |
| OWASP ZAP  | 3        |

Routed to AppSec for review and intake.

Gate Status: PASSED
```

### Security Exception Workflow

When a blocking finding cannot be immediately remediated, engineers can request a time-bounded exception:

```
Step 1: Developer posts in PR comment:
  /security-exception reason="Unfixable OS CVE; vendor patch pending" expires="2026-07-01"

Step 2: Pipeline detects label: security-exception-requested

Step 3: Validates two conditions:
  EXCEPTION_VALID: expiry date has not passed
  APPROVED: PR carries the security-approved label

Step 4: Gate reports OVERRIDE instead of FAIL (soft pass)
        Expired exceptions never override the gate
```

### Suppression Files

**`.trivyignore`** documents every accepted suppression with justification:

```
# CVE-2026-4878: unfixable OS CVE; no upstream patch available
# Accepted risk; review date: 2026-08-01
CVE-2026-4878

# KSV014 / KSV-0014: Postgres readOnlyRootFilesystem exception
# Postgres requires write access for WAL files; architectural exception documented
# Both ID formats required; Trivy changed naming convention between versions
KSV014
KSV-0014

# AVD-KSV-0109: ConfigMap contains Postgres init credentials
# DB init credentials cannot use Vault because Postgres starts before vault-agent-init completes
AVD-KSV-0109
```

### Current Gate Status

| Scanner | Findings | Gate Result |
|---|---|---|
| Gitleaks | 0 | PASS |
| Trivy Image | 0 | PASS |
| Trivy K8s | 0 | PASS |
| Checkov | 0 | PASS |
| SonarCloud | 4 | NON-BLOCKING |
| OWASP ZAP | 3 MEDIUM | NON-BLOCKING |
| **Overall Gate** | | **PASSED** |

---

## 11. Phase 7: Security Observability

### Stack

Installed in the `monitoring` namespace via the `kube-prometheus-stack` Helm chart. Components:

- **Prometheus:** scrapes metrics from all targets; evaluates alert rules
- **Grafana:** visualises security posture; 8-panel provisioned dashboard
- **Alertmanager:** routes firing alerts to Slack, PagerDuty, or webhooks
- **Falco Exporter:** converts Falco alert events to `falco_events_total` Prometheus counter
- **Pushgateway:** receives metrics pushed from the CI pipeline after each run

### Why a Dedicated Monitoring Namespace?

Observability tooling is platform infrastructure, not application code. Separating it into its own namespace enforces RBAC boundaries, allows targeted NetworkPolicies, and mirrors the real-world team ownership model where SRE and platform teams own monitoring infrastructure independently of application teams.

### 8-Panel Security Dashboard

Provisioned as a Kubernetes ConfigMap with label `grafana_dashboard: "1"`. Grafana's sidecar container watches for ConfigMaps with this label and loads them automatically within 30 seconds; no manual dashboard import is required.

| Panel | Type | PromQL Query | Data Source |
|---|---|---|---|
| Security Gate Status | Stat (green/red) | `secureflow_gate_status` | Pushgateway |
| Gitleaks Findings Over Time | Time series | `secureflow_gitleaks_findings` | Pushgateway |
| Trivy Image CVE Count | Time series | `secureflow_trivy_image_findings` | Pushgateway |
| Trivy K8s Misconfiguration Count | Time series | `secureflow_trivy_k8s_findings` | Pushgateway |
| AppSec SonarCloud Findings | Time series | `secureflow_sonar_findings` | Pushgateway |
| Falco Alert Rate by Rule | Time series | `rate(falco_events_total[5m])` | Falco Exporter |
| Pod Security: Running Containers | Stat | `count(kube_pod_container_info{namespace="secureflow"})` | kube-state-metrics |
| Vault Unexpected Access Events | Time series | `increase(falco_events_total{rule="Vault Secrets Accessed by Unexpected Process"}[5m])` | Falco Exporter |

### Alert Rules

Six `PrometheusRule` alerts defined in `infra/kubernetes/monitoring/secureflow-alerts.yaml`:

| Alert Name | Severity | Fires When |
|---|---|---|
| SecureFlowGateFailed | critical | Gate has been failing for more than 1 minute |
| SecretsDetectedInCode | critical | Gitleaks detects any secret (fires immediately) |
| CriticalImageVulnerability | warning | Trivy finds a HIGH/CRITICAL CVE for more than 5 minutes |
| FalcoShellSpawnedInContainer | warning | Shell process detected in any secureflow pod (immediate) |
| FalcoSensitiveFileAccess | critical | `/etc/shadow` or `/etc/passwd` read inside a pod (immediate) |
| UnexpectedVaultSecretAccess | critical | Non-authorised process reads `/vault/secrets/` (immediate) |

The `for` duration on each alert is deliberate. Security events that are always urgent fire immediately (`for: 0m`). Gate failures use `for: 1m` to avoid noise from transient CI hiccups. CVE findings use `for: 5m` to allow the scan to fully complete before alerting.

### Accessing the Stack on kind

```bash
# Grafana (forward directly to the pod; service port-forward is unreliable on kind)
GRAFANA_POD=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana \
  -o jsonpath='{.items[0].metadata.name}')
kubectl port-forward -n monitoring pod/$GRAFANA_POD 3000:3000
# Open http://localhost:3000 with credentials: admin / secureflow-admin

# Prometheus
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Open http://localhost:9090

# Pushgateway
kubectl port-forward -n monitoring svc/prometheus-pushgateway 9091:9091
# Open http://localhost:9091
```

### CI Metrics Pipeline

After each pipeline run, the `push-metrics` job uploads `reports/metrics/pipeline-metrics.txt` as an artifact and pushes it to the Pushgateway if `PUSHGATEWAY_URL` is configured. This keeps Panels 1-5 on the Grafana dashboard current without any manual steps. Locally, `scripts/push-metrics.py` performs the same push against the port-forwarded Pushgateway.

---

## 12. Phase 8: DAST with OWASP ZAP

### Scan Command

```bash
docker run --rm \
  -v "$(pwd)/reports/zap:/zap/wrk" \
  -t ghcr.io/zaproxy/zaproxy:stable \
  zap-baseline.py \
  -t http://host.docker.internal:5000 \
  -r zap-report.html \
  -J zap-report.json \
  -I
```

### Results

| Severity | Count | Findings |
|---|---|---|
| HIGH | 0 | None |
| MEDIUM | 3 | Anti-CSRF Tokens (FV-05); CSP Header Not Set (FV-07); Missing Anti-clickjacking Header (FV-06) |
| LOW | 7 | Security header gaps; server version disclosure |
| Informational | 6 | Cache policies; authentication request identified |

All MEDIUM findings map directly to intentional `FV-xx` application vulnerabilities. ZAP is not wired into the CI pipeline for this project because there is no persistent staging deployment in the kind environment. It is deferred to the EKS implementation where a stable staging URL will be available. At that point, ZAP findings will appear in the AppSec non-blocking section of the PR comment.

---

## 13. AWS EKS Production Equivalent

The full EKS implementation guide is at [`README-eks-implementation-guide.md`](README-eks-implementation-guide.md). The guide covers all eight phases with EKS-specific commands, values files, and IAM configuration.

### Key Differences from kind

| Component | kind (local) | AWS EKS (production) |
|---|---|---|
| Cluster creation | `kind create cluster` | `eksctl create cluster` with private node groups |
| Image registry | `localhost:5001` with `kind load` | ECR with KMS encryption and scan-on-push |
| Vault storage | In-memory; lost on restart | Raft on EBS gp3; permanent |
| Vault unseal | Automatic (dev mode) | AWS KMS auto-unseal |
| Vault high availability | Not supported | 3 replicas with Raft consensus |
| Persistent storage | EmptyDir (lost on restart) | EBS gp3 PVC (survives indefinitely) |
| Grafana access | `kubectl port-forward` | Internal NLB; accessible only via VPN |
| Pushgateway access | Local port-forward only | Internal NLB; reachable from GitHub Actions |
| Falco eBPF events | WSL2 limited | Fully functional on standard Linux kernel |
| CI authentication | Direct kubectl | OIDC federation to IAM role; no stored credentials |
| Access control | None | AWS Client VPN with per-user certificates |
| TLS | None | ACM certificate on all internal NLBs |
| Cost | Free (local Docker) | Approximately £120-250/month for 3x t3.medium + RDS + NLBs |

### Internal Access Architecture

All dashboards and internal services are exposed via internal Network Load Balancers. These have private IP addresses only reachable from within the VPC. Authorised users connect through AWS Client VPN using per-user certificates:

```
Authorised user laptop
  |
  | AWS Client VPN (mutual TLS; per-user certificate)
  v
AWS VPC (private address space)
  |
  +-- grafana.internal.secureflow.com  --> Internal NLB (10.0.x.x)
  +-- vault.internal.secureflow.com   --> Internal NLB (10.0.x.x)
  +-- prometheus.internal.secureflow.com --> Internal NLB (10.0.x.x)

Public internet --> DNS resolves to 10.0.x.x --> unreachable
```

Revoking a user's access requires only revoking their VPN certificate. The VPN connection log provides a built-in audit trail of who accessed what and when.

---

## 14. Repository Structure

```
secureflow/
|
+-- services/
|   +-- auth-service/
|   |   +-- app.py                     Intentionally vulnerable Flask application
|   |   +-- vault_config.py            Reads /vault/secrets/config; loads into os.environ
|   |   +-- requirements.txt
|   |   +-- Dockerfile                 Hardened: python:3.12-slim; non-root; healthcheck
|   +-- transaction-service/           Same structure as auth-service
|   +-- frontend/                      Same structure as auth-service
|
+-- infra/
|   +-- kubernetes/
|   |   +-- base/
|   |   |   +-- deployments.yaml       Deployments with Vault annotations and security contexts
|   |   |   +-- services.yaml          ClusterIP services
|   |   |   +-- databases.yaml         Postgres with hardened security context
|   |   |   +-- configmap.yaml         Non-sensitive configuration only
|   |   |   +-- network-policies.yaml  Default-deny plus explicit whitelists
|   |   |   +-- vault-agent-templates.yaml
|   |   +-- overlays/
|   |   |   +-- dev/
|   |   |       +-- kustomization.yaml Labels; image pins; imagePullPolicy patch
|   |   +-- vault/
|   |   |   +-- values.yaml            Vault Helm values for kind (dev mode)
|   |   |   +-- values-eks.yaml        Vault Helm values for EKS (Raft + KMS)
|   |   +-- falco/
|   |   |   +-- values.yaml            Falco Helm values (modern_ebpf; gRPC enabled)
|   |   |   +-- secureflow-rules.yaml  5 custom MITRE ATT&CK rules
|   |   +-- monitoring/
|   |       +-- prometheus-values.yaml
|   |       +-- prometheus-values-eks.yaml
|   |       +-- grafana-security-dashboard.yaml   8-panel ConfigMap
|   |       +-- secureflow-alerts.yaml            6 PrometheusRule alerts
|   |       +-- falco-servicemonitor.yaml         ServiceMonitor for Falco Exporter
|   |       +-- pushgateway-service-eks.yaml      Internal NLB for EKS Pushgateway
|   +-- terraform/
|       +-- main.tf                    EKS cluster; VPC; RDS
|       +-- variables.tf               db_password as sensitive variable
|       +-- iam.tf                     Least-privilege node and app IAM roles
|       +-- s3.tf                      Encrypted; versioned; private S3
|       +-- backend.tf                 S3 and DynamoDB remote state
|
+-- pipeline/
|   +-- scripts/
|       +-- security-gate.sh           Gate logic; PR comment; metrics file output
|
+-- scripts/
|   +-- vault-init.sh                  Re-initialises Vault dev mode after cluster restart
|   +-- push-metrics.py               Pushes pipeline-metrics.txt to Pushgateway
|   +-- push-metrics.ps1              PowerShell wrapper for local metric pushes
|
+-- .github/
|   +-- workflows/
|       +-- devsecops-pipeline.yaml    7-stage parallel security pipeline
|
+-- reports/
|   +-- zap/
|       +-- zap-report.html
|       +-- zap-report.json
|
+-- cosign.pub                         Public key for image verification (private key never committed)
+-- .trivyignore                       Documented CVE and misconfiguration suppressions
+-- .gitleaks.toml                     Allowlists for intentional vulnerable baseline content
+-- docker-compose.yml                 Local dev without Kubernetes
+-- docker-compose.env.example         Example env file for local dev
```

---

## 15. Local Setup

### Prerequisites

```powershell
# Windows: install via winget or chocolatey
winget install Docker.DockerDesktop
winget install Kubernetes.kubectl
winget install Helm.Helm
choco install kind

# WSL2 Ubuntu: required for Cosign and any tool needing a proper TTY
wsl --install -d Ubuntu
```

### Cluster Setup

```powershell
kind create cluster --name secureflow --config infra/kind-config.yaml
kubectl get nodes
```

### Deploy Everything

```powershell
# 1. Add Helm repos
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# 2. Install Vault in dev mode
helm install vault hashicorp/vault --namespace vault --create-namespace `
  --set server.dev.enabled=true `
  --set server.dev.devRootToken="root" `
  --set injector.enabled=true

# 3. Initialise Vault (run once per cluster restart)
bash scripts/vault-init.sh

# 4. Build and load service images
docker build -t secureflow/auth-service:latest ./services/auth-service
docker build -t secureflow/transaction-service:latest ./services/transaction-service
docker build -t secureflow/frontend:latest ./services/frontend
kind load docker-image secureflow/auth-service:latest --name secureflow
kind load docker-image secureflow/transaction-service:latest --name secureflow
kind load docker-image secureflow/frontend:latest --name secureflow

# 5. Deploy the application
kubectl apply -k infra/kubernetes/overlays/dev/
kubectl get pods -n secureflow -w
# Wait for: all pods showing 2/2 Running (app container + vault-agent sidecar)

# 6. Install Falco
helm install falco falcosecurity/falco --namespace falco --create-namespace `
  --values infra/kubernetes/falco/values.yaml `
  --set-file customRules."secureflow-rules\.yaml"=infra/kubernetes/falco/secureflow-rules.yaml

# 7. Install monitoring stack
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack `
  --namespace monitoring --create-namespace `
  --values infra/kubernetes/monitoring/prometheus-values.yaml

kubectl apply -f infra/kubernetes/monitoring/grafana-security-dashboard.yaml
kubectl apply -f infra/kubernetes/monitoring/secureflow-alerts.yaml
kubectl apply -f infra/kubernetes/monitoring/falco-servicemonitor.yaml

helm install prometheus-pushgateway prometheus-community/prometheus-pushgateway `
  --namespace monitoring `
  --set serviceMonitor.enabled=true `
  --set "serviceMonitor.additionalLabels.release=kube-prometheus-stack"

# 8. Access the application
kubectl port-forward -n secureflow svc/frontend 5000:5000
# Open http://localhost:5000
```

### GitHub Actions Secrets Required

| Secret | Description |
|---|---|
| `SONAR_TOKEN` | SonarCloud project token |
| `SONAR_PROJECT_KEY` | SonarCloud project key |
| `COSIGN_PRIVATE_KEY` | Base64-encoded cosign.key |
| `COSIGN_PASSWORD` | Cosign key passphrase |
| `PUSHGATEWAY_URL` | Pushgateway endpoint; pipeline skips push gracefully if not set |

---

## 16. Key Architectural Decisions

### Vault Agent Injector over Secrets Store CSI Driver

The Agent Injector runs as a sidecar inside the pod and writes secrets to a tmpfs volume. The CSI driver mounts secrets as external volumes. The Injector was chosen because it provides automatic secret renewal for the full pod lifetime without requiring a container restart, and it integrates natively with Vault's Kubernetes auth method without introducing additional AWS dependencies.

### Differentiated Gate Governance

A single-threshold gate creates a false binary: either everything blocks or nothing does. The model implemented here reflects real team ownership. DevSecOps owns infrastructure controls (secrets, CVEs, IaC misconfigurations) and can act on findings immediately. AppSec owns application logic vulnerabilities (SQLi, XSS, IDOR) that require triage, context, and risk acceptance that no automated scanner can provide. Making AppSec findings blocking would hold every non-security pull request hostage to AppSec team capacity and sprint cycles.

### Port-Based Allowlist for Falco Outbound Rule

Falco's `fd.sip` IP address field does not support CIDR notation. The `rfc_1918_addresses` macro does not exist in the installed Falco version. The `startswith` string operator is not supported for IP fields. Port-based allowlisting was chosen as the alternative; it is also more stable than IP-based rules because internal service IPs are assigned dynamically by the CNI plugin and can change across restarts.

### Both KSV014 and KSV-0014 in .trivyignore

Trivy changed its check ID naming convention between releases: `KSV014` in older versions; `KSV-0014` (with hyphen and leading zero) in newer ones. The CI environment and local environment may run different Trivy versions. Adding both formats ensures the suppression works regardless of which version executes the scan.

### imagePullPolicy: Never on kind

kind runs cluster nodes as Docker containers. The `localhost` address inside a kind node refers to that node container, not the developer's host machine. A registry at `localhost:5001` on the host is unreachable from inside a kind node. `kind load docker-image` injects images directly into kind's containerd runtime, bypassing the registry problem entirely. On EKS, images are pulled normally from ECR.

### Python urllib.request for Pushgateway Metrics

PowerShell heredoc strings (`@" ... "@`) add Windows-style CRLF line endings. `Out-File -Encoding ascii` also produces CRLF. The Prometheus text format parser is strict: CRLF line endings cause an `unexpected end of input stream` parse error. Python's string literals and file handling produce LF line endings on all platforms, making it the reliable cross-platform choice for this task.

### grpcOutput Removed from Falco Values

`grpcOutput` was deprecated and removed from Falco's configuration schema in version 0.43.x. Including the key causes a YAML schema validation failure that crashes the Falco process at startup. The fix is to remove the key entirely; gRPC output behaviour is now controlled solely by `grpc.enabled`.

### Checkov via GitHub Actions Module, not pip CLI

The `checkov` CLI's `--check-severity` flag is a paid Bridgecrew platform feature requiring an API key. `bridgecrewio/checkov-action@v12` implements severity filtering internally without a paid account. The action also requires `sudo mv` and `sudo chmod 644` on its output files because it executes inside a Docker container as root, and the GitHub Actions runner user cannot move root-owned files without elevated permissions.

---

## 17. Lessons Learned

### Scan the Right Artifact

The Trivy stage originally scanned `python:3.9-slim` directly instead of the built service images. It appeared to work: it ran, produced a report, and fed the security gate. But it was measuring the wrong thing. The finding count dropped from 36 to 0 once corrected to scan the actual built images. A security scanner measuring the wrong artifact produces false assurance that is more dangerous than no scanner at all.

### Suppress With Justification, Not Convenience

Every entry in `.trivyignore` and `.gitleaks.toml` carries a documented reason, the associated CVE or check ID, and a review date comment. This is the difference between a team that understands its accepted risk posture and one that silences alerts to improve pipeline metrics. Suppressions without documentation are indistinguishable from negligence.

### Dev Mode Creates Operational Debt

Vault dev mode is efficient for rapid iteration but the state loss on every pod restart creates recurring pain. Running `vault-init.sh` repeatedly through the project made the production architecture (Raft plus KMS auto-unseal) feel necessary rather than over-engineered. The lesson: local shortcuts that require manual recovery should be scripted from day one, and the pain of that scripting is what makes the production solution feel justified.

### Platform Constraints Are Portfolio Strengths

The WSL2/Falco eBPF limitation could have been hidden by omitting any mention of it. Documenting it honestly with the root cause, confirmation via `kubectl logs`, and the production equivalent where the issue does not exist demonstrates deeper understanding than a project where everything works on ideal hardware. Reviewers and interviewers recognise the difference between someone who reasoned through a real constraint and someone who ran a tutorial on a cloud VM.

### Gate Ownership Is a Governance Decision, Not a Technical One

Deciding that Checkov belongs in the blocking DevSecOps gate rather than the AppSec non-blocking section required answering a team governance question: who owns infrastructure misconfiguration remediation? The answer (DevSecOps, because infrastructure misconfigurations are deployment-time risks) is a decision that should be documented and agreed upon explicitly. Undocumented governance decisions become tribal knowledge that disappears when people leave.

### Security Observability Closes the Feedback Loop

A Falco alert firing for a shell spawn inside a production container at 2am, routed through Alertmanager, and paging an on-call engineer is a materially different security posture than finding the same event in log files the following morning. The 8-panel Grafana dashboard represents 8 questions the platform can answer continuously and automatically, without anyone having to remember to check.

---

## 18. Conclusion and Future Improvements

SecureFlow began as a deliberately vulnerable banking application and was transformed, phase by phase, into a hardened, observable, and continuously verified security platform. Across eight implementation phases, the project covered the full DevSecOps lifecycle: secret management with HashiCorp Vault replacing hardcoded credentials; container hardening that eliminated all CRITICAL and HIGH CVEs; Kubernetes NetworkPolicies enforcing least-privilege network segmentation; Falco providing real-time runtime threat detection mapped to MITRE ATT&CK techniques; Terraform IaC remediation closing four critical infrastructure exposure classes; and a seven-stage CI security gate that enforces a differentiated governance model separating DevSecOps-owned blocking controls from AppSec-owned non-blocking ones. The entire implementation runs on a kind cluster on Windows 11, with a fully documented AWS EKS production equivalent covering KMS auto-unseal, ECR image signing, IRSA, internal NLBs, and AWS Client VPN for controlled access.

The most significant lessons came not from the tools themselves but from the constraints around them. Running a production-grade security stack on Windows with WSL2 and kind surfaces exactly the kind of friction that cloud-based tutorials hide: PowerShell CRLF line endings breaking Prometheus text format parsing; kind's localhost registry isolation requiring a completely different image delivery strategy; WSL2's custom kernel limiting Falco's eBPF syscall visibility; and Checkov's severity filtering sitting behind a paid API key that the official documentation does not prominently advertise. Each constraint was documented honestly with its root cause, resolution, and production equivalent. The broader lesson is that a security control which appears to be working but is measuring the wrong thing (like Trivy scanning the base image instead of the built service image) produces false assurance that is more dangerous than no control at all. Every suppression, every exception, and every workaround in this project has a documented justification precisely because the absence of that documentation is indistinguishable from negligence.

Looking forward, several natural extensions would complete the production picture. The most immediate is deploying the full stack on AWS EKS, which would unlock capabilities that kind's constraints prevented: real Falco event metrics in Prometheus; automated metrics pushing from CI via the internal NLB Pushgateway; and OWASP ZAP wired into the pipeline against a stable staging URL. Beyond that, OPA Gatekeeper would add a third enforcement layer at the Kubernetes admission level, ensuring no misconfigured resource can reach a node even if it bypasses the CI pipeline entirely. ArgoCD would replace direct `kubectl apply` with a GitOps delivery model, making every deployment auditable and reversible by definition. Falco Sidekick would route runtime alerts directly to Slack or PagerDuty without the Prometheus intermediary, closing the gap between a detection at 2am and an engineer being paged. The platform as it stands is a complete DevSecOps demonstration; what remains is operationalising it at production scale on AWS EKS.

---

## 19. Troubleshooting Reference

Full troubleshooting documentation covering 23 documented issues is at [`README-troubleshooting.md`](README-troubleshooting.md). Common issues are summarised below.

| Symptom | Root Cause | Fix |
|---|---|---|
| `kubectl exec` fails with a Windows path error | Git Bash converts `/bin/sh` to a Windows path | Use PowerShell, not Git Bash, for all kubectl commands |
| Cosign password prompt fails on Windows | PowerShell has no TTY for interactive input | Run Cosign from WSL2 Ubuntu |
| Vault pods stuck at `Init:0/1` after cluster restart | Dev mode in-memory state was wiped | Run `bash scripts/vault-init.sh` |
| `psycopg2-binary` fails to install on Python 3.12 | No pre-built wheel for 2.9.5 on Python 3.12 | Upgrade to `psycopg2-binary==2.9.9` |
| Falco pod crashes with schema validation error | Deprecated `grpcOutput` key in values file | Remove `grpcOutput:` key from Falco Helm values entirely |
| `falco_events_total` is always 0 in Prometheus | WSL2 kernel restricts certain eBPF program types | Expected behaviour on WSL2; alerts confirmed via `kubectl logs` |
| Checkov `--check-severity requires API key` | CLI severity filtering is a paid feature | Use `bridgecrewio/checkov-action@v12` with `check: CRITICAL` |
| Pushgateway push returns `unexpected end of input stream` | PowerShell produces CRLF line endings | Use Python `urllib.request` to push metrics |
| Grafana not reachable via `svc` port-forward | Service port indirection fails on kind | Forward directly to the pod on port 3000:3000 |
| `.trivyignore` suppression not working | Trivy version uses the other ID format | Add both `KSV014` and `KSV-0014` to `.trivyignore` |
| `git filter-repo` removes the remote after history rewrite | filter-repo intentionally removes remotes as a safety measure | Re-add with `git remote add origin <url>` then force-push |
| Kustomize path resolution error on Windows | Cross-directory `../` references in base kustomization | Move referenced files into the `base/` directory |
| Unknown pod status after node restart | kind node container restarted; kubelet lost contact | Force-delete stuck pods: `kubectl delete pod -n secureflow --all --force --grace-period=0` |

---

## 20. Technology Stack

| Category | Tool | Version / Notes |
|---|---|---|
| Application runtime | Python + Flask | 3.12 |
| Database | PostgreSQL | 14 (digest-pinned) |
| Container runtime | Docker | Desktop with WSL2 integration |
| Orchestration (local) | kind | Kubernetes in Docker |
| Orchestration (production) | AWS EKS | 1.31 |
| Configuration management | Kustomize | Bundled with kubectl |
| Secret management | HashiCorp Vault | Dev mode locally; Raft + KMS on EKS |
| Image signing | Cosign (Sigstore) | |
| SAST | SonarCloud | GitHub Actions integration |
| Container scanning | Trivy | CVEs and K8s misconfigurations |
| Secret scanning | Gitleaks | Current working tree only |
| IaC scanning | Checkov | `bridgecrewio/checkov-action@v12` |
| DAST | OWASP ZAP | Baseline scan; local only |
| Runtime security | Falco | modern_ebpf driver; 5 custom rules |
| Metrics | Prometheus | kube-prometheus-stack |
| Dashboards | Grafana | ConfigMap-provisioned; 8 panels |
| Alerting | Alertmanager | 6 PrometheusRule alerts |
| Metrics relay | Prometheus Pushgateway | CI pipeline metric ingestion |
| Infrastructure as code | Terraform | AWS EKS; VPC; RDS; S3; IAM |
| CI/CD | GitHub Actions | 7-stage parallel pipeline |
| Cloud (production) | AWS | EKS; ECR; KMS; RDS; S3; Client VPN |

---

## 21. Documentation Index

| Document | Contents |
|---|---|
| `README.md` (this file) | Full project overview; architecture; decisions; lessons; conclusion |
| `README-vault-integration.md` | Phase 1 step-by-step implementation guide |
| `README-container-hardening.md` | Phase 2 step-by-step implementation guide |
| `README-k8s-hardening-falco-terraform.md` | Phase 3, 4, and 5 implementation guide |
| `README-observability.md` | Phase 7 guide with key concept explanations |
| `README-eks-implementation-guide.md` | Full 8-phase AWS EKS production equivalent |
| `README-troubleshooting.md` | 23 documented issues with root cause and resolution |

---

*Repository: secureflow*  
*Implementation branch: devsecops-kenn*  
*Author: Kenneth Ikeagu*
---
*Contact: kenvalleytech@gmail.com*
