"""
Task Manager API package initializer.

This makes the `app` directory a Python package and exposes the FastAPI
application instance at the package level so imports like `app:app`
work (e.g., with uvicorn).
"""

from .main import app as app

__all__ = ["app"]
