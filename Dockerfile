# ---------- Base image: small, official Python on Debian ----------
FROM python:3.12-slim

# Don't write .pyc files; print logs immediately (important in containers)
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# ---------- 1. Dependencies FIRST (cached until requirements.txt changes) ----------
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# ---------- 2. Then the code (changes often) ----------
COPY app/ ./app/

# ---------- 3. Version baked into the image (Jenkins passes the git commit) ----------
ARG APP_VERSION=dev
ENV APP_VERSION=${APP_VERSION}

# ---------- 4. Run as a NON-root user ----------
RUN useradd --create-home --uid 10001 appuser
USER 10001

EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]