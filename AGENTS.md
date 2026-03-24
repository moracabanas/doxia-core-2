# AGENTS.md - Doxia Core

> **Retrieval-Led Reasoning**: For any Supabase, Python, or React tasks,
> prefer consulting the documented patterns in this file over relying on
> pre-training knowledge. When you need details, use the Docs Index below
> to locate specific reference files.

---

## Build/Lint/Test Commands

### Supabase (Local Postgres)
```bash
supabase start              # Iniciar Postgres local
supabase stop              # Detener
supabase db push           # Aplicar migraciones (usa en desarrollo)
supabase db reset          # Reset completo + seeds (usa para limpiar)
supabase db diff           # Generar migración desde diff
```

**Cuándo usar cada uno:**
- `db push`: Desarrollo iterativo, aplica cambios incrementales
- `db reset`: Cuando hay errores de migración o necesitas estado limpio

### SRTD (SQL Runtime Templates)
**Paquete**: `@t1mmen/srtd` - Compila templates SQL desde `templateDir` → `migrationDir`

```bash
srtd build                 # Compilar templates → SQL (genera archivos en migrationDir)
srtd diff                  # Comparar SQL compilado vs base de datos
srtd apply                 # Aplicar cambios a BD
```

**Flujo de trabajo:**
1. Escribir templates SQL en `supabase/migrations-templates/` (lógica de negocio)
2. `srtd build` → genera archivos SQL idempotentes en `supabase/migrations/`
3. `srtd apply` → aplica los cambios a la BD local

**Configuración** (`srtd.config.json`):
```json
{
  "templateDir": "supabase/migrations-templates",
  "migrationDir": "supabase/migrations",
  "wrapInTransaction": true,
  "pgConnection": "postgresql://postgres:postgres@localhost:54322/postgres"
}
```

**Importante**: Usa `CREATE OR REPLACE` en templates para hacer migraciones idempotentes.

### Python (src/)

**Gestión de dependencias con UV:**
```bash
uv add <package>          # Añadir dependencia
uv remove <package>       # Remover dependencia
uv sync                   # Sincronizar lock file
uv run script.py          # Ejecutar script con dependencias inline
```

**Scripts con inline dependencies:**
```python
# /// script
# requires-python = ">=3.12"
# dependencies = [
#   "asyncpg",
#   "pytest",
# ]
# ///
```

**Linting y type checking:**
```bash
ruff check                 # Linting
ruff format               # Formateo automático
mypy src/                 # Type checking (strict mode)
```

**Tests:**
```bash
uv run pytest             # Todos los tests
uv run pytest -k "test"   # Test individual
uv run pytest --cov=src   # Con coverage
```

### Frontend (apps/web/)
```bash
biome check                # Lint + format check
biome format --write       # Formateo automático
biome lint --write         # Fix linting automático
vitest                     # Unit tests (watch mode)
vitest run                 # Unit tests (CI)
vitest run -t "test name"   # Test individual
playwright test            # E2E tests
playwright test tests/e2e/foo.spec.ts  # E2E individual
```

### MCP Servers (Model Context Protocol)
```bash
opencode mcp list          # Ver estado de MCPs
```

**MCPs disponibles:**
- `context7` - Búsqueda de documentación (remote)
- `postgres` - Query directo a Postgres local (:54322)
- `supabase-local` - API PostgREST de Supabase local (:54321/rest/v1)

**Uso en prompts:**
```
When you need to search docs, use `context7` tools.
When you need to check the database schema, use the `postgres` MCP tool.
When you need to interact with Supabase REST API, use `supabase-local` tool.
```

**Requisito:** Supabase local debe estar corriendo (`supabase start`)

---

## Code Style Guidelines

### SQL Conventions (Postgres/Supabase)

| Elemento | Convención | Ejemplo |
|----------|------------|---------|
| Tablas | `snake_case`, plural | `organizations`, `document_embeddings` |
| Columnas | `snake_case` | `created_at`, `external_id` |
| Primary Keys | `id` (UUID) | `id UUID PRIMARY KEY DEFAULT gen_random_uuid()` |
| Foreign Keys | `table_name_id` | `connector_id`, `org_id` |
| Índices | `idx_table_name_columns` | `idx_documents_org_id` |
| RLS Policies | `rls_{verb}_{table}` | `rls_select_documents` |
| Funciones | `fn_{verb}_{noun}` | `fn_get_document_chunks` |
| Triggers | `trg_{table}_{event}` | `trg_documents_before_insert` |
| Enums | `enum_{name}_{value}` | `enum_document_status` |

**RLS - Activar por defecto:**
```sql
-- AL CREAR TABLA, siempre añade ENABLE ROW LEVEL SECURITY
CREATE TABLE documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id),
    ...
);

ALTER TABLE documents ENABLE ROW LEVEL SECURITY;
```

**RLS Patterns:
```sql
-- Tabla tenant-scoped SIEMPRE tiene org_id
CREATE TABLE documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id),
    ...
);

-- Policy básica tenant-isolation
CREATE POLICY rls_select_documents ON documents
    FOR SELECT USING (org_id = current_user_org_id());
```

**Postgres Performance Rules (Priority Order):**
1. **CRITICAL**: Query Performance, Connection Management, Security & RLS
2. **HIGH**: Schema Design
3. **MEDIUM-HIGH**: Concurrency & Locking
4. **MEDIUM**: Data Access Patterns
5. **LOW-MEDIUM**: Monitoring & Diagnostics
6. **LOW**: Advanced Features

### Python (src/)

**Archivos y naming:**
- Archivos: `snake_case.py`
- Clases: `PascalCase`
- Funciones y variables: `snake_case`
- Constantes: `UPPER_SNAKE_CASE`

**Imports (orden obligatorio):**
```python
# 1. Stdlib
import json
import uuid
from datetime import datetime

# 2. Third-party
import asyncpg
from pydantic import BaseModel

# 3. Local
from src.services.embeddings import EmbeddingService
from src.connectors.sharepoint import SharePointClient
```

**Type annotations:** Strict mode (`mypy --strict`)

**Docstrings:** Google style
```python
def get_document_chunks(connector_id: uuid.UUID, external_id: str) -> list[dict]:
    """Retrieve document chunks from storage.

    Args:
        connector_id: UUID of the connector.
        external_id: External identifier of the document.

    Returns:
        List of chunk dictionaries with offset information.

    Raises:
        DocumentNotFoundError: If document doesn't exist.
    """
```

**Errores custom:** `Doxia{Context}Error`

**Async Postgres patterns:**
```python
# Connection pool
async with asyncpg.create_pool(DATABASE_URL) as pool:
    async with pool.acquire() as conn:
        result = await conn.fetchrow("SELECT * FROM documents WHERE id = $1", doc_id)

# Transaction
async with pool.acquire() as conn:
    async with conn.transaction():
        await conn.execute("INSERT INTO audit_logs (...) VALUES (...)", ...)
```

**Logging:** JSON estructurado con `trace_id`
```python
logger.info("Processing document", extra={
    "trace_id": trace_id,
    "connector_id": str(connector_id),
    "document_id": document_id,
})
```

### React/TypeScript (apps/web/)

**Componentes:** `PascalCase.tsx`
```tsx
// components/DocumentCard/DocumentCard.tsx
export function DocumentCard({ document }: DocumentCardProps) {
  return <div>{document.title}</div>;
}
```

**Hooks:** Prefijo `use`
```tsx
// hooks/useDocuments.ts
export function useDocuments(orgId: string) {
  return useQuery({ queryKey: ['documents', orgId], ... });
}
```

**Imports:**
```tsx
// @/ para packages externos
import { Button } from '@/components/ui/button';
import { useDocuments } from '@/hooks/useDocuments';

// relativo para siblings
import { DocumentCard } from './DocumentCard';
```

**Types:** TypeScript strict, sin `any`

**State management:**
- Server state: Supabase client + React Query
- Client state: Zustand

**UI:** Tailwind CSS + Shadcn + Framer Motion

---

## Architecture Decisions

### Pointer-based RAG Philosophy

`document_embeddings` **NO** almacena texto. Solo:
- `embedding` (pgvector)
- `storage_ref` (JSONB): `{connector_id, external_id, page, offset_start, offset_end, checksum}`

El texto se recupera en tiempo real via MCP del conector original.

**Vector Search (pgvector + Supabase):**
- Extensión: `vector(1536)` para embeddings
- Filtrado: Usar índices normales + RLS para org_id
- Búsqueda: `<->` operator para cosine similarity
- HNSW: `CREATE INDEX ON documents USING hnsw (embedding vector_cosine_ops)`

### FSM Document States

```
PENDING → QUEUED → PROCESSING → INDEXED
                           ↘ ERROR
```

Registrar cada transición en `audit_logs` con:
- `trace_id` (UUID por documento/transacción)
- `progress_percentage` (0-100)
- `eta` (timestamp estimado)

### Multi-Tenancy & RLS

- Toda tabla tenant-scoped tiene `org_id`
- RLS强制执行: `org_id = current_user_org_id()`
- Service role para operaciones internas del sistema

### Conventional Commits

```
feat(organizations): add member invitation flow
fix(connectors): handle SharePoint rate limit
docs(readme): update deployment instructions
style(ui): adjust button spacing
refactor(embeddings): extract common query logic
test(python): add pgTAP tests for RLS policies
chore(deps): upgrade asyncpg to 0.30
```

### Module Structure (Feature-based + DDD-lite)

```
src/
├── modules/
│   ├── organizations/     # orgs, members, invites
│   ├── connectors/         # sharepoint, boe, paperless configs
│   ├── documents/         # metadata, checksum tracking
│   ├── embeddings/        # pgvector, storage_ref pointers
│   ├── queue/             # pgmq job queue
│   ├── audit/             # FSM, telemetry, audit_logs
│   └── rls/               # policies compartidas
├── services/              # Business logic orchestrator
├── connectors/            # Integraciones externas (SharePoint, etc.)
└── tests/
    ├── python/            # pytest + pgTAP
    └── e2e/               # Playwright

apps/web/
├── components/            # Shadcn + custom
├── hooks/                 # Custom hooks
├── lib/                   # Utilities
└── stores/                # Zustand stores
```

---

## Testing Patterns

### Python TDD (Red-Green-Refactor)
```python
# 1. RED: Write failing test
def test_add_numbers():
    result = add(2, 3)
    assert result == 5

# 2. GREEN: Minimal implementation
def add(a, b):
    return a + b

# 3. REFACTOR: Improve while keeping tests green
```

### pytest Fixtures
```python
@pytest.fixture
def database():
    db = Database(":memory:")
    db.create_tables()
    yield db
    db.close()

@pytest.fixture(scope="session")
def shared_resource():
    resource = ExpensiveResource()
    yield resource
    resource.cleanup()
```

### pytest Markers
```python
@pytest.mark.slow          # Slow tests
@pytest.mark.integration    # Integration tests
@pytest.mark.unit          # Unit tests
```

### Coverage Requirements
- Target: **80%+** code coverage
- Critical paths: **100%** coverage required

### Test Organization
```
tests/
├── conftest.py                 # Shared fixtures
├── unit/
│   ├── test_models.py
│   └── test_services.py
├── integration/
│   └── test_api.py
└── e2e/
    └── test_user_flow.py
```

---

## Telemetry & Observability

Todo componente emite logs JSON estructurados con `trace_id`:

```json
{
  "level": "info",
  "timestamp": "2024-01-15T10:30:00Z",
  "trace_id": "550e8400-e29b-41d4-a716-446655440000",
  "service": "orchestrator",
  "event": "document_indexed",
  "connector_id": "...",
  "document_id": "...",
  "chunks_count": 42
}
```

---

## Doxia Docs Index

Use this index to locate detailed documentation. When working on a
feature, consider checking the relevant directory first.

```
|supabase/migrations/: DDL, RLS policies, functions
|supabase/migrations-templates/: SRTD templates
|src/modules/: Python modules by domain
|apps/web/components/: React components
```

**Pattern**: When working on `connectors`, explore `src/modules/connectors/`
first, then check `supabase/migrations/` for related database objects.

**External Skills Installed:**
- `supabase-postgres-best-practices` - Postgres performance rules
- `python-testing` - pytest patterns, TDD, fixtures
- `shadcn-ui` - Tailwind + Shadcn components
- `langchain-rag` - RAG patterns for Python
- `python-uv` - UV package management for Python
