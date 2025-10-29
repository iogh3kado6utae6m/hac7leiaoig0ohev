# --- Stage 1: Builder image ---
FROM ruby:3.3-slim AS builder

WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends build-essential git && rm -rf /var/lib/apt/lists/*

COPY Gemfile Gemfile.lock ./
RUN bundle install --without development test

COPY . .

# --- Stage 2: Runtime image ---
FROM ruby:3.3-slim

ENV RACK_ENV=production \
    PORT=8080 \
    LOG_LEVEL=info

WORKDIR /app
COPY --from=builder /app /app

# Безопасность и оптимизация
RUN adduser --system --group appuser && \
    chown -R appuser:appuser /app

USER appuser

EXPOSE 8080

# Для graceful shutdown
STOPSIGNAL SIGTERM

# Healthcheck для Docker/Kubernetes
HEALTHCHECK --interval=10s --timeout=2s --retries=3 CMD curl -f http://localhost:${PORT}/health || exit 1

CMD ["bundle", "exec", "ruby", "victima.rb", "-o", "0.0.0.0", "-p", "8080"]
