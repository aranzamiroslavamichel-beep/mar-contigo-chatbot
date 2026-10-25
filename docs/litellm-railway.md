# LiteLLM en Railway con PostgreSQL de Supabase

El servicio se construye desde `litellm/Dockerfile`, con la imagen oficial de LiteLLM fijada en 1.106.3. Escucha en el puerto 4000. PostgreSQL conserva claves virtuales, presupuestos y registros de tokens y costes. El servicio n8n mantiene su base de datos y su volumen actuales.

## 1. Preparar Supabase

1. Crea un proyecto dedicado, por ejemplo `mar-contigo-litellm`, en una region europea proxima a Railway EU West. Conserva su contrasena de base de datos. `openssl rand -hex 32` permite generar una contrasena apta para incluir directamente en una URL.
2. Desactiva la **Data API** de ese proyecto en sus ajustes: LiteLLM utiliza PostgreSQL directamente y no necesita exponer sus tablas mediante la API de Supabase.
3. Pulsa **Connect** y copia la URL de **Session pooler**, puerto **5432**. Sustituye `[YOUR-PASSWORD]` por la contrasena. Si utilizas caracteres reservados como `@`, `:` o `/`, codifica la contrasena para una URL.
4. Anade `?sslmode=require&connection_limit=5` si la URL no tiene parametros; si ya tiene parametros, anadelos con `&`, sin duplicarlos.

Ejemplo de estructura, con valores ficticios:

```text
postgresql://postgres.PROJECT_REF:CONTRASENA@HOST.pooler.supabase.com:5432/postgres?sslmode=require&connection_limit=5
```

Usa el usuario y servidor exactos que muestra Supabase. La URL es una credencial PostgreSQL; no es la URL HTTPS del proyecto ni una clave `anon` o `service_role`. Las tablas las crea LiteLLM al iniciar. No uses el pooler de transacciones del puerto 6543 para este despliegue.

## 2. Subir los archivos

Sube a GitHub la carpeta `litellm/`. El Dockerfile de la raiz del repositorio sigue siendo el de n8n. Railway debe construir cada servicio desde su directorio correspondiente.

`litellm/.dockerignore` solo permite incluir el Dockerfile y `config.yaml` en la imagen. Las credenciales se introducen en Railway, nunca en Git ni en el Dockerfile.

## 3. Crear el servicio Railway

1. En el proyecto y entorno actuales, usa **+ Add -> GitHub Repo** y selecciona este repositorio. Crea un servicio nuevo llamado `litellm`.
2. Antes del despliegue definitivo, configura **Settings -> Source -> Root Directory** en **`/litellm`**. Si Railway inicio un despliegue desde la raiz, vuelve a desplegar tras corregirlo.
3. Deja que Railway detecte el `Dockerfile` de esa carpeta. Deja vacios los comandos personalizados de build y arranque; el Dockerfile ya arranca LiteLLM con `config.yaml`.
4. Usa **EU West**, **una replica** y manten el servicio disponible durante las pruebas.
5. Anade las variables de `litellm/.env.example`. Sustituye todos los valores de ejemplo. Genera valores independientes para `LITELLM_MASTER_KEY`, `LITELLM_SALT_KEY` y `UI_PASSWORD`; el primero debe comenzar por `sk-`.
6. Configura **Healthcheck Path** en **`/health/readiness`** y el timeout en **300 segundos**. La sonda comprueba la base de datos sin llamar a Gemini.
7. En **Networking**, genera un dominio publico con puerto de destino **4000**. Establece `PROXY_BASE_URL=https://DOMINIO-GENERADO`, sin barra final ni ruta, y despliega.

Los logs de build deben indicar la imagen de LiteLLM, no `n8nio/n8n`. Este servicio no necesita un volumen local: el YAML esta dentro de la imagen y el estado persistente esta en Supabase. La base de datos y la salt key deben conservarse entre despliegues.

## 4. Entrar y probar

1. Abre `https://DOMINIO-GENERADO/ui`. Accede con `UI_USERNAME` y `UI_PASSWORD`.
2. Verifica que aparecen los modelos `mar-chat`, `mar-clasificador` y `mar-respaldo`.
3. En **Playground**, prueba un mensaje ficticio con `mar-chat`; comprueba respuesta, tokens y coste calculado en **Usage/Logs**. Los registros se escriben en lotes, por lo que puede haber un pequeno retraso.
4. Reinicia solo `litellm` y comprueba que las claves virtuales y las metricas se conservan. En Supabase deben aparecer tablas como `LiteLLM_SpendLogs` y `LiteLLM_VerificationToken`.
5. Crea una clave virtual de prueba en **Virtual Keys**, con acceso a los tres aliases. Utiliza esa clave en n8n, no la master key administrativa.

Los modelos y fallbacks de esta configuracion estan definidos en Git; no tienes que crearlos otra vez desde el panel. LiteLLM muestra los modelos del YAML como modelos de configuracion, que no se editan en la UI. Puedes anadir otros modelos desde el panel y se guardaran en Supabase. Si quieres administrar tambien los tres modelos iniciales desde la UI, hay que migrarlos al almacenamiento de modelos en BD antes de quitarlos del YAML.

El respaldo inicial utiliza otra version de Gemini con la misma clave. Esto cubre ciertos fallos del modelo, pero no da independencia respecto a las cuotas o la disponibilidad del proyecto Google. Para usar otra clave/proyecto, anade una variable de respaldo y cambia la referencia del modelo en `config.yaml`.

La configuracion conserva los registros de consumo y desactiva el guardado de prompts/respuestas en SpendLogs y en los callbacks. No actives debug detallado para el trafico real. LiteLLM solo contabiliza peticiones que atraviesan el gateway; su coste calculado no sustituye la factura del proveedor.

## 5. Prueba independiente desde n8n

Importa `litellm/prueba-n8n.json` como un workflow nuevo. No necesita publicacion ni Telegram.

En el nodo **LiteLLM - mar-chat**, crea y selecciona una credencial **OpenAI**:

| Campo | Valor |
| --- | --- |
| API Key | La clave virtual de prueba |
| Base URL | `https://DOMINIO-GENERADO/v1` |
| Organization ID | Vacio |

El workflow utiliza `mar-chat`, Chat Completions (`Use Responses API` desactivado), timeout de 60 segundos y cero reintentos en el cliente. Ejecutalo manualmente y comprueba que la peticion aparece en LiteLLM. La migracion de B, F y H se hace despues; esta preparacion no modifica sus JSON ni sus credenciales.

## Desarrollo local opcional

Desde `litellm/`, copia `.env.example` a `.env`, introduce los valores reales de prueba y ejecuta:

```sh
docker compose up --build -d
```

El panel queda en `http://localhost:4000/ui` y utiliza la base externa indicada en `DATABASE_URL`. Para detenerlo, ejecuta `docker compose down`. El archivo `.env` esta excluido de Git y de la imagen Docker.

## Validacion local

Prueba realizada el 25 de octubre de 2026 con PostgreSQL local y credenciales ficticias, en una red Docker sin salida a proveedores externos:

- Construccion correcta desde `litellm/Dockerfile`.
- Migraciones completas y `/health/readiness` con HTTP 200 y `db: connected`.
- Panel `/ui/` accesible; API de modelos sin autenticacion rechazada con HTTP 401.
- Los tres aliases del YAML estan disponibles.
- Creacion de un modelo simulado en BD y una clave virtual; una respuesta simulada registro 30 tokens y un coste calculado en `LiteLLM_SpendLogs`.
- Tras reiniciar el gateway, la clave virtual y el modelo de BD siguieron disponibles y los registros permanecieron en PostgreSQL.

Los contenedores y la red de prueba se eliminaron al terminar; la imagen `mar-contigo-litellm:smoke` queda disponible localmente. La prueba no verifica una conexion real a Supabase ni llamadas reales a Gemini: estas se comprueban despues de configurar las variables del servicio Railway.

## Referencias

- [LiteLLM: inicio con PostgreSQL y panel](https://docs.litellm.ai/docs/proxy/docker_quick_start)
- [LiteLLM: modelos de BD y modelos de configuracion](https://docs.litellm.ai/docs/proxy/model_management)
- [Supabase: conexiones PostgreSQL](https://supabase.com/docs/guides/database/connecting-to-postgres)
- [Supabase: Prisma y Data API](https://supabase.com/docs/guides/database/prisma)
- [Railway: directorio raiz para servicios de un monorepo](https://docs.railway.com/guides/monorepo)
