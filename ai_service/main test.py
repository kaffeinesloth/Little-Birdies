"""
Compatibility entry point.

Use main.py for normal local and Docker runs:
    uvicorn main:app --reload --port 8001
"""
from main import app
