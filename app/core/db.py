from __future__ import annotations

import os
import sqlite3
from datetime import datetime, timezone
from typing import Any, Dict

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


__all__ = [
    "DB_PATH",
    "get_db",
    "init_db",
    "row_to_task",
    "iso_utc_now",
    "to_utc",
    "parse_rfc3339",
    "normalize_rfc3339",
]
