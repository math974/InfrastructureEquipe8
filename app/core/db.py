from __future__ import annotations

import os
import sqlite3
import json
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

BASE_DIR = os.path.dirname(os.path.dirname(__file__))
DB_PATH = os.path.join(BASE_DIR, "tasks.db")


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


def get_db() -> sqlite3.Connection:
    """
    Open a new SQLite connection with Row factory enabled.
    Callers are responsible for closing/committing (use context manager recommended).
    """
    conn = sqlite3.connect(DB_PATH, detect_types=sqlite3.PARSE_DECLTYPES)
    conn.row_factory = sqlite3.Row
    return conn


def init_db() -> None:
    """
    Initialize the database schema if it doesn't exist.
    Creates indices and a UNIQUE constraint to prevent duplicate tasks
    for the same (title, due_date) pair.
    Also creates scheduled_ops table for deferred operations.
    """
    with get_db() as conn:
        cur = conn.cursor()
        # Tasks table
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS tasks (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                title TEXT NOT NULL,
                content TEXT,
                due_date TEXT,
                done INTEGER NOT NULL DEFAULT 0,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                last_request_ts TEXT NOT NULL,
                UNIQUE(title, due_date)
            )
            """
        )
        cur.execute("CREATE INDEX IF NOT EXISTS idx_tasks_due_date ON tasks(due_date)")
        cur.execute(
            "CREATE INDEX IF NOT EXISTS idx_tasks_updated_at ON tasks(updated_at)"
        )

        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS users (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                username TEXT NOT NULL UNIQUE,
                email TEXT UNIQUE,
                password_hash TEXT NOT NULL,
                is_active INTEGER NOT NULL DEFAULT 1,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
            """
        )
        cur.execute("CREATE INDEX IF NOT EXISTS idx_users_username ON users(username)")
        cur.execute("CREATE INDEX IF NOT EXISTS idx_users_email ON users(email)")

        # New table for scheduled operations
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS scheduled_ops (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                task_id INTEGER,
                op_type TEXT NOT NULL, -- 'update' or 'delete'
                payload TEXT NOT NULL, -- JSON payload for the op
                execute_at TEXT NOT NULL, -- RFC3339 execute timestamp (UTC)
                request_ts TEXT NOT NULL, -- original request timestamp (RFC3339, UTC)
                created_at TEXT NOT NULL
            )
            """
        )
        cur.execute(
            "CREATE INDEX IF NOT EXISTS idx_schedops_execute_at ON scheduled_ops(execute_at)"
        )
        conn.commit()


def row_to_task(row: sqlite3.Row) -> Dict[str, Any]:
    """
    Convert a sqlite3.Row from the tasks table into a serializable dict.
    Note: due_date is kept as a string (YYYY-MM-DD); Pydantic models can coerce it to date.
    """
    return {
        "id": row["id"],
        "title": row["title"],
        "content": row["content"],
        "due_date": row["due_date"],
        "done": bool(row["done"]),
        "created_at": row["created_at"],
        "updated_at": row["updated_at"],
    }


# New helpers for scheduled operations

def enqueue_scheduled_op(
    conn: sqlite3.Connection,
    task_id: Optional[int],
    op_type: str,
    payload: Dict[str, Any],
    execute_at: str,
    request_ts: str,
) -> int:
    """
    Insert a scheduled operation and return its id.
    """
    cur = conn.cursor()
    now_iso = iso_utc_now()
    cur.execute(
        """
        INSERT INTO scheduled_ops (task_id, op_type, payload, execute_at, request_ts, created_at)
        VALUES (?, ?, ?, ?, ?, ?)
        """,
        (task_id, op_type, json.dumps(payload), execute_at, request_ts, now_iso),
    )
    op_id = cur.lastrowid
    conn.commit()
    return op_id


def fetch_due_scheduled_ops(conn: sqlite3.Connection, upto_iso: str) -> List[sqlite3.Row]:
    """
    Fetch scheduled operations with execute_at <= upto_iso.
    """
    cur = conn.cursor()
    cur.execute("SELECT * FROM scheduled_ops WHERE execute_at <= ? ORDER BY execute_at ASC", (upto_iso,))
    return cur.fetchall()


def delete_scheduled_op(conn: sqlite3.Connection, op_id: int) -> None:
    cur = conn.cursor()
    cur.execute("DELETE FROM scheduled_ops WHERE id = ?", (op_id,))
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
                op_id = op["id"]
                task_id = op["task_id"]
                op_type = op["op_type"]
                payload = json.loads(op["payload"])
                req_ts = parse_rfc3339(op["request_ts"])

                # For update/delete, check resource exists (for update we still allow applying if exists)
                cur.execute("SELECT * FROM tasks WHERE id = ?", (task_id,))
                row = cur.fetchone()
                if not row:
                    # Nothing to apply; remove scheduled op
                    delete_scheduled_op(conn, op_id)
                    continue

                stored_last_ts = parse_rfc3339(row["last_request_ts"])
                if not (req_ts > stored_last_ts):
                    # Conflict at execution time; drop the scheduled op
                    delete_scheduled_op(conn, op_id)
                    continue

                if op_type == "update":
                    # Build updated values (payload contains fields like title, content, due_date, done)
                    new_title = payload.get("title", row["title"])
                    new_content = payload.get("content", row["content"])
                    new_due_date = payload.get("due_date", row["due_date"])
                    new_done = int(payload.get("done")) if payload.get("done") is not None else row["done"]
                    now_iso_local = iso_utc_now()
                    cur.execute(
                        """
                        UPDATE tasks
                        SET title = ?, content = ?, due_date = ?, done = ?, updated_at = ?, last_request_ts = ?
                        WHERE id = ?
                        """,
                        (
                            new_title,
                            new_content,
                            new_due_date,
                            new_done,
                            now_iso_local,
                            op["request_ts"],
                            task_id,
                        ),
                    )
                    conn.commit()
                    # remove op
                    delete_scheduled_op(conn, op_id)
                    processed += 1
                elif op_type == "delete":
                    cur.execute("DELETE FROM tasks WHERE id = ?", (task_id,))
                    conn.commit()
                    delete_scheduled_op(conn, op_id)
                    processed += 1
                else:
                    # Unknown op type; remove it to avoid looping
                    delete_scheduled_op(conn, op_id)
            except Exception:
                # On any exception while processing an op, remove it to avoid retries/leaks
                try:
                    delete_scheduled_op(conn, op["id"])
                except Exception:
                    pass
                continue
    return processed


__all__ = [
    "DB_PATH",
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
