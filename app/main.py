"""demo-app: a tiny web service used to demonstrate CI/CD and GitOps."""
import os

from fastapi import FastAPI

# Values come from environment variables, so the SAME image can behave
# differently per environment without being rebuilt.
APP_VERSION = os.getenv("APP_VERSION", "dev")
APP_MESSAGE = os.getenv("APP_MESSAGE", "Hello from demo-app")

app = FastAPI(title="demo-app")


@app.get("/")
def root():
    """Main endpoint: returns a message and the version (= git commit) of the running image."""
    return {"message": APP_MESSAGE, "version": APP_VERSION}


@app.get("/health")
def health():
    """Health endpoint: Kubernetes calls this to decide if the pod is alive and ready."""
    return {"status": "ok"}