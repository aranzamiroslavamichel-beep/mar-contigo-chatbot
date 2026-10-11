# mar-contigo-chatbot
Mar contigo · Chatbot de orientación ante violencia de género en CDMX

Aviso importante. Mar contigo no es un servicio de emergencia ni sustituye la atención profesional. Si estás en peligro ahora, llama al 911. El bot es un primer punto de contacto que orienta hacia recursos verificados de la Ciudad de México.

Trabajo Fin de Máster · [NOMBRE DEL MÁSTER] · [UNIVERSIDAD / ESCUELA] · 2026 Autora: Miroslava Michel

	
🤖 Bot de Telegram	@NOMBRE_DEL_BOT
🌐 Web	[URL de Framer]
📄 Documento del TFM	/docs/TFM.pdf

Índice
Qué es y qué problema resuelve
Principios de diseño
Arquitectura
Modelos y parametrización
Resiliencia
Estructura del repositorio
Puesta en marcha
Evaluación y pruebas
Seguridad y privacidad
Monitorización
Proceso de release
Lecciones técnicas
Estado, limitaciones y trabajo futuro
1. Qué es y qué problema resuelve

Las personas que viven violencia de género en la Ciudad de México se enfrentan a una oferta de recursos fragmentada: líneas telefónicas, refugios, asesoría legal y programas con nombres parecidos y datos que cambian. Buscar en ese momento es costoso y, a veces, peligroso.

Mar contigo es un chatbot de Telegram que:

detecta si la persona describe un peligro que está ocurriendo ahora y, en ese caso, responde de inmediato con contactos de emergencia fijos;
en el resto de casos, orienta hacia el recurso adecuado (emergencias, refugio, asesoría legal, denuncia, acompañamiento humano) usando únicamente información de una base verificada: el Documento Madre;
funciona sin registro y con anonimato por nombre de usuario de Telegram.
2. Principios de diseño

Estos principios son no negociables y explican la mayoría de decisiones técnicas:

Principio	Cómo se materializa
Cero alucinación en datos críticos	Teléfonos, direcciones y horarios nunca los genera el LLM: se insertan desde el Documento Madre mediante slots. Un evaluador automático lo verifica.
Verificación humana como puerta obligatoria	Ningún dato entra en producción sin estado = verificado contrastado contra fuente primaria.
Sesgo hacia falsos positivos	Ante la duda, el sistema clasifica como emergencia. Un falso negativo es el error más grave posible.
Nunca dejar sin respuesta	Cualquier fallo, límite o abuso degrada a un modo sin IA que sigue mostrando los contactos de emergencia; nunca bloquea.
Autonomía acotada	El LLM decide cómo hablar (estrategia conversacional), no qué datos dar. Es un asistente orquestado con agencia limitada donde el coste de error es bajo.
3. Arquitectura

El sistema está construido en n8n Cloud como siete workflows con responsabilidades separadas.

emergencia
consulta de recurso
fallo o abuso
error
alerta
Usuaria en Telegram
B · Conversación principal
F · Clasificador
Respuesta fija deemergencia
Agente RAG · Gemini
Documento Madresolo filas verificadas
A · Ingesta
D · Modo sin IA
C · Gestión de errores
Bot de administración
G · Banco de pruebas
Workflow	Función
A · Ingesta	Carga las filas verificadas del Documento Madre y genera los embeddings.
B · Conversación principal	Recibe el mensaje de Telegram, normaliza la entrada, aplica filtros, llama al clasificador y compone la respuesta.
C · Gestión de errores	Error workflow: registra el fallo y avisa al bot de administración.
D · Modo sin IA	Sirve el Documento Madre directamente con un teclado inline. Último escalón antes del texto de emergencia fijo.
E · [COMPLETAR]	[COMPLETAR función]
F · Clasificador	Sub-workflow reutilizable: única fuente de verdad de la clasificación. Lo invocan B y G.
G · Banco de pruebas	Ejecuta casos de prueba contra F y mide falsos negativos en emergencia.
Documento Madre

Base de recursos verificados organizada en cinco módulos:

Módulo	Contenido
M1 · Emergencias	Contactos de atención inmediata
M2 · [COMPLETAR]	
M3 · [COMPLETAR]	
M4 · [COMPLETAR]	
M5 · Acompañamiento humano	Derivación a personas

Cada fila incluye Estado_Verificacion, Fuente_Verificacion_Sugerida y Notas_Reconciliacion. NotebookLM se usó solo como capa de investigación: lo que produce entra con estado = pendiente.

4. Modelos y parametrización

Se usa exclusivamente Google Gemini.

Paso	Modelo	Por qué	Parámetros
Clasificación	Gemini Flash-Lite	Se ejecuta en cada mensaje: prima latencia y coste. La tarea es acotada (pocas categorías).	Temperatura 0 · salida JSON · maxTokens [COMPLETAR]
Agente RAG	Gemini [COMPLETAR versión]	Mejor calidad conversacional para redactar la respuesta en torno a los datos insertados.	Temperatura [COMPLETAR] · maxTokens [COMPLETAR]
Embeddings	models/text-embedding-004	Ver nota de resiliencia: no se puede cambiar de modelo sin reindexar.	—
LLM juez (evaluación)	Gemini [COMPLETAR, distinto del generador]	Puntúa tono y pertinencia con rúbrica.	Temperatura 0 · salida JSON

Los prompts de sistema, incluidas las versiones descartadas, están en /prompts con su historial. El razonamiento de cada cambio está en el decision log.

Costes estimados
Escenario	Conversaciones/mes	Coste estimado/mes
Piloto	100	[COMPLETAR]
Uso medio	1.000	[COMPLETAR]
Uso alto	10.000	[COMPLETAR]

Supuestos: [COMPLETAR tokens de entrada/salida por conversación medidos en ejecuciones reales] · precios de Gemini a fecha [COMPLETAR].

5. Resiliencia

Al depender de un único proveedor, la estrategia es una escalera de degradación:

Reintentos con espera en cada llamada a Gemini.
Segunda API key de un proyecto de Google Cloud distinto.
Alternancia de modelo dentro de Gemini.
Modo sin IA (Workflow D): el Documento Madre servido directamente.
Texto de emergencia fijo, sin ninguna dependencia externa.

⚠️ Los embeddings solo admiten fallback con el mismo nombre de modelo en otra API key. Cambiar de modelo de embeddings corrompe la recuperación en silencio, sin errores.

6. Estructura del repositorio
.
├── workflows/        # JSON exportados de n8n (A–G)
├── prompts/          # Prompts de sistema versionados, incluidos los descartados
├── evals/            # Dataset de evaluación y configuración de promptfoo
│   ├── dataset.csv
│   └── promptfooconfig.yaml
├── docs/
│   ├── decision-log.md
│   ├── matriz-riesgos.md
│   └── TFM.pdf
├── .github/workflows/  # [Si aplica] CI de evaluaciones
└── README.md

El Documento Madre no se publica en el repositorio: contiene datos operativos que deben mantenerse bajo control y revisión humana.

7. Puesta en marcha
Requisitos
Cuenta de n8n Cloud [COMPLETAR plan]
Dos proyectos de Google Cloud con la API de Gemini habilitada (una API key en cada uno)
Dos bots de Telegram creados con BotFather: test y producción
Pasos
Importar los workflows en este orden, porque B y G dependen de F: F → A → C → D → [E] → B → G.
Crear las credenciales en n8n: Telegram (test y producción), Gemini (key principal y key de respaldo).
Completar los campos manuales marcados en cada workflow: [COMPLETAR, por ejemplo IDs de sub-workflows, ID del error workflow, chat_id del bot de administración].
Cargar el Documento Madre y ejecutar el Workflow A.
Configurar el bot en BotFather: desactivar grupos con /setjoingroups.
Proteger el webhook con un secret_token (ver sección 9).
Probar con el bot de test antes de activar producción.

💡 Para depurar un workflow publicado, usa Executions → Copy to editor en lugar de Execute step: evita conflictos entre el webhook en vivo y los datos fijados.

8. Evaluación y pruebas
Tipo	Herramienta	Métrica	Objetivo
Detección de emergencia	Workflow G	Falsos negativos	0
Clasificación	n8n Evaluations	Exactitud por categoría	[COMPLETAR]
Integridad de datos	Nodo Code (regex)	% de teléfonos/direcciones de la respuesta presentes en el Documento Madre verificado	100 %
Latencia	Logs de ejecución	Tiempo medio de clasificación y de respuesta	[COMPLETAR]
Calidad conversacional	LLM como juez	Rúbrica 1–5: empatía, no revictimización, pertinencia, sin consejo legal inventado	[COMPLETAR]
Robustez	promptfoo (red-team)	Ataques superados	[COMPLETAR]

El juez se calibró contra 10 casos puntuados a mano: [COMPLETAR concordancia].

Resultados
Métrica	Línea base	Versión final
Falsos negativos en emergencia	[ ]	[ ]
Latencia media de clasificación	[ ]	[ ]
Integridad de datos	[ ]	[ ]
Puntuación media del juez	[ ]	[ ]
Ejecutar el red-team
bash
cd evals
npx promptfoo@latest redteam run
npx promptfoo@latest view

Los ataques se lanzan contra un webhook de pruebas que solo existe en el entorno de test y exige cabecera secreta. Informe completo: /docs/matriz-riesgos.md.

9. Seguridad y privacidad

Las protecciones están ordenadas de más barata a más cara. Ninguna deja a una persona sin los contactos de emergencia: el abuso degrada al modo sin IA.

Capa	Control
Entrada	El webhook solo acepta peticiones con la cabecera X-Telegram-Bot-Api-Secret-Token correcta. La web enlaza a t.me/..., nunca a la URL de n8n.
Filtros previos	Solo chats privados, solo texto, longitud máxima de [COMPLETAR] caracteres.
Límite por usuaria	Máximo de [COMPLETAR] mensajes por ventana por chat_id; al superarlo, modo sin IA.
Freno global	Contador diario de llamadas a Gemini + cuotas y alertas de presupuesto en Google Cloud.
Contenido	El LLM nunca genera datos de contacto. Las ubicaciones de casas refugio nunca se comparten por el bot.
Datos personales	Solo se guarda [COMPLETAR: hash del chat_id, categoría, métricas técnicas]. El contenido de los mensajes [COMPLETAR política]. Retención: [COMPLETAR].

Registrar el webhook con secret token:

bash
curl -X POST "https://api.telegram.org/bot<TOKEN>/setWebhook" \
  -d "url=<URL_DEL_WEBHOOK_DE_N8N>" \
  -d "secret_token=<SECRETO>"

Si usas el nodo Telegram Trigger de n8n, comprueba primero si gestiona él mismo el registro del webhook para no sobrescribirlo.

10. Monitorización

Cada ejecución registra: hash del chat_id, categoría, latencia, modelo usado, escalón de resiliencia alcanzado y tokens consumidos.

Panel: [COMPLETAR enlace a Looker Studio o capturas]
Alertas: el Workflow C avisa por Telegram al bot de administración ante errores.
Indicadores que se vigilan: tasa de fallback, latencia, coste diario y porcentaje de respuestas en modo sin IA.
11. Proceso de release
falsos negativos = 0integridad = 100 %
falla
Cambio en bot de test
Commit y push a GitHub
Evaluaciones + Workflow G
Revisión humana
Promoción a producción +tag de versión

La promoción a producción es manual a propósito: en un dominio de alto riesgo, una persona revisa cada cambio que ya pasó las pruebas automáticas. [COMPLETAR: si hay GitHub Action, describir qué automatiza; si no, enlazar la checklist de release.]

12. Lecciones técnicas

Problemas reales encontrados durante el desarrollo, útiles para cualquiera que construya algo similar en n8n:

Fallos silenciosos hacia la primera salida. Con la gestión de errores de n8n, los items fallidos salen por la primera salida del nodo. Como la primera rama era "emergencia", un fallo aguas arriba clasificaba todo como emergencia sin dar error.
pairedItem se pierde al cruzar sub-workflows. Después de llamar a un sub-workflow, usar $('Nodo').first() en lugar de .item.
Session ID de la memoria. Con un trigger de Telegram, el modo automático falla; hay que fijarlo al chat_id de forma explícita.
Reglas de clasificación demasiado amplias. Una regla del tipo "cualquier vocabulario de violencia = emergencia" disparaba falsos positivos masivos; se acotó a "peligro ocurriendo ahora".
Programas con nombres parecidos. Casas Siemprevivas y Unidades Siempre Vivas (LUNAS) son programas distintos y no deben fusionarse en los datos.
13. Estado, limitaciones y trabajo futuro
Estado
 Flujo completo en producción
 Webhook protegido con secret token
 Rate limiting y freno global
 Evaluaciones automatizadas
 LLM como juez calibrado
 Red-team con promptfoo
 Monitorización y alertas
 Web en Framer publicada
 Prueba con usuarias externas
Limitaciones
Dependencia de un único proveedor de LLM.
El Documento Madre requiere mantenimiento humano continuo para seguir siendo fiable.
[COMPLETAR]
Trabajo futuro
Gateway de IA (LiteLLM): trazabilidad de costes por llamada y posibilidad de cambiar de proveedor sin tocar los workflows.
n8n en local para desarrollo, sincronizado con Git.
[COMPLETAR]
Licencia

[COMPLETAR, por ejemplo MIT para el código; el contenido del Documento Madre no se distribuye.]
Mar contigo is a chatbot for womans in mexico city, who needs assitant for violence