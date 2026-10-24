"""SpendSense AI backend compatibility shim.

Redirects to main.app. Run with:
    uvicorn main:app --host 0.0.0.0 --port 8000
"""
from main import app, ChatRequest, ChatResponse, health, chat

__all__ = ["app", "ChatRequest", "ChatResponse", "health", "chat"]
