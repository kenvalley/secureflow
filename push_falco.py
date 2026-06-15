import urllib.request

metrics = (
    'falco_events_total{priority="Warning",rule="Shell Spawned in SecureFlow Container",source="syscall"} 3\n'
    'falco_events_total{priority="Critical",rule="Sensitive File Read in SecureFlow Container",source="syscall"} 5\n'
    'falco_events_total{priority="Error",rule="Package Manager Executed in SecureFlow Container",source="syscall"} 2\n'
    'falco_events_total{priority="Warning",rule="Unexpected Outbound Connection from SecureFlow Container",source="syscall"} 1\n'
)

data = metrics.encode("utf-8")
req = urllib.request.Request(
    "http://localhost:9091/metrics/job/falco_events",
    data=data,
    method="POST",
    headers={"Content-Type": "text/plain"}
)
with urllib.request.urlopen(req) as resp:
    print("Status:", resp.status)
