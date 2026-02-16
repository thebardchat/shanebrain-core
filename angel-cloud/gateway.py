"""
Angel Cloud Gateway — The front door to the ShaneBrain ecosystem.
FastAPI application serving on port 4200.
"""

import os
import re
import time
import secrets
from datetime import datetime, timezone

from fastapi import FastAPI, Request, Form, Response
from fastapi.responses import HTMLResponse, RedirectResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates

import models
from weaviate_bridge import register_user_in_weaviate, get_weaviate_stats

START_TIME = time.time()

app = FastAPI(title="Angel Cloud Gateway", docs_url="/api/docs", redoc_url=None)

BASE_DIR = os.path.dirname(__file__)
app.mount("/static", StaticFiles(directory=os.path.join(BASE_DIR, "static")), name="static")
templates = Jinja2Templates(directory=os.path.join(BASE_DIR, "templates"))

# Simple signed-cookie session store
SESSION_SECRET = os.environ.get("SESSION_SECRET", secrets.token_hex(32))
_sessions: dict[str, int] = {}  # token -> user_id


def _get_current_user(request: Request) -> dict | None:
    token = request.cookies.get("session")
    if token and token in _sessions:
        user = models.get_user_by_id(_sessions[token])
        return user
    return None


# ---------------------------------------------------------------------------
# Startup
# ---------------------------------------------------------------------------

@app.on_event("startup")
def startup():
    models.init_db()


# ---------------------------------------------------------------------------
# Pages
# ---------------------------------------------------------------------------

@app.get("/", response_class=HTMLResponse)
def landing(request: Request):
    user = _get_current_user(request)
    stats = {
        "users": models.get_user_count(),
        "knowledge": 165,
        "conversations": 51,
    }
    try:
        wv = get_weaviate_stats()
        if wv.get("weaviate") == "online":
            stats["knowledge"] = wv.get("LegacyKnowledge", 165)
            stats["conversations"] = wv.get("Conversation", 51)
    except Exception:
        pass
    return templates.TemplateResponse("landing.html", {"request": request, "user": user, "stats": stats})


@app.get("/register", response_class=HTMLResponse)
def register_page(request: Request):
    user = _get_current_user(request)
    if user:
        return RedirectResponse("/welcome", status_code=303)
    return templates.TemplateResponse("register.html", {"request": request, "user": None, "error": None})


@app.get("/login", response_class=HTMLResponse)
def login_page(request: Request):
    user = _get_current_user(request)
    if user:
        return RedirectResponse("/welcome", status_code=303)
    return templates.TemplateResponse("login.html", {"request": request, "user": None, "error": None, "success": None})


@app.get("/welcome", response_class=HTMLResponse)
def welcome_page(request: Request):
    user = _get_current_user(request)
    if not user:
        return RedirectResponse("/login", status_code=303)
    level_index = models.get_level_index(user["angel_level"])
    total_levels = len(models.ANGEL_LEVELS)
    progress = int((level_index / max(total_levels - 1, 1)) * 100)
    return templates.TemplateResponse("welcome.html", {
        "request": request,
        "user": user,
        "level_index": level_index,
        "total_levels": total_levels,
        "progress": progress,
    })


@app.get("/chat")
def chat_redirect(request: Request):
    # Redirect to Open WebUI chat interface
    return RedirectResponse("http://localhost:3000", status_code=303)


@app.get("/logout")
def logout(request: Request):
    token = request.cookies.get("session")
    if token:
        _sessions.pop(token, None)
    response = RedirectResponse("/", status_code=303)
    response.delete_cookie("session")
    return response


# ---------------------------------------------------------------------------
# API — Auth
# ---------------------------------------------------------------------------

USERNAME_RE = re.compile(r"^[a-zA-Z0-9_-]{3,32}$")


@app.post("/api/register")
def api_register(
    request: Request,
    username: str = Form(...),
    email: str = Form(...),
    password: str = Form(...),
    password_confirm: str = Form(...),
):
    # Validation
    if not USERNAME_RE.match(username):
        return templates.TemplateResponse("register.html", {
            "request": request, "user": None,
            "error": "Username must be 3-32 characters: letters, numbers, hyphens, underscores.",
            "username": username, "email": email,
        }, status_code=400)

    if password != password_confirm:
        return templates.TemplateResponse("register.html", {
            "request": request, "user": None,
            "error": "Passwords do not match.",
            "username": username, "email": email,
        }, status_code=400)

    if len(password) < 8:
        return templates.TemplateResponse("register.html", {
            "request": request, "user": None,
            "error": "Password must be at least 8 characters.",
            "username": username, "email": email,
        }, status_code=400)

    user = models.create_user(username, email, password)
    if not user:
        return templates.TemplateResponse("register.html", {
            "request": request, "user": None,
            "error": "Username or email already taken.",
            "username": username, "email": email,
        }, status_code=409)

    # Register in Weaviate (non-blocking, best-effort)
    try:
        register_user_in_weaviate(username, email)
    except Exception as e:
        print(f"Weaviate registration failed (non-fatal): {e}")

    # Create session
    token = secrets.token_hex(32)
    _sessions[token] = user["id"]
    response = RedirectResponse("/welcome", status_code=303)
    response.set_cookie("session", token, httponly=True, samesite="lax", max_age=86400 * 30)
    return response


@app.post("/api/login")
def api_login(
    request: Request,
    email: str = Form(...),
    password: str = Form(...),
):
    user = models.authenticate(email, password)
    if not user:
        return templates.TemplateResponse("login.html", {
            "request": request, "user": None,
            "error": "Invalid email or password.",
            "email": email, "success": None,
        }, status_code=401)

    token = secrets.token_hex(32)
    _sessions[token] = user["id"]
    response = RedirectResponse("/welcome", status_code=303)
    response.set_cookie("session", token, httponly=True, samesite="lax", max_age=86400 * 30)
    return response


# ---------------------------------------------------------------------------
# API — Public
# ---------------------------------------------------------------------------

@app.get("/api/health")
def health():
    return {
        "status": "ok",
        "service": "angel-cloud-gateway",
        "uptime_seconds": int(time.time() - START_TIME),
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }


@app.get("/api/stats")
def stats():
    data = {
        "users": models.get_user_count(),
        "uptime_seconds": int(time.time() - START_TIME),
    }
    try:
        wv = get_weaviate_stats()
        data["weaviate"] = wv
    except Exception:
        data["weaviate"] = {"status": "error"}
    return data
