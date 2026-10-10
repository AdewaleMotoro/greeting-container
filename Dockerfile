# syntax=docker/dockerfile:1.7

# ============================================================
# Stage 1: Build — install Python dependencies in a virtualenv
# ============================================================
FROM python:3.12-slim-bookworm AS builder

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
    && rm -rf /var/lib/apt/lists/*

RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

WORKDIR /build

COPY app/requirements.txt .

RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt

# ============================================================
# Stage 2: Runtime — small, secure, production-ready
# ============================================================
FROM python:3.12-slim-bookworm AS runtime

RUN groupadd --gid 1000 app \
    && useradd --uid 1000 --gid app --shell /bin/bash --create-home app

COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

WORKDIR /app

COPY --chown=app:app app/ ./app/

USER app

EXPOSE 8080

LABEL org.opencontainers.image.title="greeting-container" \
      org.opencontainers.image.description="Sample Flask greeting application" \
      org.opencontainers.image.version="v1" \
      org.opencontainers.image.source="https://github.com/AdewaleMotoro/greeting-container"

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request, sys; sys.exit(0 if urllib.request.urlopen('http://localhost:8080/healthz').status == 200 else 1)"

CMD ["gunicorn", "--chdir", "app", "--bind", "0.0.0.0:8080", "--workers", "2", "--access-logfile", "-", "--error-logfile", "-", "app:app"]
