# Dockerfile for Transaction Service with security improvements

FROM python:3.12-slim
# CK-01 fix — updated to a more recent base image with security patches.
WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .
COPY vault_config.py .
# I added this file to load secrets from Vault Agent Injector's file-based secrets into environment variables.

# CK-02 fix — create non-root user and group
RUN groupadd --system app && useradd --system --gid app --no-create-home app

RUN chown -R app:app /app

USER app

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5002/health')" \
  || exit 1

EXPOSE 5002

CMD ["python", "app.py"]
