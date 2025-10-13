# Backend Documentation — app

This document describes the backend service implemented in `app/`. It covers architecture, API endpoints, persistence, concurrency & scheduling semantics, error handling, and instructions for running & testing locally.

Table of contents
- Overview
- Tech stack
- Running locally
- Environment / dependencies
- Database / schema
- API endpoints (examples)
- Concurrency & scheduling model
- Background scheduler
- Correlation ID middleware & error handling
- Observability & debugging
- Contributing / extending

---

## Overview

The `app` directory implements a small Task Manager REST API built with FastAPI and SQLite. The service provides CRUD operations for tasks and includes a scheduling mechanism that allows writes (create/update/delete) to be executed at a future RFC3339 timestamp. To avoid lost writes in concurrent scenarios, each modifying request carries a `request_timestamp` used for optimistic concurrency control.

Key files
- `app/main.py` — FastAPI application, middleware, startup/shutdown lifecycle, and background scheduler registration.
- `app/routes/tasks.py` — API endpoints for tasks (create, list, get, update, delete).
- `app/core/db.py` — SQLite helpers, schema initialization, scheduled ops processing logic, and timestamp utilities.
- `app/core/models.py` — Pydantic request/response models.
- `app/requirements.txt` — Python package dependencies.
- `app/tasks.db` — SQLite database file (created by `init_db()`).

---

## Tech stack

- Python 3.10+ (or compatible)
- FastAPI (web framework)
- Uvicorn (ASGI server)
- SQLite (embedded storage)
- Pydantic (request/response models)

Dependencies are listed in `app/requirements.txt`.

---

## Running locally

1. Create a virtual environment and install dependencies:
```/dev/null/run-steps.sh#L1-6
python -m venv .venv
source .venv/bin/activate
pip install -r app/requirements.txt
```

2. Start the app with uvicorn:
```/dev/null/run-uvicorn.sh#L1-3
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

3. The API will be available at `http://127.0.0.1:8000`. The OpenAPI docs are at `http://127.0.0.1:8000/docs`.

Notes:
- On startup the app calls `init_db()` which will create `app/tasks.db` if it doesn't exist and will ensure the required tables and indices are present.
- The background scheduler is started on startup and cancelled on shutdown.

---

## Environment / dependencies

Requirements are in `app/requirements.txt`. There are no special environment variables required by the app itself; the database path is derived relative to the package (the file `app/core/db.py` sets `DB_PATH` to `app/tasks.db`).

---

## Database / schema

The app uses a SQLite database with the following tables (created by `init_db()`):

- `tasks`
  - `id` INTEGER PRIMARY KEY AUTOINCREMENT
  - `title` TEXT NOT NULL
  - `content` TEXT
  - `due_date` TEXT (YYYY-MM-DD or NULL)
  - `done` INTEGER NOT NULL DEFAULT 0
  - `created_at` TEXT (RFC3339 UTC)
  - `updated_at` TEXT (RFC3339 UTC)
  - `last_request_ts` TEXT (RFC3339 UTC)
  - UNIQUE(title, due_date)
  - indices: `idx_tasks_due_date`, `idx_tasks_updated_at`

- `users` (present but not used by routes in this service)
  - `id`, `username` (unique), `email` (unique), `password_hash`, `is_active`, `created_at`, `updated_at`
  - indices: `idx_users_username`, `idx_users_email`

- `scheduled_ops` (scheduling queue)
  - `id` INTEGER PRIMARY KEY AUTOINCREMENT
  - `task_id` INTEGER (nullable when creating a new task)
  - `op_type` TEXT (values: `'create' | 'update' | 'delete'`)
  - `payload` TEXT (JSON-serialized payload for the operation)
  - `execute_at` TEXT (RFC3339 UTC time when the op should be executed)
  - `request_ts` TEXT (original request timestamp)
  - `created_at` TEXT (when the op was scheduled)
  - index: `idx_schedops_execute_at`

The `scheduled_ops` table is the mechanism used to defer operations to a future timestamp.

---

## API Endpoints

Base prefix: `/tasks`

All requests that mutate state must include a `request_timestamp` (RFC3339 UTC) in the request body. This timestamp is used for optimistic concurrency control and for scheduling future operations.

1) Create task
- POST `/tasks`
- Request model: `TaskCreate` — `{ title, content?, due_date?, request_timestamp }`

Example immediate create (request_timestamp <= now):
```/dev/null/curl-create-now.sh#L1-10
curl -X POST http://127.0.0.1:8000/tasks \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Read book",
    "content": "Read chapters 1-3",
    "due_date": "2025-09-30",
    "request_timestamp": "2025-09-25T20:00:00Z"
  }'
```

Example scheduled create (request_timestamp in the future):
```/dev/null/curl-create-scheduled.sh#L1-10
curl -X POST http://127.0.0.1:8000/tasks \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Future task",
    "content": "Run in future",
    "due_date": "2025-10-01",
    "request_timestamp": "2025-10-01T12:00:00Z"
  }'
# Returns: { "scheduled": true, "execute_at": "...", "op_id": 123 }
```

2) List tasks
- GET `/tasks`
- Response: array of task objects (see `TaskOut`)

Example:
```/dev/null/curl-list.sh#L1-5
curl http://127.0.0.1:8000/tasks
```

3) Get task
- GET `/tasks/{task_id}`
- Response: single `TaskOut` object or 404 if not found

4) Update task
- PUT `/tasks/{task_id}`
- Request model: `TaskUpdate` — optional `title`, `content`, `due_date`, `done`, plus required `request_timestamp`
- Semantic:
  - If `request_timestamp` <= stored `last_request_ts` for the task: 409 Conflict (timestamp conflict).
  - If `request_timestamp` > now: scheduled update (enqueued into `scheduled_ops`).
  - If `request_timestamp` <= now: immediate update applied.

Example immediate update:
```/dev/null/curl-update-now.sh#L1-10
curl -X PUT http://127.0.0.1:8000/tasks/1 \
  -H "Content-Type: application/json" \
  -d '{
    "content": "Updated content",
    "request_timestamp": "2025-09-25T20:01:00Z"
  }'
```

5) Delete task
- DELETE `/tasks/{task_id}`
- Request model: `TaskDelete` — `{ request_timestamp }`
- Semantic parallels update:
  - If `request_timestamp` <= stored `last_request_ts`: 409 Conflict.
  - If `request_timestamp` > now: scheduled delete.
  - Otherwise: immediate delete.

Example scheduled delete:
```/dev/null/curl-delete-scheduled.sh#L1-8
curl -X DELETE http://127.0.0.1:8000/tasks/1 \
  -H "Content-Type: application/json" \
  -d '{ "request_timestamp": "2025-12-01T00:00:00Z" }'
# Returns: { "id": 1, "scheduled": true, "execute_at": "...", "op_id": 124 }
```

---

## Concurrency & scheduling model

This service uses a simple optimistic concurrency control approach driven by RFC3339 timestamps:

- Each successful write (create/update) stores its `request_timestamp` in the `tasks.last_request_ts` column (a string in RFC3339 UTC).
- Incoming modifying requests must include a `request_timestamp` field.
- On update/delete, the server compares the incoming `request_timestamp` to the stored `last_request_ts` parsed as timestamps:
  - If incoming `request_timestamp` is NOT strictly greater than stored `last_request_ts`, the server returns 409 Conflict.
  - If strictly greater, the operation may either be executed immediately (if `request_timestamp` <= current time) or scheduled for future execution (if `request_timestamp` > now).

Scheduling:
- Scheduled operations are saved to `scheduled_ops` with the `execute_at` timestamp equal to the provided `request_timestamp`.
- A background runner periodically reads due rows (`execute_at <= now`) and attempts to apply them.
- When processing a scheduled op, the runner re-checks the `request_ts` against the current `last_request_ts` of the target resource. If the scheduled op's `request_ts` is not strictly greater than the current stored `last_request_ts`, the scheduled op is discarded to avoid applying stale writes.
- For create operations scheduled in the future, the `task_id` is `NULL` in the scheduled op; on execution the runner will create the new task. (Note: in this codebase the create scheduling path enqueues an op with `task_id = None` — implemented accordingly.)

Edge cases:
- Scheduled ops that fail during processing are removed to avoid infinite retries (the runner deletes the op on exceptions).
- The scheduling model depends on accurate client-provided `request_timestamp` values and monotonicity of times as used by clients.

---

## Background scheduler

- Implemented in `app/main.py` as `_scheduled_ops_runner()`.
- On startup, `on_startup()` creates an asyncio task that loops and calls `process_due_scheduled_ops_once()` (from `app/core/db.py`) via `asyncio.to_thread()` to avoid blocking the event loop.
- The runner sleeps for a short interval (tuned to 1 second) between checks to achieve prompt execution for scheduled ops.
- On shutdown the runner task is cancelled and awaited to finish cleanly.

---

## Correlation ID middleware & error handling

- Middleware (`correlation_id_middleware`) reads `correlation-id` or `correlation_id` headers from incoming requests or generates a UUID if absent. This ID is attached to `request.state.correlation_id` and returned in response headers as `x-correlation-id` and `correlation_id`.
- The app registers exception handlers for:
  - `RequestValidationError` — returns HTTP 400 with `detail` containing validation errors (instead of default 422).
  - `sqlite3.IntegrityError` — returns HTTP 409 Conflict (useful for UNIQUE constraint violations).
  - Generic `Exception` — returns HTTP 500 Internal Server Error.
- The handlers include correlation headers to aid cross-service tracing.

---

## Observability & debugging

- Use the correlation id header for tracing:
  - Send `correlation-id: <uuid>` in requests to identify and track request flows and log correlation across services.
- Inspect the SQLite database file `app/tasks.db` with `sqlite3` or a DB browser for quick inspection:
```/dev/null/sqlite-inspect.sh#L1-6
# Example:
sqlite3 app/tasks.db
sqlite> .tables
sqlite> SELECT * FROM tasks LIMIT 10;
```

- For additional debug logging, add logging statements to `app/main.py` and `app/core/db.py` around key operations (e.g., enqueue, process scheduled ops).

---

## Testing

- Manual tests: Use `curl` examples above or a REST client (Postman, HTTPie) to interact with endpoints.
- Automated tests: There are no tests included in the repository; add pytest-based tests that spin up a TestClient from FastAPI and an isolated temporary SQLite DB (or mock `get_db` to point to a temp file) to assert behavior for:
  - Immediate create/update/delete
  - Scheduling create/update/delete
  - Concurrency conflicts with `request_timestamp`
  - Background runner processing of scheduled ops

---

## Contributing / Extending

A few suggestions for improvements or extensions:
- Transactional scheduled create: when creating a scheduled `create` op, include all necessary payload and ensure the runner creates the resource with a deterministic ID or return the op id for later reference.
- Retain a small retry-on-failure policy for scheduled ops (with a retry count/TTL) instead of deleting on the first exception, if transient errors are expected.
- Add authentication/authorization for multi-user support and to enforce per-user visibility for tasks (the `users` table exists but is unused).
- Add structured logging (JSON logs) including correlation id and additional metadata.
- Add metrics (Prometheus) for counts of scheduled ops enqueued, processed, and failed.
- Consider switching to a more robust queue (RabbitMQ/Redis) for production-scale scheduling.

---

If you want, I can:
- Add examples of unit tests.
- Create a small script to inspect and print pending scheduled operations.
- Add a README or update `app/requirements.txt` with pinned versions or a `pyproject.toml`/`poetry` manifest.
