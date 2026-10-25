# Version oficial fijada para que un redeploy no actualice el gateway.
ARG LITELLM_VERSION=1.106.3
FROM ghcr.io/berriai/litellm:v${LITELLM_VERSION}

COPY config.yaml /app/mar-config.yaml

ENV PORT=4000
EXPOSE 4000

# Se conserva el entrypoint de LiteLLM. Railway debe usar PORT=4000.
CMD ["--config", "/app/mar-config.yaml", "--host", "0.0.0.0", "--port", "4000"]
