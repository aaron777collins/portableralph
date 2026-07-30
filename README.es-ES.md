

# PortableRalph

[![Deploy Documentation](https://github.com/aaron777collins/portableralph/actions/workflows/docs.yml/badge.svg)](https://github.com/aaron777collins/portableralph/actions/workflows/docs.yml)
[![Windows Compatibility](https://github.com/aaron777collins/portableralph/actions/workflows/windows-test.yml/badge.svg)](https://github.com/aaron777collins/portableralph/actions/workflows/windows-test.yml)
[![CI Tests](https://github.com/aaron777collins/portableralph/actions/workflows/ci.yml/badge.svg)](https://github.com/aaron777collins/portableralph/actions/workflows/ci.yml)

Un bucle de desarrollo de IA autónomo que funciona en **cualquier repositorio**.

[**Ver Documentación →**](https://aaron777collins.github.io/portableralph/)

```bash
ralph ./feature-plan.md
```

Ralph lee tu plan, lo divide en tareas y las implementa una por una hasta completarlas.

## Inicio Rápido

### Linux / macOS

**Instalación en una línea:**
```bash
curl -fsSL https://raw.githubusercontent.com/aaron777collins/portableralph/master/install.sh | bash
```

**O manualmente:**
```bash
# Clona el repositorio
git clone https://github.com/aaron777collins/portableralph.git ~/ralph

# Haz los scripts ejecutables
chmod +x ~/ralph/*.sh

# Añade a PATH (opcional)
echo 'export PATH="$HOME/ralph:$PATH"' >> ~/.bashrc
source ~/.bashrc

# O crea un alias
echo 'alias ralph="$HOME/ralph/ralph.sh"' >> ~/.bashrc
source ~/.bashrc
```

**Ejecutar:**
```bash
ralph ./my-plan.md
```

### Windows

**Instalación con PowerShell:**
```powershell
irm https://raw.githubusercontent.com/aaron777collins/portableralph/master/install.ps1 | iex
```

**O manualmente:**
```powershell
# Clona el repositorio
git clone https://github.com/aaron777collins/portableralph.git $env:USERPROFILE\ralph

# Navega al directorio
cd $env:USERPROFILE\ralph

# Verifica la directiva de ejecución de PowerShell (puede requerir ajuste)
Get-ExecutionPolicy

# Si es necesario, establece la directiva de ejecución
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser

# Añade a PATH (opcional)
$env:PATH += ";$env:USERPROFILE\ralph"

# O crea un alias en PowerShell (añadir a $PROFILE)
New-Alias -Name ralph -Value $env:USERPROFILE\ralph\ralph.ps1
```

**Ejecutar (PowerShell):**
```powershell
ralph .\my-plan.md
```

**Ejecutar (Símbolo del sistema):**
```cmd
launcher.bat ralph .\my-plan.md
```

**Nota:** Los usuarios de Windows pueden usar tanto PowerShell (scripts `.ps1`) como Git Bash (scripts `.sh`). Los scripts de lanzamiento (`launcher.sh` y `launcher.bat`) detectan automáticamente tu entorno y ejecutan la versión del script adecuada.

## Cómo Funciona

```
 Tu Plan          Bucle de Ralph              Archivo de Progreso
┌──────────┐      ┌─────────────┐         ┌─────────────┐
│ feature  │      │ 1. Leer     │         │ - [x] Hecho │
│   .md    │ ───► │ 2. Elegir tarea│ ◄─────► │ - [ ] Pendiente │
│          │      │ 3. Implementar│         │ - [ ] Pendiente │
└──────────┘      │ 4. Confirmar  │         │             │
                  │ 5. Repetir    │         │ RALPH_DONE  │
                  └─────────────┘         └─────────────┘
```

1. **Tú escribes** un archivo de plan describiendo qué construir
2. **Ralph lo divide** en tareas discretas (el modo plan termina aquí)
3. **Cada iteración**: elegir una tarea → implementar → validar → confirmar (commit)
4. **El bucle termina** cuando aparece `RALPH_DONE` en el archivo de progreso (modo build)

## Uso

### Unix/Linux/macOS
```bash
ralph <archivo-plan> [modo] [iteraciones-maximas]
ralph notify <setup|test>
```

### Windows (PowerShell)
```powershell
ralph <archivo-plan> [modo] [iteraciones-maximas]
ralph notify <setup|test>
```

### Windows (Símbolo del sistema)
```cmd
launcher.bat ralph <archivo-plan> [modo] [iteraciones-maximas]
launcher.bat notify <setup|test>
```

| Modo | Descripción |
|------|-------------|
| `build` | Implementar tareas hasta que aparezca RALPH_DONE (predeterminado) |
| `plan` | Analizar y crear lista de tareas, luego salir (se ejecuta una vez) |

### Ejemplos

**Unix/Linux/macOS:**
```bash
ralph ./feature.md           # Construir hasta completar
ralph ./feature.md plan      # Solo plan (crea lista de tareas, sale)
ralph ./feature.md build 20  # Construir, máximo 20 iteraciones
```

**Windows (PowerShell):**
```powershell
ralph .\feature.md           # Construir hasta completar
ralph .\feature.md plan      # Solo plan (crea lista de tareas, sale)
ralph .\feature.md build 20  # Construir, máximo 20 iteraciones
```

## Configuración

Ralph se configura mediante `~/.ralph.env`. Configuraciones disponibles:

```bash
# Modelo de Claude a usar (predeterminado: sonnet)
export RALPH_MODEL="sonnet"
# Otras opciones: claude-opus-4-6, claude-haiku-4-5-20251001, etc.

# Confirmación automática después de cada iteración (predeterminado: true)
export RALPH_AUTO_COMMIT="true"

# Transmitir la salida de Claude a la terminal en tiempo real (predeterminado: true)
# Requiere jq. Recurre a modo sin transmisión si jq no está instalado.
# Establece en false para capturar la salida y mostrarla después de cada iteración.
export RALPH_STREAM_OUTPUT="true"
```

También puedes anular el modelo por ejecución mediante variable de entorno:

```bash
RALPH_MODEL=claude-opus-4-6 ralph ./plan.md
```

O usa el comando de configuración para la confirmación automática:

```bash
ralph config commit off   # Desactivar confirmación automática
ralph config commit on    # Activar confirmación automática
```

### Guardarrails (Lecciones Aprendidas)

Ralph mantiene un archivo `RALPH_GUARDRAILS.md` en tu directorio del proyecto que captura lecciones específicas del proyecto a través de las iteraciones. Esto evita que Claude repita los mismos errores (comandos de prueba incorrectos, violaciones de estilo, patrones rotos).

- **Se crea automáticamente** — Claude lo crea y lo actualiza cuando descubre particularidades del proyecto
- **Persiste entre iteraciones** — cada nueva sesión de Claude lo lee al inicio
- **Puedes inicializarlo manualmente** — agrega tus propias reglas antes de ejecutar Ralph:
  ```markdown
  - Ejecutar siempre `pytest -x` en lugar de `python -m pytest`
  - Usar tabulaciones para la indentación (convención del proyecto)
  ```
- **Autoadministrado** — Claude consolida las entradas cuando el archivo crece más allá de ~50 líneas

## Formato del Archivo de Plan

```markdown
# Funcionalidad: Autenticación de Usuario

## Objetivo
Agregar autenticación basada en JWT a la API.

## Requisitos
- El endpoint de inicio de sesión devuelve un token JWT
- El middleware valida los tokens en rutas protegidas
- Los tokens expiran después de 24 horas

## Criterios de Aceptación
- POST /auth/login con credenciales válidas devuelve un token
- Los endpoints protegidos retornan 401 sin un token válido
```

Consulta [Escribir Planes Efectivos](https://aaron777collins.github.io/portableralph/writing-plans/) para más ejemplos.

## Configuración

PortableRalph admite una configuración extensa a través de variables de entorno. Crea un archivo de configuración para personalizar el comportamiento:

**Crear Archivo de Configuración:**
```bash
# Unix/Linux/macOS
touch ~/.ralph.env
chmod 600 ~/.ralph.env

# Windows (PowerShell)
New-Item -Path $env:USERPROFILE\.ralph.env -ItemType File -Force
```

## Configuraciones Principales

### Configuración Principal

**Configuración de la API:**
```bash
# Configuración de la API de Claude
export CLAUDE_API_KEY="your-api-key-here"           # Requerido: Tu clave API de Claude
export CLAUDE_MODEL="claude-3-sonnet-20240229"      # Opcional: Modelo predeterminado a usar
export CLAUDE_TIMEOUT=30                            # Opcional: Tiempo de espera de la API en segundos
export CLAUDE_RETRY_COUNT=3                         # Opcional: Número de reintentos de la API
```

**Configuración de Ejecución:**
```bash
# Configuración de Comportamiento de Ralph
export RALPH_MAX_ITERATIONS=50                      # Iteraciones máximas por ejecución
export RALPH_TASK_TIMEOUT=300                       # Tiempo de espera de tareas en segundos (5 minutos)
export RALPH_LOG_LEVEL="INFO"                       # Nivel de registro: DEBUG, INFO, WARN, ERROR
export RALPH_DEBUG=false                            # Activar modo de depuración
export RALPH_TRACE=false                            # Activar modo de traza (muy detallado)
```

**Configuración de Archivos y Directorios:**
```bash
# Configuración de Rutas
export RALPH_TEMP_DIR="/tmp/ralph"                  # Directorio de archivos temporales
export RALPH_LOG_DIR="$HOME/.ralph/logs"            # Directorio de archivos de registro
export RALPH_CONFIG_DIR="$HOME/.ralph"              # Directorio de configuración
export RALPH_BACKUP_DIR="$HOME/.ralph/backups"     # Directorio de archivos de respaldo
```

**Integración con Git:**
```bash
# Configuración de Git
export RALPH_GIT_ENABLED=true                       # Activar confirmaciones automáticas de git
export RALPH_GIT_AUTO_PUSH=false                    # Empujar confirmaciones automáticamente
export RALPH_GIT_COMMIT_PREFIX="ralph:"             # Prefijo para mensajes de confirmación
export RALPH_GIT_BRANCH="ralph-dev"                 # Rama para confirmaciones de Ralph
```

## Configuración de Notificaciones

### Configuración de Notificaciones

**Configuración Global de Notificaciones:**
```bash
# Comportamiento de Notificaciones
export RALPH_NOTIFY_FREQUENCY=5                     # Notificar cada N iteraciones
export RALPH_NOTIFY_ENABLED=true                    # Activar notificaciones
export RALPH_NOTIFY_ON_START=true                   # Notificar cuando Ralph inicia
export RALPH_NOTIFY_ON_ERROR=true                   # Notificar en errores
export RALPH_NOTIFY_ON_COMPLETION=true              # Notificar cuando Ralph completa
```

**Configuración de Slack:**
```bash
# Integración con Slack
export RALPH_SLACK_ENABLED=true                     # Activar notificaciones de Slack
export RALPH_SLACK_WEBHOOK_URL="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
export RALPH_SLACK_CHANNEL="#general"               # Canal objetivo (opcional)
export RALPH_SLACK_USERNAME="Ralph"                 # Nombre de usuario del bot
export RALPH_SLACK_EMOJI=":robot_face:"             # Emoji del bot
export RALPH_SLACK_MENTION_ON_ERROR="@channel"      # Mención en errores
```

**Configuración de Discord:**
```bash
# Integración con Discord
export RALPH_DISCORD_ENABLED=true                   # Activar notificaciones de Discord
export RALPH_DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/YOUR/WEBHOOK/URL"
export RALPH_DISCORD_USERNAME="Ralph"               # Nombre de usuario del bot
export RALPH_DISCORD_AVATAR_URL="https://example.com/ralph-avatar.png"
```

**Configuración de Telegram:**
```bash
# Integración con Telegram
export RALPH_TELEGRAM_ENABLED=true                  # Activar notificaciones de Telegram
export RALPH_TELEGRAM_BOT_TOKEN="your-bot-token"    # Token del bot de @BotFather
export RALPH_TELEGRAM_CHAT_ID="your-chat-id"        # ID del chat para enviar mensajes
export RALPH_TELEGRAM_PARSE_MODE="Markdown"         # Formato del mensaje: Markdown o HTML
```

## Configuración de Correo Electrónico

### Configuración de Correo Electrónico

**Configuración SMTP:**
```bash
# Configuración SMTP
export RALPH_EMAIL_ENABLED=true                     # Activar notificaciones por correo
export RALPH_EMAIL_TO="you@example.com"             # Correo del destinatario
export RALPH_EMAIL_FROM="ralph@example.com"         # Correo del remitente
export RALPH_EMAIL_SMTP_SERVER="smtp.gmail.com"     # Servidor SMTP
export RALPH_EMAIL_PORT="587"                       # Puerto SMTP
export RALPH_EMAIL_USER="your-email@gmail.com"      # Usuario SMTP
export RALPH_EMAIL_PASS="your-app-password"         # Contraseña SMTP (usar contraseña de app para Gmail)
export RALPH_EMAIL_TLS=true                         # Activar cifrado TLS
```

**Configuración de Lote por Correo Electrónico:**
```bash
# Configuración de Envío por Lote
export RALPH_EMAIL_BATCH_ENABLED=true               # Activar envío por lote
export RALPH_EMAIL_BATCH_DELAY=300                  # Retraso del lote en segundos (5 minutos)
export RALPH_EMAIL_BATCH_MAX=10                     # Notificaciones máximas por lote
export RALPH_EMAIL_HTML=true                        # Usar plantillas de correo HTML
export RALPH_EMAIL_TEMPLATE_DIR="$HOME/.ralph/templates" # Directorio de plantillas personalizadas
```

**Configuración de SendGrid:**
```bash
# Configuración API de SendGrid
export RALPH_SENDGRID_ENABLED=true                  # Activar SendGrid
export RALPH_SENDGRID_API_KEY="SG.your-api-key"     # Clave API de SendGrid
export RALPH_EMAIL_TO="you@example.com"             # Correo del destinatario
export RALPH_EMAIL_FROM="ralph@yourdomain.com"      # Correo del remitente (debe estar verificado)
```

**Configuración de AWS SES:**
```bash
# Configuración AWS SES
export RALPH_AWS_SES_ENABLED=true                   # Activar AWS SES
export RALPH_AWS_SES_REGION="us-east-1"             # Región de AWS
export RALPH_AWS_ACCESS_KEY_ID="your-access-key"    # Clave de acceso AWS
export RALPH_AWS_SECRET_KEY="your-secret-key"       # Clave secreta AWS
export RALPH_EMAIL_TO="you@example.com"             # Correo del destinatario
export RALPH_EMAIL_FROM="ralph@yourdomain.com"      # Correo del remitente (debe estar verificado en SES)
```

## Configuraciones Avanzadas

### Configuración Avanzada

**Configuración de Rendimiento:**
```bash
# Optimización de Rendimiento
export RALPH_PARALLEL_TASKS=false                   # Activar procesamiento paralelo de tareas
export RALPH_MAX_CONCURRENT=4                       # Operaciones concurrentes máximas
export RALPH_MEMORY_LIMIT=1048576                   # Límite de memoria en KB (1GB)
export RALPH_CPU_LIMIT=200                          # Límite de CPU como porcentaje (200% = 2 núcleos)
export RALPH_IO_TIMEOUT=60                          # Tiempo de espera de operaciones de E/S en segundos
```

**Configuración de Seguridad:**
```bash
# Configuración de Seguridad
export RALPH_SECURE_MODE=true                       # Activar características de seguridad
export RALPH_MASK_SECRETS=true                      # Enmascarar secretos en registros
export RALPH_VERIFY_SSL=true                        # Verificar certificados SSL
export RALPH_ALLOWED_HOSTS="github.com,api.anthropic.com" # Hosts de red permitidos
export RALPH_DISABLE_SHELL_EXEC=false               # Desactivar ejecución de comandos de shell
```

**Configuración de Desarrollo:**
```bash
# Configuración de Desarrollo
export RALPH_DEV_MODE=false                         # Activar características de desarrollo
export RALPH_MOCK_API=false                         # Usar respuestas simuladas de API
export RALPH_SAVE_REQUESTS=false                    # Guardar solicitudes/respuestas de API
export RALPH_VALIDATE_CONFIG=true                   # Validar configuración al inicio
export RALPH_PROFILE_PERFORMANCE=false              # Activar perfilado de rendimiento
```

## Configuraciones Específicas del Entorno

### Configuraciones Específicas del Entorno

**Entorno de Producción:**
```bash
# ~/.ralph.env - Configuración de Producción
export RALPH_LOG_LEVEL="WARN"
export RALPH_DEBUG=false
export RALPH_MAX_ITERATIONS=100
export RALPH_NOTIFY_FREQUENCY=10
export RALPH_EMAIL_BATCH_DELAY=600
export RALPH_SECURE_MODE=true
export RALPH_VERIFY_SSL=true
```

**Entorno de Desarrollo:**
```bash
# ~/.ralph.env - Configuración de Desarrollo
export RALPH_LOG_LEVEL="DEBUG"
export RALPH_DEBUG=true
export RALPH_MAX_ITERATIONS=10
export RALPH_NOTIFY_FREQUENCY=1
export RALPH_DEV_MODE=true
export RALPH_PROFILE_PERFORMANCE=true
```

**Entorno de Pruebas:**
```bash
# ~/.ralph.env - Configuración de Pruebas
export RALPH_LOG_LEVEL="INFO"
export RALPH_MAX_ITERATIONS=5
export RALPH_NOTIFY_ENABLED=false
export RALPH_GIT_ENABLED=false
export RALPH_MOCK_API=true
```

## Gestión de Configuración

### Gestión de Configuración

**Carga de Configuración:**
```bash
# Ralph carga automáticamente la configuración desde:
# 1. ~/.ralph.env (configuración de usuario)
# 2. ./.ralph.env (configuración del proyecto)
# 3. Variables de entorno (máxima prioridad)

# Verificar configuración cargada
ralph --config

# Validar configuración
ralph --validate-config
```

**Plantillas de Configuración:**
```bash
# Generar configuración predeterminada
ralph --generate-config > ~/.ralph.env

# Generar configuración específica
ralph --generate-config --template production > ~/.ralph.env
ralph --generate-config --template development > ~/.ralph.env
```

## Notificaciones

Recibe notificaciones en Slack, Discord, Telegram, correo electrónico o integraciones personalizadas:

```bash
ralph notify setup  # Asistente de configuración interactivo
ralph notify test   # Probar tu configuración
```

### Plataformas Compatibles

- **Slack** - Integración con webhook
- **Discord** - Integración con webhook
- **Telegram** - API de bot
- **Correo electrónico** - SMTP, SendGrid o AWS SES
- **Personalizado** - Tus propios scripts de notificación

### Configuración de Correo Electrónico

Ralph admite múltiples métodos de entrega por correo:

#### SMTP (Gmail, Outlook, etc.)

```bash
export RALPH_EMAIL_TO="you@example.com"
export RALPH_EMAIL_FROM="ralph@example.com"
export RALPH_EMAIL_SMTP_SERVER="smtp.gmail.com"
export RALPH_EMAIL_PORT="587"
export RALPH_EMAIL_USER="your-email@gmail.com"
export RALPH_EMAIL_PASS="your-app-password"
```

**Usuarios de Gmail:** Usa una [Contraseña de Aplicación](https://support.google.com/accounts/answer/185833), no tu contraseña regular.

#### API de SendGrid

```bash
export RALPH_EMAIL_TO="you@example.com"
export RALPH_EMAIL_FROM="ralph@example.com"
export RALPH_SENDGRID_API_KEY="SG.your-api-key"
```

#### AWS SES

```bash
export RALPH_EMAIL_TO="you@example.com"
export RALPH_EMAIL_FROM="ralph@example.com"
export RALPH_AWS_SES_REGION="us-east-1"
export RALPH_AWS_ACCESS_KEY_ID="your-access-key"
export RALPH_AWS_SECRET_KEY="your-secret-key"
```

### Características de Correo Electrónico

- **Plantillas HTML** - Diseños de correo elegantes y responsivos
- **Respaldo en Texto** - Versión en texto plano para todos los correos
- **Lote Inteligente** - Reduce el spam de correos agrupando actualizaciones de progreso
- **Manejo de Prioridades** - Los errores y advertencias siempre se envían inmediatamente
- **Múltiples Destinatarios** - Direcciones de correo separadas por comas

Configura el comportamiento del lote:

```bash
export RALPH_EMAIL_BATCH_DELAY="300"  # Esperar 5 minutos antes de enviar el lote
export RALPH_EMAIL_BATCH_MAX="10"     # Enviar cuando haya 10 notificaciones en cola
export RALPH_EMAIL_HTML="true"        # Usar plantillas HTML (predeterminado)
```

Establece `RALPH_EMAIL_BATCH_DELAY="0"` para desactivar el lote y enviar cada notificación inmediatamente.

### Frecuencia de Notificaciones

Controla qué tan seguido recibes notificaciones de progreso configurando `RALPH_NOTIFY_FREQUENCY` en `~/.ralph.env`:

```bash
# Enviar notificación cada 5 iteraciones (predeterminado)
export RALPH_NOTIFY_FREQUENCY=5

# Enviar notificación cada iteración
export RALPH_NOTIFY_FREQUENCY=1

# Enviar notificación cada 10 iteraciones
export RALPH_NOTIFY_FREQUENCY=10
```

Ralph siempre envía notificaciones para:
- Inicio
- Completado
- Errores
- Primera iteración

Consulta [Guía de Notificaciones](https://aaron777collins.github.io/portableralph/notifications/) para detalles de configuración.

## Documentación

| Documento | Descripción |
|----------|-------------|
| [Guía de Uso](https://aaron777collins.github.io/portableralph/usage/) | Referencia completa de comandos |
| [Escribir Planes](https://aaron777collins.github.io/portableralph/writing-plans/) | Cómo escribir planes efectivos |
| [Notificaciones](https://aaron777collins.github.io/portableralph/notifications/) | Configuración de Slack, Discord, Telegram |
| [Cómo Funciona](https://aaron777collins.github.io/portableralph/how-it-works/) | Arquitectura técnica |
| [Guía de Pruebas](TESTING.md) | Documentación completa de pruebas |
| [Guía de Seguridad](docs/SECURITY.md) | Mejores prácticas y directrices de seguridad |

## Mejores Prácticas de Seguridad

🔒 **La seguridad es una prioridad máxima para PortableRalph.** El proyecto ha pasado auditorías de seguridad exhaustivas y sigue las mejores prácticas de la industria.

### Configuración Rápida de Seguridad

1. **Configuración Segura:**
   ```bash
   # Crear archivo de configuración seguro
   touch ~/.ralph.env
   chmod 600 ~/.ralph.env  # Solo lectura/escritura para el propietario
   ```

2. **Nunca escribas secretos en código duro:**
   ```bash
   # ✅ Bueno - usar variables de entorno
   export CLAUDE_API_KEY="your-key-here"
   export RALPH_SLACK_WEBHOOK_URL="your-webhook-here"
   
   # ❌ Malo - no escribir en código duro en scripts
   CLAUDE_API_KEY="sk-ant-api03-hardcoded"
   ```

3. **Usa solo HTTPS:**
   ```bash
   # ✅ Bueno - webhooks seguros
   export RALPH_SLACK_WEBHOOK_URL="https://hooks.slack.com/services/..."
   
   # ❌ Malo - HTTP inseguro
   export RALPH_SLACK_WEBHOOK_URL="http://insecure.example.com/webhook"
   ```

### Características de Seguridad ✅

- **✅ Validación de Entradas** - Todas las entradas de usuario están sanitizadas y validadas
- **✅ Protección contra Traversa de Ruta** - Previene el acceso fuera de los directorios intencionales  
- **✅ Prevención de Inyección de Comandos** - La ejecución parametrizada evita código malicioso
- **✅ Comunicación Solo HTTPS** - Todas las llamadas de red usan conexiones TLS seguras
- **✅ Enmascaramiento de Credenciales** - Tokens sensibles ocultos en registros y salida
- **✅ Protección contra SSRF** - URLs de webhook validadas contra rangos de IP privados
- **✅ Permisos de Archivo Seguros** - Archivos de configuración creados con permisos 600
- **✅ Sin Secretos en Código Duro** - Enfoque de configuración basado en plantillas
- **✅ Pruebas de Seguridad Exhaustivas** - 26+ pruebas de seguridad validan la protección

### Resultados de la Auditoría de Seguridad

PortableRalph ha pasado auditorías de seguridad exhaustivas con **0 vulnerabilidades críticas**:

- **Última Auditoría:** 2026-02-22
- **Estado:** ✅ **LISTO PARA PRODUCCIÓN**  
- **Cobertura:** Validación de entradas, autenticación, permisos de archivo, exposición de secretos
- **Resultados de Pruebas:** 26/26 pruebas de seguridad APROBADAS

Consulta [Informe de Auditoría de Seguridad](security-audit-report.md) para hallazgos detallados.

### Despliegue Seguro

**Desarrollo:**
```bash
# Usar iteraciones limitadas para pruebas
ralph ./plan.md build 5

# Revisar cambios antes de confirmar
git diff
```

**Producción:**
```bash
# Usar gestor de secretos (AWS, HashiCorp Vault, etc.)
# Establecer límites estrictos de iteraciones
ralph ./plan.md build 20

# Activar registro seguro
export RALPH_LOG_LEVEL="INFO"
```

## Reportar Problemas de Seguridad

¿Encontraste una vulnerabilidad de seguridad? **Por favor, reportala de manera responsable:**

1. **NO cree** un issue público en GitHub
2. **Correo electrónico:** contacto de seguridad (ver SECURITY.md)
3. **Incluye:** Descripción, pasos para reproducir, impacto potencial
4. **Plazo:** Permite 90 días para corrección antes de la divulgación pública

Para orientación completa de seguridad, consulta [Documentación de Seguridad](docs/SECURITY.md).

## Pruebas

Ralph incluye un suite de pruebas exhaustivo con 150+ pruebas automatizadas que cubren todas las plataformas:

**Unix/Linux/macOS:**
```bash
cd ~/ralph/tests
./run-all-tests.sh
```

**Windows (PowerShell):**
```powershell
cd ~\ralph\tests
.\run-all-tests.ps1
```

**Opciones de Prueba:**
```bash
# Ejecutar categorías específicas de pruebas
./run-all-tests.sh --unit-only
./run-all-tests.sh --integration-only
./run-all-tests.sh --security-only

# Salida detallada
./run-all-tests.sh --verbose

# Detener en el primer fallo
./run-all-tests.sh --stop-on-failure
```

Consulta [TESTING.md](TESTING.md) para documentación completa de pruebas que incluye:
- Estructura y organización de pruebas
- Escritura de nuevas pruebas
- Pruebas específicas de plataforma
- Integración CI/CD
- Solución de problemas

## Actualización

Ralph incluye un sistema de autoactualización:

```bash
# Actualizar a la última versión
ralph update

# Verificar actualizaciones
ralph update --check

# Listar todas las versiones
ralph update --list

# Instalar versión específica
ralph update 1.5.0

# Retroceder a la versión anterior
ralph rollback
```

## Requisitos

### Todas las Plataformas
- [Claude Code CLI](https://platform.claude.com/docs/en/get-started) instalado y autenticado
- Git (opcional, para autoconfirmaciones)

### Unix/Linux/macOS
- Shell Bash (generalmente preinstalado)

### Windows
- **Opción 1 (Recomendada):** PowerShell 5.1+ (preinstalado en Windows 10/11)
- **Opción 2:** Git for Windows (incluye Git Bash)
- **Opción 3:** WSL (Windows Subsystem for Linux)

**Nota:** Los scripts de PowerShell (`.ps1`) son completamente nativos en Windows y no requieren instalación adicional. Los scripts de Bash (`.sh`) requieren Git Bash o WSL.

## Verificación de Instalación

Después de la instalación, verifica que Ralph funcione correctamente:

**Prueba de Instalación:**
```bash
# Unix/Linux/macOS
ralph --help

# Windows (PowerShell)
ralph --help

# Windows (Símbolo del sistema)
launcher.bat ralph --help
```

**Prueba de Conexión de Claude CLI:**
```bash
claude --version
claude auth status
```

**Prueba de Funcionalidad Básica:**
```bash
# Crear un plan de prueba simple
echo "# Test Plan" > test-plan.md
echo "Create a hello.txt file with 'Hello World'" >> test-plan.md

# Ejecutar Ralph en modo plan (solo análisis)
ralph test-plan.md plan

# Limpiar
rm test-plan.md progress.md
```

**Verificar Configuración:**
```bash
# Verificar variables de entorno
env | grep RALPH

# Probar notificaciones (opcional)
ralph notify test
```

## Archivos

```
~/ralph/
├── ralph.sh               # Bucle principal (Bash)
├── ralph.ps1              # Bucle principal (PowerShell)
├── update.sh              # Sistema de autoactualización (Bash)
├── update.ps1             # Sistema de autoactualización (PowerShell)
├── notify.sh              # Despachador de notificaciones (Bash)
├── notify.ps1             # Despachador de notificaciones (PowerShell)
├── setup-notifications.sh # Asistente de configuración (Bash)
├── setup-notifications.ps1 # Asistente de configuración (PowerShell)
├── launcher.sh            # Lanzador de detección automática (Unix)
├── launcher.bat           # Lanzador de detección automática (Windows)
├── lib/
│   ├── platform-utils.sh  # Utilidades multiplataforma (Bash)
│   ├── platform-utils.ps1 # Utilidades multiplataforma (PowerShell)
│   ├── process-mgmt.sh    # Gestión de procesos (Bash)
│   └── process-mgmt.ps1   # Gestión de procesos (PowerShell)
├── PROMPT_plan.md         # Instrucciones de modo plan
├── PROMPT_build.md        # Instrucciones de modo build
├── CHANGELOG.md           # Historial de versiones
├── .env.example           # Plantilla de configuración
├── .gitattributes         # Configuración de saltos de línea
└── docs/                  # Documentación
```

### Compatibilidad Multiplataforma

PortableRalph proporciona versiones tanto en Bash (`.sh`) como PowerShell (`.ps1`) de todos los scripts:

- **Unix/Linux/macOS:** Usa scripts `.sh` directamente
- **Windows (PowerShell):** Usa scripts `.ps1` o el comando `ralph` (si se añadió a PATH)
- **Windows (Git Bash):** Usa scripts `.sh`
- **Windows (WSL):** Usa scripts `.sh`
- **Detección automática:** Usa `launcher.sh` o `launcher.bat` para seleccionar automáticamente el script correcto para tu entorno

El archivo `.gitattributes` garantiza los saltos de línea correctos entre plataformas (LF para `.sh`, CRLF para `.ps1` y `.bat`).

## Soporte para Windows

PortableRalph es totalmente multiplataforma con **soporte nativo para Windows verificado por CI**:

> **✅ Verificado por CI:** La compatibilidad con Windows se prueba automáticamente en cada push mediante GitHub Actions con **31/31 pruebas aprobadas**. Consulta el distintivo de [Compatibilidad con Windows](https://github.com/aaron777collins/portableralph/actions/workflows/windows-test.yml) arriba.

### Pruebas CI de Windows

El flujo de trabajo de GitHub Actions [`windows-test.yml`](.github/workflows/windows-test.yml) proporciona validación integral para Windows con **5 trabajos de prueba automatizados**:

1. **Pruebas de Scripts de PowerShell:** Validación de sintaxis, parámetros de ayuda/versión, verificación de dependencias para todos los archivos `.ps1` (install.ps1, ralph.ps1, notify.ps1, setup-notifications.ps1)
2. **Pruebas de Archivos Batch:** Funcionalidad de `launcher.bat` y compatibilidad con el entorno de CMD de Windows  
3. **Pruebas de Integración:** Interoperabilidad batch-PowerShell y simulación de flujo de trabajo extremo a extremo
4. **Pruebas del Sistema de Notificaciones:** Pruebas en seco de notificaciones y verificación de informes de estado
5. **Características Específicas de Windows:** Acceso al registro, servicios, variables de entorno, operaciones de sistema de archivos

**Disparadores Manuales del Flujo de Trabajo:** Puedes disparar manualmente el flujo de trabajo de CI de Windows yendo a la [pestaña de Actions](https://github.com/aaron777collins/portableralph/actions/workflows/windows-test.yml) y haciendo clic en "Run workflow".

El CI genera un artefacto de informe de compatibilidad detallado que documenta los resultados de las pruebas y la información de la plataforma.

### Opciones de Instalación

1. **PowerShell (Recomendada):** Soporte nativo para Windows, sin dependencias
   ```powershell
   irm https://raw.githubusercontent.com/aaron777collins/portableralph/master/install.ps1 | iex
   ```

2. **Git Bash:** Usa scripts de Bash en Windows
   ```bash
   curl -fsSL https://raw.githubusercontent.com/aaron777collins/portableralph/master/install.sh | bash
   ```

3. **WSL:** Ejecuta la versión de Linux en Windows Subsystem for Linux

### Requisitos de Windows

- **PowerShell 5.1+** (preinstalado en Windows 10/11)
  - Probado en PowerShell 5.1, Windows PowerShell y PowerShell 7+
  - Manejo de JSON, solicitudes web y operaciones de sistema de archivos verificadas
- **Directiva de Ejecución:** Ejecuta `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser` si los scripts están bloqueados
- **Claude Code CLI:** Debe estar instalado y autenticado  
- **Git for Windows:** Recomendado para funciones de control de versiones
- **Características de Windows:** Acceso al registro, consulta de servicios y variables de entorno (probadas automáticamente en CI)

### Manejo de Rutas

PortableRalph maneja automáticamente las convenciones de rutas de Windows y Unix:
- **Windows:** `C:\Users\name\project` o `C:/Users/name/project`
- **Unix:** `/home/name/project`
- **WSL:** `/mnt/c/Users/name/project` (convertido automáticamente)

### Gestión de Procesos

Las utilidades de gestión de procesos específicas de Windows están disponibles en `lib/process-mgmt.ps1`:
- `Start-BackgroundProcess` - Equivalente a `nohup`
- `Stop-ProcessSafe` - Equivalente a `kill`
- `Get-ProcessList` - Equivalente a `ps`
- `Find-ProcessByPattern` - Equivalente a `pgrep`
- `Stop-ProcessByPattern` - Equivalente a `pkill`

### Configuración

Ubicación del archivo de configuración:
- **Windows:** `%USERPROFILE%\.ralph.env` (ej., `C:\Users\YourName\.ralph.env`)
- **Unix:** `~/.ralph.env` (ej., `/home/yourname/.ralph.env`)

### Solución de Problemas

**Directiva de Ejecución de PowerShell:**
Si ves "running scripts is disabled", ejecuta PowerShell como Administrador y ejecuta:
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**Saltos de Línea:**
El archivo `.gitattributes` garantiza los saltos de línea correctos. Si editas archivos manualmente:
- Los archivos `.sh` deben usar saltos de línea LF (Unix)
- Los archivos `.ps1` y `.bat` deben usar saltos de línea CRLF (Windows)

## Para Agentes de IA

Invoca Ralph desde otro agente de IA:

**Unix/Linux/macOS:**
```bash
# Planificar primero (analiza la base de código, crea lista de tareas, sale después de 1 iteración)
ralph /absolute/path/to/plan.md plan

# Luego construir (implementa tareas una por una hasta completar)
ralph /absolute/path/to/plan.md build
```

**Windows (PowerShell):**
```powershell
# Planificar primero
ralph C:\absolute\path\to\plan.md plan

# Luego construir
ralph C:\absolute\path\to\plan.md build
```

**Importante:**
- El modo plan se ejecuta una vez y sale automáticamente (establece el estado a `IN_PROGRESS`)
- El modo build se repite hasta que todas las tareas estén completas, luego escribe `RALPH_DONE` en su propia línea en la sección de Estado
- Solo el modo build debería escribir el marcador de finalización
- El marcador debe estar en su propia línea para ser detectado (no en línea con otro texto)

## Para Mantenedores: Flujos de Trabajo CI/CD

PortableRalph utiliza GitHub Actions para pruebas y despliegue automatizado:

### Flujos de Trabajo CI

| Flujo de Trabajo | Archivo | Propósito |
|----------|------|---------|
| **Compatibilidad con Windows** | `.github/workflows/windows-test.yml` | Prueba scripts de PowerShell, archivos batch e integración de Windows |
| **Pruebas CI** | `.github/workflows/ci.yml` | Pruebas generales de compatibilidad y linting |
| **Suite de Pruebas** | `.github/workflows/test.yml` | Ejecución completa de la suite de pruebas |
| **Documentación** | `.github/workflows/docs.yml` | Despliegue de documentación MkDocs |
| **Lanzamiento** | `.github/workflows/release.yml` | Lanzamientos de versiones |

### Detalles de Pruebas CI de Windows

El flujo de trabajo de CI para Windows (`windows-test.yml`) verifica automáticamente:

1. **Pruebas de Scripts de PowerShell**
   - Validación de sintaxis para todos los archivos `.ps1`
   - Pruebas de parámetros de ayuda/versión
   - Verificación de dependencias

2. **Pruebas de Archivos Batch**
   - Funcionalidad de `launcher.bat`
   - Compatibilidad con el entorno de CMD de Windows

3. **Pruebas de Integración**
   - Interoperabilidad batch-PowerShell
   - Simulación de flujo de trabajo extremo a extremo

4. **Pruebas del Sistema de Notificaciones**
   - Pruebas en seco de notificaciones
   - Verificación de informes de estado

### Ejecutar CI Localmente

Para probar cambios de Windows localmente antes de enviarlos:

```powershell
# Probar sintaxis de PowerShell
$scriptContent = Get-Content "ralph.ps1" -Raw
[System.Management.Automation.PSParser]::Tokenize($scriptContent, [ref]@())

# Probar funcionalidad básica
.\ralph.ps1 -Help
.\install.ps1 -Help
```

## Artefactos CI

El CI de Windows genera un artefacto `windows-compatibility-report.md` que contiene:
- Resumen de resultados de pruebas
- Versión de PowerShell probada
- Información de la plataforma
- Recomendaciones

## Solución de Problemas (Referencia Rápida)

### Problemas de Windows

| Problema | Solución |
|---------|----------|
| Scripts bloqueados | `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser` |
| Errores de saltos de línea (`'\r': command not found`) | `git config core.autocrlf input` y volver a clonar |
| `claude: command not found` | Instala [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) |
| Problemas de rutas en WSL | Usa rutas `/mnt/c/...`, no `C:\...` |

### Todas las Plataformas

| Problema | Solución |
|---------|----------|
| Comando Ralph no encontrado | Agrega alias: `alias ralph="~/ralph/ralph.sh"` |
| Tareas que se repiten | Revisa errores de build/prueba; marca tareas completadas manualmente |
| Notificaciones fallando | Ejecuta `ralph notify test` para diagnosticar |

Consulta [Guía de Solución de Problemas](docs/TROUBLESHOOTING.md) para soluciones detalladas.

Para solución de problemas integral que incluya:
- **Problemas específicos de plataforma** (PowerShell de Windows, permisos de Unix, Gatekeeper de macOS)
- **Problemas de instalación** (problemas de dependencias, fallos de red, errores de configuración)
- **Problemas en tiempo de ejecución** (bucles de tareas, errores de permisos, problemas de rendimiento)
- **Depuración avanzada** (análisis de registros, diagnósticos del sistema, perfilado de rendimiento)

## Licencia

MIT

---

Basado en [The Ralph Playbook](https://github.com/ghuntley/how-to-ralph-wiggum) por [@GeoffreyHuntley](https://x.com/GeoffreyHuntley).
