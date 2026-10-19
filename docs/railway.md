# Desplegar Mar contigo en Railway con Docker

El repositorio contiene siete workflows exportados de n8n: A, B, C, D, F, G y H. El Dockerfile instala n8n y copia los JSON a `/opt/n8n/workflows/`. La importación y la activación se hacen una vez, después de conectar las credenciales. Un redeploy actualiza la imagen y esas copias, pero no sobrescribe los workflows guardados en la base de datos.

La configuración inicial usa **una instancia de n8n y SQLite en un volumen persistente**. No requiere Redis, workers ni paquetes de nodos adicionales: los tipos de nodos de estos JSON forman parte de la distribución oficial. Para usar PostgreSQL, ver el apartado correspondiente antes del primer despliegue.

## 1. Crear el servicio

1. Sube estos archivos al repositorio de GitHub que vas a conectar.
2. En Railway, crea un proyecto y un servicio desde **GitHub Repo**.
3. Selecciona este repositorio y deja la raíz del servicio en `/`. Railway detecta el `Dockerfile` de la raíz.
4. Deja vacíos los comandos personalizados de build y de arranque: se utiliza el arranque de la imagen oficial.
5. Configura una sola réplica y desactiva Serverless/suspensión por inactividad para mantener el bot disponible.

## 2. Crear el almacenamiento persistente

Antes de importar nada, adjunta un **Volume** al servicio n8n con esta ruta exacta:

```text
/home/node/.n8n
```

Aquí se guardan SQLite, los workflows importados, las credenciales cifradas y la configuración. El sistema de archivos normal del contenedor se reemplaza en los redeploys. Configura backups del volumen y guarda aparte una copia segura de la clave de cifrado.

## 3. Configurar dominio y variables

1. En **Settings → Networking**, genera un dominio público con **Generate Domain** y usa el puerto de destino **5678**.
2. En **Variables → Raw Editor**, copia las variables sin comentar de [`.env.example`](../.env.example).
3. Sustituye `N8N_ENCRYPTION_KEY` por una clave aleatoria generada en tu equipo, por ejemplo:

   ```sh
   openssl rand -hex 32
   ```

4. Conserva esa clave entre despliegues. Cambiarla impide descifrar las credenciales ya guardadas. No la subas a Git.
5. Comprueba que Railway resuelve `RAILWAY_PUBLIC_DOMAIN` al dominio generado. Si usas un dominio propio, escribe ese dominio en `N8N_HOST` y las URL HTTPS completas en `N8N_EDITOR_BASE_URL` y `N8N_WEBHOOK_URL`.
6. En los ajustes de despliegue, configura el **Healthcheck Path** en `/healthz/readiness` y un timeout de **300 segundos**. La respuesta 200 confirma que la base de datos está conectada y migrada.
7. Despliega y abre el dominio para crear la cuenta propietaria de n8n inmediatamente.

`PORT` y `N8N_PORT` deben quedar ambos en `5678`: Railway usa el primero para el enrutamiento y el healthcheck, y n8n escucha en el segundo. Railway termina HTTPS; n8n escucha HTTP dentro del contenedor. `N8N_PROXY_HOPS=1` corresponde al proxy de Railway; revisa el valor si añades otros proxies.

Esta imagen fija n8n **2.43.8** para que un redeploy no cambie de versión inesperadamente. Usa `N8N_WEBHOOK_URL`, el nombre actual de la variable de webhooks; `WEBHOOK_URL` es un alias deprecado desde n8n 2.35. No uses `N8N_BASIC_AUTH_*`: n8n retiró esa autenticación en la versión 1.0 y utiliza su pantalla de inicio de sesión.

## 4. Conectar los servicios externos

Los JSON incluyen referencias a credenciales de la instancia original, no sus secretos. Hay que crearlas en la nueva instancia y seleccionarlas de nuevo en los nodos:

| Credencial | Uso y configuración pendiente |
| --- | --- |
| Telegram API | Token del bot en B, C y D. Usa un bot distinto para las pruebas. Revisa también el `chat_id` administrativo de C. |
| Google Gemini / Google Palm API | Claves principal y de respaldo para los nodos de Gemini de A, B, F y H. |
| Google Sheets OAuth2 | Lectura del Documento Madre, bitácora, casos de prueba y resultados. En self-hosted debes configurar tu propio cliente OAuth de Google, habilitar Google Sheets API y Google Drive API, y registrar exactamente la URL de redirección que muestra n8n en esa credencial. Autoriza una cuenta con acceso a las hojas. |
| Pinecone API | Clave y acceso al índice `mar-contigo-recursos`, utilizado por A y B. |

Revisa los IDs de los documentos, pestañas e índice. Puedes conservar los actuales si tienes acceso a los mismos recursos. El Documento Madre y las hojas de resultados no se crean al construir la imagen.

Los JSON actuales de A y B usan `models/gemini-embedding-2`; el README general todavía menciona otro modelo. Mantén el mismo modelo y dimensiones en la ingesta, la consulta y el índice de Pinecone. Confirma también que tus claves tienen acceso a los modelos seleccionados en los workflows. Si cambias de modelo de embeddings, crea/reconstruye el índice correspondiente.

## 5. Importar y revisar los workflows

1. Desde el editor de n8n usa **Import from File** con los JSON de `workflows/`, en este orden: **F → A → C → D → B → G → H**. No hay un workflow E en el repositorio.
2. Comprueba que **B esté desactivado/sin publicar** durante la configuración; el JSON original tiene `active: true`.
3. Asigna las credenciales creadas a todos los nodos correspondientes.
4. En **B06 · Clasificar (sub-workflow F)1** y **G4 · Clasificar (sub-workflow F)**, vuelve a seleccionar el workflow F importado. Los JSON apuntan al ID `xJSC5YgRUNDDVklY` de la instancia original; la importación desde el editor puede asignar otros IDs.
5. En los ajustes de los workflows que deban gestionar errores, selecciona **C · Manejo de errores** como **Error Workflow**. Los JSON actuales no tienen esa asociación configurada.
6. Revisa cómo debe invocarse D: el workflow B exportado solo contiene una llamada a sub-workflow, la de F. Importar D no lo conecta automáticamente como fallback de B.
7. Quita los datos fijados (**pinned data**) de F antes de evaluar la clasificación.
8. Comprueba la conectividad con Google Sheets, Gemini y Pinecone. Si necesitas reconstruir el índice, revisa A antes de ejecutarlo: **A5 tiene `clearNamespace: true` y puede borrar los vectores del namespace configurado**. No hace falta ejecutarlo si conservas un índice compatible ya cargado.
9. Ejecuta G y, si corresponde, H con tus datos de prueba. Revisa los resultados antes de activar el bot.

Las copias de los JSON dentro del contenedor sirven también para una importación manual con la CLI de n8n. No se ejecuta ninguna importación durante el arranque para evitar reemplazar cambios hechos desde el editor en cada redeploy.

## 6. Activar Telegram

Cuando el bot de pruebas funcione, publica/activa B en Railway. El nodo **Telegram Trigger** registra su webhook utilizando la URL pública configurada.

Telegram admite un solo webhook por bot. Si el mismo token sigue activo en n8n Cloud, coordina el cambio: desactiva B en Cloud antes de activarlo en Railway. Evita ejecutar el trigger en modo de prueba con el token de producción, porque puede reemplazar el webhook activo.

## PostgreSQL opcional

Para guardar los datos de n8n en PostgreSQL, crea un servicio PostgreSQL llamado `Postgres` y añade las variables `DB_*` comentadas en `.env.example` al servicio n8n. Si el servicio tiene otro nombre, ajusta las referencias. Conserva también el volumen de n8n para sus archivos locales.

Elige la base de datos antes de importar los workflows. Añadir las variables `DB_*` a una instalación que ya usa SQLite **no migra sus datos**: n8n conectará a otra base de datos y habrá que migrar los datos de forma explícita.

## Comprobaciones y problemas habituales

- **502 / healthcheck fallido:** comprueba los logs, `PORT=5678`, `N8N_PORT=5678`, el puerto del dominio y el volumen montado en la ruta correcta.
- **`EACCES` al escribir en `.n8n`:** la imagen ejecuta n8n como `node`, y los volúmenes de Railway pueden tener permisos de root. Railway documenta `RAILWAY_RUN_UID=0` como solución; añádelo al servicio y vuelve a desplegar si aparece ese error. Esto ejecuta el proceso como root. `N8N_USER_FOLDER=/home/node` mantiene los datos en el volumen configurado.
- **Google OAuth devuelve `redirect_uri_mismatch`:** registra la URL exacta que muestra n8n tras configurar el dominio definitivo y vuelve a autorizar la cuenta.
- **Telegram no recibe mensajes:** revisa la URL pública HTTPS, la publicación de B y que otra instancia no esté usando el mismo token.
- **Credenciales no disponibles o sub-workflow no encontrado:** vuelve a seleccionarlos en la nueva instancia; importar el JSON no migra secretos.
- **Se pierde el historial conversacional tras reiniciar:** B utiliza Simple Memory en RAM. El volumen conserva la base de datos de n8n, pero no esa memoria. Si necesitas conservar conversaciones entre reinicios, cambia ese nodo por una memoria persistente.

## Validación local

Prueba realizada con Docker el 19 de octubre de 2026:

- Construcción correcta de la imagen `mar-contigo-n8n:smoke` con n8n 2.43.8 desde Docker Hub. El registro `docker.n8n.io` devolvió HTTP 429, por lo que el Dockerfile utiliza la imagen oficial `n8nio/n8n` de Docker Hub.
- Editor y `/healthz/readiness` responden HTTP 200; n8n arranca como usuario `node` (UID 1000) y crea SQLite en el volumen.
- La imagen incluye exactamente los siete JSON, sin `.DS_Store`.
- Importación de los siete workflows y exportación de los mismos después de recrear el contenedor con el mismo volumen. Todos permanecieron desactivados.

La prueba se ejecutó sin acceso a la red y sin credenciales externas. Valida el arranque, la importación y la persistencia local; las llamadas a Telegram, Google Sheets, Gemini y Pinecone deben comprobarse con sus credenciales en Railway. Los contenedores y el volumen de prueba se eliminaron al terminar.

## Referencias

- [n8n: instalación con Docker](https://docs.n8n.io/hosting/installation/docker/)
- [n8n: webhooks detrás de un proxy](https://docs.n8n.io/hosting/configuration/configuration-examples/webhook-url/)
- [n8n: usuarios y autenticación](https://docs.n8n.io/hosting/configuration/user-management-self-hosted/)
- [n8n: comprobaciones de disponibilidad](https://docs.n8n.io/hosting/logging-monitoring/monitoring/)
- [Railway: Dockerfiles](https://docs.railway.com/guides/dockerfiles)
- [Railway: volúmenes y permisos](https://docs.railway.com/reference/volumes)
