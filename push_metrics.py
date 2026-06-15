import urllib.request

metrics = (
    'secureflow_gate_status{branch="devsecops-kenn",repo="secureflow"} 1\n'
    'secureflow_gitleaks_findings{branch="devsecops-kenn",repo="secureflow"} 0\n'
    'secureflow_trivy_image_findings{branch="devsecops-kenn",repo="secureflow"} 0\n'
    'secureflow_trivy_k8s_findings{branch="devsecops-kenn",repo="secureflow"} 0\n'
    'secureflow_checkov_findings{branch="devsecops-kenn",repo="secureflow"} 0\n'
    'secureflow_sonar_findings{branch="devsecops-kenn",repo="secureflow"} 4\n'
)

data = metrics.encode("utf-8")
req = urllib.request.Request(
    "http://localhost:9091/metrics/job/secureflow_ci",
    data=data,
    method="POST",
    headers={"Content-Type": "text/plain"}
)
with urllib.request.urlopen(req) as resp:
    print("Status:", resp.status)
