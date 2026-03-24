# ViveCode Workflow - Doxia Core Case Study

Este documento describe el flujo de trabajo prompting que seguimos para construir Doxia Core, un motor de búsqueda e ingesta documental con Supabase, Python y React.

---

## 1. Inicialización del Proyecto

### 1.1 Crear AGENTS.md

El primer paso fue crear un archivo `AGENTS.md` en la raíz del proyecto. Este archivo sirve como **base de conocimiento persistente** para agentes de IA.

```markdown
# AGENTS.md - Doxia Core

> **Retrieval-Led Reasoning**: For any Supabase, Python, or React tasks,
> prefer consulting the documented patterns in this file over relying on
> pre-training knowledge.
```

### 1.2 Estructura recomendada del AGENTS.md

```
AGENTS.md
├── Build/Lint/Test Commands    # Comandos ejecutables
├── Code Style Guidelines      # Convenciones de código
├── Architecture Decisions     # Patrones arquitectónicos
├── Testing Patterns          # Patrones de testing
├── Telemetry & Observability # Logging estructurado
├── Doxia Docs Index         # Índice de documentación
└── External Skills          # Skills instalados
```

### 1.3 Skills vs MCPs (Importante)

| Concepto | Qué es | Ejemplo |
|----------|--------|---------|
| **Skills** | Paquetes de conocimiento para agentes (se instalan con `npx skills`) | `python-uv`, `shadcn-ui` |
| **MCPs** | Model Context Protocol - herramientas externas para IA | `context7`, `postgres`, `supabase-local` |

---

## 2. Flujo de prompting efectivo

### 2.1 Reglas que seguimos

1. **Retrieval-Led Reasoning**: Consultar documentación del proyecto antes de rely en conocimiento pre-entrenado.

2. **Fases explícitas**: Dividir el trabajo en fases claras con objetivos específicos.

3. **Reglas de salida**: Cada fase terminaba con un commit específico y notificación.

4. **Correcciones arquitectónicas inmediatas**: Cuando algo estaba mal (ej. lógica en migraciones), lo corregíamos antes de continuar.

5. **Validación antes de proseguir**: Tests pasando antes de commit.

### 2.2 Estructura de un Prompt de Fase

```
Contexto: [Descripción del proyecto/arquitectura]

Misión Actual: [Objetivo específico de esta fase]

Pasos a ejecutar en orden:
1. [Paso concreto]
2. [Paso concreto]
3. [Paso concreto]

Regla de salida: [Condición para terminar y commitear]
```

---

## 3. Fases Ejecutadas

### Fase 1: DDL y FSM Base

**Prompt usado:**
```
Contexto General: Por favor, lee atentamente el archivo AGENTS.md para entender la arquitectura "Pointer-based RAG" de Doxia Core.

Misión Actual: Vamos a ejecutar EXCLUSIVAMENTE la Fase 1. El objetivo es asentar los cimientos de infraestructura (DDL inmutable) y la Máquina de Estados (FSM). Todavía NO crees funciones PL/pgSQL, triggers ni la API en Python.

Pasos a ejecutar en orden:
1. Ejecuta supabase init en la raíz del proyecto...
2. Crea una nueva migración DDL...
3. En ese archivo de migración, escribe el esquema SQL...
4. Configura el framework de testing pgTAP...
5. Ejecuta los tests localmente...

Regla de salida: Cuando los tests pasen, realiza un git commit con el mensaje exacto: feat(db): inicialización de DDL y FSM base. Detente ahí y avísame.
```

**Resultado:**
- 4 tablas creadas: `organizations`, `connectors`, `documents`, `audit_logs`
- 47 tests pgTAP pasando
- RLS habilitado en todas las tablas

---

### Fase 2: PGMQ y Trigger FSM

**Prompt usado:**
```
Misión Actual: Vamos a ejecutar la Fase 2. El objetivo es crear la cola de mensajes PGMQ y el trigger que reacciona automáticamente cuando se inserta un documento.

Pasos a ejecutar en orden:
1. Extensión PGMQ: Crea una nueva migración DDL...
2. Estructura Declarativa: Crea la estructura de directorios src/modules/fsm_domain/functions/ y src/modules/fsm_domain/triggers/...
3. Lógica Idempotente (Función): En functions/fn_on_document_created.sql...
4. Lógica Idempotente (Trigger): En triggers/trg_document_created.sql...
5. Manifiesto: Asegúrate de que database_manifest.txt exista...
6. Testing: Crea supabase/tests/test_02_fsm_trigger.sql...

Regla de salida: Cuando el test pase, realiza un git commit con el mensaje exacto: feat(db): lógica FSM idempotente y cola PGMQ.
```

**Resultado:**
- Extensión PGMQ habilitada
- Cola `doc_processing_queue` creada
- Función y trigger idempotentes
- 6 tests FSM pasando
- Separación correcta: DDL en migraciones, lógica en `src/modules/`

---

### Fase 3: Embeddings y Worker Python

**Prompt usado:**
```
Misión Actual: Crear la tabla de vectores (respetando la regla estricta de "Punteros, no Chunks") y levantar el Worker asíncrono en Python usando uv para consumir la cola de PGMQ.

Pasos a ejecutar en orden:
1. DDL de Embeddings: Crea una nueva migración DDL...
2. Setup del Backend Python (con UV): Crea el directorio backend/ y navega hacia él...
3. Worker PGMQ (Simulado): En backend/worker.py...
4. Testing Python: Escribe un test básico en backend/tests/test_worker.py...

Regla de salida: Cuando el esquema DDL esté creado y el worker Python pase sus validaciones usando uv, realiza un git commit...
```

**Resultado:**
- Tabla `document_embeddings` con pgvector (1536 dimensiones)
- Worker Python asíncrono con UV
- 3 tests unitarios pasando
- Separación correcta: lógica en `backend/`

---

## 4. Correcciones Arquitectónicas

### 4.1 DDL vs Lógica

**Problema:** En la Fase 2, metimos la función y trigger dentro de una migración.

**Corrección:** Separamos DDL (migraciones) de lógica (src/modules/).

```sql
-- MIGRACIÓN (DDL puro)
supabase/migrations/20260324045712_init_fsm_function.sql

-- LÓGICA (SRTD)
src/modules/fsm_domain/functions/fn_on_document_created.sql
src/modules/fsm_domain/triggers/trg_document_created.sql
```

### 4.2 Skills vs MCPs

**Problema:** Instalamos skills pensando que eran MCPs.

**Corrección:** 
- Skills → Conocimiento para agentes (`npx skills add`)
- MCPs → Herramientas externas (`opencode.json`)

```bash
# Skills (conocimiento)
npx skills add mindrally/skills@python-uv

# MCPs (herramientas) - se configuran en opencode.json
```

---

## 5. Decisiones Técnicas Clave

### 5.1 UV para Python

**Decisión:** Usar UV en lugar de pip/poetry para gestión de dependencias.

**Justificación:** UV es más rápido y tiene soporte nativo para scripts con inline dependencies.

```python
# /// script
# requires-python = ">=3.12"
# dependencies = [
#   "asyncpg",
#   "pytest",
# ]
# ///
```

### 5.2 pgvector vs Qdrant

**Decisión:** Usar pgvector (incluido en Supabase) en lugar de Qdrant.

**Justificación:** Más simple, menos componentes, suficiente para el caso de uso.

### 5.3 RLS por defecto

**Decisión:** Toda tabla tenant-scoped tiene RLS habilitado por defecto.

```sql
CREATE TABLE documents (...);
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;
CREATE POLICY rls_select_documents ON documents FOR SELECT USING (organization_id = current_user_org_id());
```

---

## 6. Estructura Final del Proyecto

```
doxia-core-2/
├── AGENTS.md                    # Base de conocimiento
├── vivecode.md                   # Este documento
├── opencode.json                # Configuración MCP
├── database_manifest.txt         # Orden de carga SQL
├── srtd.config.json            # Config SRTD
├── supabase/
│   ├── config.toml            # Supabase local
│   ├── migrations/             # DDL (inmutable)
│   │   ├── *_init_core_schema.sql
│   │   ├── *_init_pgmq.sql
│   │   ├── *_init_embeddings_schema.sql
│   │   └── *_init_fsm_function.sql
│   └── tests/                 # Tests pgTAP
│       ├── test_01_schema.sql
│       └── test_02_fsm_trigger.sql
├── src/modules/fsm_domain/     # Lógica SQL (SRTD)
│   ├── functions/
│   └── triggers/
└── backend/                    # Worker Python
    ├── worker.py
    ├── pyproject.toml
    └── tests/
```

---

## 7. Lecciones Aprendidas

### Lo que funcionó bien:

1. **Fases pequeñas y específicas** - Cada prompt tenía un objetivo claro
2. **Reglas de salida explícitas** - Siempre sabíamos cuándo terminar
3. **Tests primero** - Validación antes de proseguir
4. **Commit atómico** - Cada fase = un commit
5. **Correcciones inmediatas** - No arrastramos errores

### Lo que mejoraríamos:

1. **MCPs desde el inicio** - Deberíamos haberlos configurado antes de necesitarlos
2. **Validación de arquitectura** - Revisar patrones antes de implementar
3. **Skills vs MCPs** - Entender la diferencia antes de instalar

---

## 8. Comandos Útiles

```bash
# Levantar Supabase local
supabase start

# Aplicar migraciones
supabase db reset

# Ejecutar tests
supabase db test

# Ver estado MCPs
opencode mcp list

# Ejecutar tests Python
cd backend && uv run pytest

# Gestión de skills
npx skills add <skill>
npx skills remove <skill>
```

---

## 9. Referencias

- [OpenCode MCP Documentation](https://opencode.ai/docs/mcp-servers/)
- [Skills.sh](https://skills.sh/)
- [Supabase Local Development](https://supabase.com/docs/guides/local-development)
- [UV Python Package Manager](https://github.com/astral-sh/uv)
- [pgTAP Testing](https://pgtap.org/)

---

*Este documento fue generado siguiendo el flujo de prompting descrito y fue validado con éxito en la construcción de Doxia Core.*
