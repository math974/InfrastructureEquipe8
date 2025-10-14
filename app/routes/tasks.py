from __future__ import annotations

import sqlite3
from typing import List, Dict, Any

from fastapi import APIRouter, HTTPException, status

from core.db import (
    get_db,
    iso_utc_now,
    normalize_rfc3339,
    parse_rfc3339,
    row_to_task,
    to_utc,
    enqueue_scheduled_op,
)
from core.models import TaskCreate, TaskDelete, TaskOut, TaskUpdate

router = APIRouter(prefix="/tasks", tags=["tasks"])


@router.post(
    "",
    response_model=Dict[str, Any],
    status_code=status.HTTP_201_CREATED,
    summary="Create a new task",
)
async def create_task(payload: TaskCreate):
    req_ts = to_utc(payload.request_timestamp)
    req_ts_norm = normalize_rfc3339(req_ts)
    now_iso = iso_utc_now()
    due_date_str = payload.due_date.isoformat() if payload.due_date else None

    with get_db() as conn:
        if req_ts_norm > now_iso:
            sched_payload = {
                "title": payload.title,
                "content": payload.content,
                "due_date": due_date_str,
                "done": 0,
                "request_timestamp": req_ts_norm,
            }
            op_id = enqueue_scheduled_op(conn, None, "create", sched_payload, req_ts_norm, req_ts_norm)
            return {"scheduled": True, "execute_at": req_ts_norm, "op_id": op_id}

        cur = conn.cursor()
        cur.execute(
            """
            INSERT INTO tasks (title, content, due_date, done, created_at, updated_at, last_request_ts)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            (
                payload.title,
                payload.content,
                due_date_str,
                0,
                now_iso,
                now_iso,
                req_ts_norm,
            ),
        )
        task_id = cur.lastrowid
        conn.commit()

        cur.execute("SELECT * FROM tasks WHERE id = ?", (task_id,))
        row = cur.fetchone()
        if not row:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to retrieve created task",
            )
        return row_to_task(row)


@router.get(
    "",
    response_model=List[TaskOut],
    status_code=status.HTTP_200_OK,
    summary="List all tasks",
)
async def list_tasks():
    with get_db() as conn:
        cur = conn.cursor()
        cur.execute("SELECT * FROM tasks ORDER BY id ASC")
        rows = cur.fetchall()
        return [row_to_task(r) for r in rows]


@router.get(
    "/{task_id}",
    response_model=TaskOut,
    status_code=status.HTTP_200_OK,
    summary="Get a specific task",
)
async def get_task(task_id: int):
    with get_db() as conn:
        cur = conn.cursor()
        cur.execute("SELECT * FROM tasks WHERE id = ?", (task_id,))
        row = cur.fetchone()
        if not row:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="Resource not found"
            )
        return row_to_task(row)


@router.put(
    "/{task_id}",
    response_model=Dict[str, Any],
    status_code=status.HTTP_200_OK,
    summary="Update a task",
)
async def update_task(task_id: int, payload: TaskUpdate):
    req_ts = to_utc(payload.request_timestamp)
    req_ts_norm = normalize_rfc3339(req_ts)

    with get_db() as conn:
        cur = conn.cursor()
        cur.execute("SELECT * FROM tasks WHERE id = ?", (task_id,))
        row = cur.fetchone()
        if not row:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="Resource not found"
            )

        stored_last_ts = parse_rfc3339(row["last_request_ts"])
        if not (req_ts > stored_last_ts):
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT, detail="Timestamp conflict"
            )

        now_iso = iso_utc_now()
        if req_ts_norm > now_iso:
            sched_payload: Dict[str, Any] = {
                "title": payload.title if payload.title is not None else row["title"],
                "content": payload.content if payload.content is not None else row["content"],
                "due_date": payload.due_date.isoformat() if payload.due_date is not None else row["due_date"],
                "done": int(payload.done) if payload.done is not None else row["done"],
                "request_timestamp": req_ts_norm,
            }
            op_id = enqueue_scheduled_op(conn, task_id, "update", sched_payload, req_ts_norm, req_ts_norm)
            return {"id": task_id, "scheduled": True, "execute_at": req_ts_norm, "op_id": op_id}

        new_title = payload.title if payload.title is not None else row["title"]
        new_content = payload.content if payload.content is not None else row["content"]
        new_due_date = (
            payload.due_date.isoformat()
            if payload.due_date is not None
            else row["due_date"]
        )
        new_done = int(payload.done) if payload.done is not None else row["done"]
        now_iso = iso_utc_now()

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
                now_iso,
                req_ts_norm,
                task_id,
            ),
        )
        conn.commit()

        cur.execute("SELECT * FROM tasks WHERE id = ?", (task_id,))
        updated = cur.fetchone()
        if not updated:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to retrieve updated task",
            )
        return row_to_task(updated)


@router.delete(
    "/{task_id}",
    response_model=Dict[str, Any],
    status_code=status.HTTP_200_OK,
    summary="Delete a task",
)
async def delete_task(task_id: int, payload: TaskDelete):
    req_ts = to_utc(payload.request_timestamp)
    req_ts_norm = normalize_rfc3339(req_ts)

    with get_db() as conn:
        cur = conn.cursor()
        cur.execute("SELECT * FROM tasks WHERE id = ?", (task_id,))
        row = cur.fetchone()
        if not row:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="Resource not found"
            )

        stored_last_ts = parse_rfc3339(row["last_request_ts"])
        if not (req_ts > stored_last_ts):
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT, detail="Timestamp conflict"
            )

        now_iso = iso_utc_now()
        if req_ts_norm > now_iso:
            # Schedule delete
            sched_payload = {"request_timestamp": req_ts_norm}
            op_id = enqueue_scheduled_op(conn, task_id, "delete", sched_payload, req_ts_norm, req_ts_norm)
            return {"id": task_id, "scheduled": True, "execute_at": req_ts_norm, "op_id": op_id}

        # Immediate delete
        cur.execute("DELETE FROM tasks WHERE id = ?", (task_id,))
        conn.commit()
        return {"id": task_id, "deleted": True}
