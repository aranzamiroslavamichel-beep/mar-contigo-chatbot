# Version estable consultada en la documentacion oficial de n8n.
# Actualizar de forma explicita tras probar los workflows.
ARG N8N_VERSION=2.43.8
FROM n8nio/n8n:${N8N_VERSION}

ENV N8N_PORT=5678 \
    N8N_LISTEN_ADDRESS=0.0.0.0 \
    N8N_USER_FOLDER=/home/node \
    N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true \
    GENERIC_TIMEZONE=America/Mexico_City \
    TZ=America/Mexico_City

# Copias para importacion manual. No se importan ni activan al arrancar.
# La base de datos debe persistir en /home/node/.n8n, fuera de esta ruta.
COPY --chown=node:node workflows/ /opt/n8n/workflows/

EXPOSE 5678

# Se conservan el usuario node y el arranque de la imagen oficial.
