from __future__ import annotations

from datetime import date, datetime
from typing import Optional

from pydantic import BaseModel, Field


class TaskCreate(BaseModel):
    """
    Request model to create a new task.

    Notes:
    - request_timestamp should be an RFC3339 timestamp (e.g., '2025-09-25T20:00:00Z').
    - due_date is optional and represented as a calendar date (no timezone).
    """

    title: str = Field(
        ..., min_length=1, max_length=255, description="Short title of the task"
    )
    content: Optional[str] = Field(
        default=None, max_length=10_000, description="Detailed description or notes"
    )
    due_date: Optional[date] = Field(
        default=None, description="Optional due date (YYYY-MM-DD)"
    )
    request_timestamp: datetime = Field(
        ..., description="RFC3339 timestamp used for write concurrency control"
    )

    model_config = {
        "json_schema_extra": {
            "examples": [
                {
                    "title": "Write",
                    "content": "Prepare lesson",
                    "due_date": "2025-09-30",
                    "request_timestamp": "2025-09-25T20:00:00Z",
                }
            ]
        }
    }


class TaskUpdate(BaseModel):
    """
    Request model to update an existing task.

    Notes:
    - At least one of title/content/due_date/done may be provided to modify the resource.
    - request_timestamp must be strictly greater than the last successful write timestamp.
    """

    title: Optional[str] = Field(
        default=None, min_length=1, max_length=255, description="Updated title"
    )
    content: Optional[str] = Field(
        default=None, max_length=10_000, description="Updated description/notes"
    )
    due_date: Optional[date] = Field(
        default=None, description="Updated due date (YYYY-MM-DD)"
    )
    done: Optional[bool] = Field(default=None, description="Mark task as done or not")
    request_timestamp: datetime = Field(
        ..., description="RFC3339 timestamp used for write concurrency control"
    )

    model_config = {
        "json_schema_extra": {
            "examples": [
                {
                    "title": "Review",
                    "content": "Check slides",
                    "done": True,
                    "request_timestamp": "2025-09-25T20:01:00Z",
                }
            ]
        }
    }


class TaskDelete(BaseModel):
    """
    Request model to delete a task.

    Notes:
    - request_timestamp must be strictly greater than the last successful write timestamp.
    """

    request_timestamp: datetime = Field(
        ..., description="RFC3339 timestamp used for write concurrency control"
    )

    model_config = {
        "json_schema_extra": {
            "examples": [
                {
                    "request_timestamp": "2025-09-25T20:02:00Z",
                }
            ]
        }
    }


class TaskOut(BaseModel):
    """
    Response model representing a task resource as returned by the API.

    Notes:
    - created_at and updated_at are RFC3339 UTC timestamps.
    - due_date is a calendar date (no time or timezone).
    """

    id: int = Field(..., description="Unique identifier of the task")
    title: str = Field(..., description="Short title of the task")
    content: Optional[str] = Field(
        default=None, description="Detailed description or notes"
    )
    due_date: Optional[date] = Field(
        default=None, description="Optional due date (YYYY-MM-DD)"
    )
    done: bool = Field(..., description="Completion status")
    created_at: datetime = Field(..., description="Creation timestamp (RFC3339, UTC)")
    updated_at: datetime = Field(
        ..., description="Last update timestamp (RFC3339, UTC)"
    )


__all__ = [
    "TaskCreate",
    "TaskUpdate",
    "TaskDelete",
    "TaskOut",
]
