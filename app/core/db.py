from __future__ import annotations

import os
import json
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional
from contextlib import contextmanager
from dotenv import load_dotenv

from sqlalchemy import create_engine, text
from sqlalchemy.engine import Engine

# Connection configuration: prefer full URL, otherwise build from env
# Expected env vars:
#   DATABASE_URL or (DB_USER, DB_PASSWORD, DB_HOST, DB_PORT, DB_NAME)
# DB driver used: pymysql via SQLAlchemy -> "mysql+pymysql://..."
# The application code uses DB-API style connections (cursor(), commit()), so get_db yields a DB-API connection.

BASE_DIR = os.path.dirname(os.path.dirname(__file__))
# Load environment variables from app/.env (if present)
load_dotenv(os.path.join(BASE_DIR, ".env"))


def iso_utc_now() -> str:
    """
    Return the current UTC time as an RFC3339 string without microseconds, with 'Z' suffix.
    Example: '2025-09-25T20:00:00Z'
    """
    return (
        datetime.now(timezone.utc)
        .replace(microsecond=0)
        .isoformat()
        .replace("+00:00", "Z")
    )


def to_utc(dt: datetime) -> datetime:
    """
    Ensure a datetime is timezone-aware and converted to UTC.
    Naive datetimes are interpreted as UTC.
    """
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


def parse_rfc3339(dt_str: str) -> datetime:
    """
    Parse an RFC3339 timestamp string into a timezone-aware datetime.
    Accepts 'Z' suffix and converts it to '+00:00' for parsing.
    """
    if dt_str.endswith("Z"):
        dt_str = dt_str[:-1] + "+00:00"
    return datetime.fromisoformat(dt_str)


def normalize_rfc3339(dt: datetime) -> str:
    """
    Normalize a datetime to UTC RFC3339 string (no microseconds, with 'Z' suffix).
    """
    return to_utc(dt).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def _build_engine() -> Engine:
    # Allow overriding with full DATABASE_URL
    db_url = os.getenv("DATABASE_URL")
    if db_url:
        return create_engine(db_url, pool_pre_ping=True)

    user = os.getenv("DB_USER", "root")
    password = os.getenv("DB_PASSWORD", "")
    host = os.getenv("DB_HOST", "127.0.0.1")
    port = os.getenv("DB_PORT", "3306")
    db = os.getenv("DB_NAME", "tasksdb")

    # Using pymysql driver
    url = f"mysql+pymysql://{user}:{password}@{host}:{port}/{db}?charset=utf8mb4"
    return create_engine(url, pool_pre_ping=True, pool_recycle=3600)


# Module-level engine
_engine = _build_engine()


@contextmanager
def get_db():
    """
    Context manager that yields a raw DB-API connection (so calling code that uses
    `with get_db() as conn:` and then `cur = conn.cursor()` still works).
    The returned connection must be closed by this context manager.
    """
    raw_conn = _engine.raw_connection()
    try:
        yield raw_conn
    finally:
        try:
            raw_conn.close()
        except Exception:
            pass


def init_db() -> None:
    """
    Initialize the MySQL schema if it doesn't exist.
    Uses DDL statements compatible with MySQL.
    Note: takes the environment-configured DB and runs CREATE TABLE IF NOT EXISTS.
    """
    # We use an engine-level connection for DDL
    with _engine.begin() as conn:
        # Using VARCHAR for RFC3339 timestamps to keep compatibility with existing code
        conn.execute(
            text(
                """
                CREATE TABLE IF NOT EXISTS tasks (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    title VARCHAR(255) NOT NULL,
                    content TEXT,
                    due_date VARCHAR(10),
                    done TINYINT NOT NULL DEFAULT 0,
                    created_at VARCHAR(32) NOT NULL,
                    updated_at VARCHAR(32) NOT NULL,
                    last_request_ts VARCHAR(32) NOT NULL,
                    UNIQUE KEY ux_tasks_title_due (title, due_date)
                )
                """
            )
        )
        conn.execute(
            text("CREATE INDEX IF NOT EXISTS idx_tasks_due_date ON tasks(due_date)")
        )
        conn.execute(
            text("CREATE INDEX IF NOT EXISTS idx_tasks_updated_at ON tasks(updated_at)")
        )

        conn.execute(
            text(
                """
                CREATE TABLE IF NOT EXISTS users (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    username VARCHAR(255) NOT NULL UNIQUE,
                    email VARCHAR(255),
                    password_hash VARCHAR(255) NOT NULL,
                    is_active TINYINT NOT NULL DEFAULT 1,
                    created_at VARCHAR(32) NOT NULL,
                    updated_at VARCHAR(32) NOT NULL
                )
                """
            )
        )
        conn.execute(
            text("CREATE INDEX IF NOT EXISTS idx_users_username ON users(username)")
        )
        conn.execute(text("CREATE INDEX IF NOT EXISTS idx_users_email ON users(email)"))

        conn.execute(
            text(
                """
                CREATE TABLE IF NOT EXISTS scheduled_ops (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    task_id INT,
                    op_type VARCHAR(32) NOT NULL,
                    payload TEXT NOT NULL,
                    execute_at VARCHAR(32) NOT NULL,
                    request_ts VARCHAR(32) NOT NULL,
                    created_at VARCHAR(32) NOT NULL
                )
                """
            )
        )
        conn.execute(
            text(
                "CREATE INDEX IF NOT EXISTS idx_schedops_execute_at ON scheduled_ops(execute_at)"
            )
        )


def _row_to_dict(cursor, row) -> Dict[str, Any]:
    """
    Convert a DB-API row (tuple) into a dict using cursor.description.
    If row is already a mapping-like object, return as dict.
    """
    if row is None:
        return None
    # If row supports keys() and __getitem__ with strings, try to use it directly
    try:
        if hasattr(row, "keys"):
            return {k: row[k] for k in row.keys()}
    except Exception:
        pass

    # Fallback: use cursor.description to build keys
    desc = [col[0] for col in cursor.description]
    return {k: v for k, v in zip(desc, row)}


def row_to_task(row: Any) -> Dict[str, Any]:
    """
    Convert a DB row (mapping-like or tuple with cursor) into the serializable dict.
    Keeps due_date as a string (YYYY-MM-DD) like before.
    """
    if row is None:
        return None
    if isinstance(row, dict):
        src = row
    else:
        # If it's a DB-API row proxy from some adapters, try mapping access
        try:
            src = dict(row)
        except Exception:
            # As a last resort, caller should supply mapping; raise to highlight mismatch
            raise TypeError("Unsupported row type for row_to_task")
    return {
        "id": src.get("id"),
        "title": src.get("title"),
        "content": src.get("content"),
        "due_date": src.get("due_date"),
        "done": bool(int(src.get("done"))) if src.get("done") is not None else False,
        "created_at": src.get("created_at"),
        "updated_at": src.get("updated_at"),
    }


# New helpers for scheduled operations


def enqueue_scheduled_op(
    conn,
    task_id: Optional[int],
    op_type: str,
    payload: Dict[str, Any],
    execute_at: str,
    request_ts: str,
) -> int:
    """
    Insert a scheduled operation and return its id.
    Expects `conn` to be a DB-API connection (obtained from get_db()).
    """
    cur = conn.cursor()
    now_iso = iso_utc_now()
    cur.execute(
        """
        INSERT INTO scheduled_ops (task_id, op_type, payload, execute_at, request_ts, created_at)
        VALUES (%s, %s, %s, %s, %s, %s)
        """,
        (task_id, op_type, json.dumps(payload), execute_at, request_ts, now_iso),
    )
    op_id = cur.lastrowid if hasattr(cur, "lastrowid") else None
    conn.commit()
    return op_id


def fetch_due_scheduled_ops(conn, upto_iso: str) -> List[Dict[str, Any]]:
    """
    Fetch scheduled operations with execute_at <= upto_iso.
    Returns list of dicts.
    """
    cur = conn.cursor()
    cur.execute(
        "SELECT * FROM scheduled_ops WHERE execute_at <= %s ORDER BY execute_at ASC",
        (upto_iso,),
    )
    rows = cur.fetchall()
    results = []
    for r in rows:
        results.append(_row_to_dict(cur, r))
    return results


def delete_scheduled_op(conn, op_id: int) -> None:
    cur = conn.cursor()
    cur.execute("DELETE FROM scheduled_ops WHERE id = %s", (op_id,))
    conn.commit()


def process_due_scheduled_ops_once() -> int:
    """
    Process all scheduled operations that are due right now.
    Returns the number of processed operations.
    Each operation is applied only if its request_ts is still greater than the current stored last_request_ts.
    """
    processed = 0
    with get_db() as conn:
        cur = conn.cursor()
        now_iso = iso_utc_now()
        due_ops = fetch_due_scheduled_ops(conn, now_iso)
        for op in due_ops:
            try:
                op_id = op.get("id")
                task_id = op.get("task_id")
                op_type = op.get("op_type")
                payload = json.loads(op.get("payload", "{}"))
                req_ts = parse_rfc3339(op.get("request_ts"))

                # For update/delete, check resource exists
                cur.execute("SELECT * FROM tasks WHERE id = %s", (task_id,))
                row = cur.fetchone()
                task_row = _row_to_dict(cur, row) if row is not None else None
                if not task_row:
                    # Nothing to apply; remove scheduled op
                    delete_scheduled_op(conn, op_id)
                    continue

                stored_last_ts = parse_rfc3339(task_row.get("last_request_ts"))
                if not (req_ts > stored_last_ts):
                    # Conflict at execution time; drop the scheduled op
                    delete_scheduled_op(conn, op_id)
                    continue

                if op_type == "update":
                    new_title = payload.get("title", task_row.get("title"))
                    new_content = payload.get("content", task_row.get("content"))
                    new_due_date = payload.get("due_date", task_row.get("due_date"))
                    new_done = (
                        int(payload.get("done"))
                        if payload.get("done") is not None
                        else int(task_row.get("done", 0))
                    )
                    now_iso_local = iso_utc_now()
                    cur.execute(
                        """
                        UPDATE tasks
                        SET title = %s, content = %s, due_date = %s, done = %s, updated_at = %s, last_request_ts = %s
                        WHERE id = %s
                        """,
                        (
                            new_title,
                            new_content,
                            new_due_date,
                            new_done,
                            now_iso_local,
                            op.get("request_ts"),
                            task_id,
                        ),
                    )
                    conn.commit()
                    delete_scheduled_op(conn, op_id)
                    processed += 1
                elif op_type == "delete":
                    cur.execute("DELETE FROM tasks WHERE id = %s", (task_id,))
                    conn.commit()
                    delete_scheduled_op(conn, op_id)
                    processed += 1
                else:
                    delete_scheduled_op(conn, op_id)
            except Exception:
                # On any exception while processing an op, remove it to avoid retries/leaks
                try:
                    delete_scheduled_op(conn, op.get("id"))
                except Exception:
                    pass
                continue
    return processed


__all__ = [
    "get_db",
    "init_db",
    "row_to_task",
    "iso_utc_now",
    "to_utc",
    "parse_rfc3339",
    "normalize_rfc3339",
    "enqueue_scheduled_op",
    "fetch_due_scheduled_ops",
    "delete_scheduled_op",
    "process_due_scheduled_ops_once",
]
