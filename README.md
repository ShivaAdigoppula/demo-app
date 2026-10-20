# demo-app

Small FastAPI service used to demonstrate CI (Jenkins, SonarQube, Trivy) and GitOps (Argo CD on EKS).

- `GET /` returns a message and the running version (git commit)
- `GET /health` returns `{"status": "ok"}` (used by Kubernetes probes)

Run locally: `uvicorn app.main:app --reload`
Test: `pytest -v`