from __future__ import annotations

import uuid
import asyncio
from typing import Any, Dict
from sqlalchemy.exc import IntegrityError as DBIntegrityError

from fastapi import FastAPI, HTTPException, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse


from core.db import init_db, process_due_scheduled_ops_once

from routes.tasks import router as tasks_router


app = FastAPI(title="Task Manager API", version="1.0.0")

app.include_router(tasks_router)


@app.middleware("http")
async def correlation_id_middleware(request: Request, call_next):
    correlation_id = (
        request.headers.get("correlation-id")
        or request.headers.get("correlation_id")
        or str(uuid.uuid4())
    )
    request.state.correlation_id = correlation_id
    try:
        response = await call_next(request)
    except HTTPException as e:
        resp = JSONResponse(status_code=e.status_code, content={"detail": e.detail})
        resp.headers["x-correlation-id"] = correlation_id
        resp.headers["correlation_id"] = correlation_id
        if hasattr(e, "headers") and e.headers:
            for k, v in e.headers.items():
                resp.headers[k] = v
        return resp
    except Exception:
        response = JSONResponse(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            content={"detail": "Internal Server Error"},
        )
        response.headers["x-correlation-id"] = correlation_id
        response.headers["correlation_id"] = correlation_id
        return response

    response.headers["x-correlation-id"] = correlation_id
    response.headers["correlation_id"] = correlation_id
    return response


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    # Map validation errors to 400 Bad Request instead of FastAPI's default 422
    headers = {
        "x-correlation-id": getattr(request.state, "correlation_id", ""),
        "correlation_id": getattr(request.state, "correlation_id", ""),
    }
    return JSONResponse(
        status_code=status.HTTP_400_BAD_REQUEST,
        content={"detail": exc.errors()},
        headers=headers,
    )


@app.exception_handler(DBIntegrityError)
async def db_integrity_handler(request: Request, exc: DBIntegrityError):
    headers = {
        "x-correlation-id": getattr(request.state, "correlation_id", ""),
        "correlation_id": getattr(request.state, "correlation_id", ""),
    }
    return JSONResponse(
        status_code=status.HTTP_409_CONFLICT,
        content={"detail": "Conflict"},
        headers=headers,
    )


@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, exc: Exception):
    headers = {
        "x-correlation-id": getattr(request.state, "correlation_id", ""),
        "correlation_id": getattr(request.state, "correlation_id", ""),
    }
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={"detail": "Internal Server Error"},
        headers=headers,
    )


@app.on_event("startup")
def on_startup():
    init_db()
    # start background scheduler
    loop = asyncio.get_event_loop()
    # store task on app.state to allow cancellation
    app.state._sched_task = loop.create_task(_scheduled_ops_runner())


@app.on_event("shutdown")
async def on_shutdown():
    # cancel scheduler if running
    sched = getattr(app.state, "_sched_task", None)
    if sched:
        sched.cancel()
        try:
            await sched
        except asyncio.CancelledError:
            pass


async def _scheduled_ops_runner():
    """
    Background runner that periodically processes due scheduled operations.
    Runs until application shutdown.
    """
    try:
        while True:
            try:
                processed = await asyncio.to_thread(process_due_scheduled_ops_once)
            except Exception:
                processed = 0
            # sleep a short time; tuned to 1 second for prompt execution
            await asyncio.sleep(1)
    except asyncio.CancelledError:
        return


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)
