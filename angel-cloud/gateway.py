"""
Angel Cloud Gateway — The front door to the ShaneBrain ecosystem.
FastAPI application serving on port 4200.
"""

import os
import re
import time
import secrets
from datetime import datetime, timezone

import json

from fastapi import FastAPI, Request, Form, Response, Header
from fastapi.responses import HTMLResponse, RedirectResponse, JSONResponse, StreamingResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates

import models
from weaviate_bridge import register_user_in_weaviate, get_weaviate_stats, update_friend_level
from chat_engine import stream_response, log_chat

START_TIME = time.time()

app = FastAPI(title="Angel Cloud Gateway", docs_url="/api/docs", redoc_url=None)

BASE_DIR = os.path.dirname(__file__)
app.mount("/static", StaticFiles(directory=os.path.join(BASE_DIR, "static")), name="static")
templates = Jinja2Templates(directory=os.path.join(BASE_DIR, "templates"))

# Simple signed-cookie session store
SESSION_SECRET = os.environ.get("SESSION_SECRET", secrets.token_hex(32))
_sessions: dict[str, int] = {}  # token -> user_id

# Bot internal secret for Discord bot -> Gateway communication
BOT_INTERNAL_SECRET = os.environ.get("BOT_INTERNAL_SECRET", "")


def _get_current_user(request: Request) -> dict | None:
    token = request.cookies.get("session")
    if token and token in _sessions:
        user = models.get_user_by_id(_sessions[token])
        return user
    return None


def _check_bot_secret(x_bot_secret: str | None) -> bool:
    return BOT_INTERNAL_SECRET and x_bot_secret == BOT_INTERNAL_SECRET


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
    next_threshold = models.get_next_threshold(user["angel_level"])
    count = user.get("interaction_count") or 0
    if next_threshold:
        progress = int((count / next_threshold) * 100)
    else:
        progress = 100
    return templates.TemplateResponse("welcome.html", {
        "request": request,
        "user": user,
        "level_index": level_index,
        "total_levels": total_levels,
        "progress": min(progress, 100),
        "next_threshold": next_threshold,
    })


@app.get("/chat", response_class=HTMLResponse)
def chat_page(request: Request):
    user = _get_current_user(request)
    if not user:
        return RedirectResponse("/login", status_code=303)
    return templates.TemplateResponse("chat.html", {"request": request, "user": user})


@app.get("/profile", response_class=HTMLResponse)
def profile_page(request: Request, success: str = None, error: str = None):
    user = _get_current_user(request)
    if not user:
        return RedirectResponse("/login", status_code=303)
    next_threshold = models.get_next_threshold(user["angel_level"])
    count = user.get("interaction_count") or 0
    if next_threshold:
        progress = min(int((count / next_threshold) * 100), 100)
    else:
        progress = 100
    return templates.TemplateResponse("profile.html", {
        "request": request,
        "user": user,
        "progress": progress,
        "next_threshold": next_threshold,
        "success": success,
        "error": error,
    })


@app.get("/community", response_class=HTMLResponse)
def community_page(request: Request):
    user = _get_current_user(request)
    leaderboard = models.get_leaderboard()
    activity = models.get_recent_activity()
    stats = models.get_community_stats()
    return templates.TemplateResponse("community.html", {
        "request": request,
        "user": user,
        "leaderboard": leaderboard,
        "activity": activity,
        "stats": stats,
    })


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
# API — Chat + Profile (requires login)
# ---------------------------------------------------------------------------

@app.post("/api/chat")
async def api_chat(request: Request):
    user = _get_current_user(request)
    if not user:
        return JSONResponse({"error": "Not authenticated"}, status_code=401)

    try:
        body = await request.json()
    except Exception:
        return JSONResponse({"error": "Invalid JSON"}, status_code=400)

    message = (body.get("message") or "").strip()
    if not message:
        return JSONResponse({"error": "Empty message"}, status_code=400)

    def event_stream():
        full_response = []
        for token in stream_response(message, user):
            full_response.append(token)
            yield f"data: {json.dumps({'token': token})}\n\n"

        # After streaming completes: progression + logging
        response_text = "".join(full_response).strip()
        models.add_interaction_points(user["id"], 1, "chat", f"Chat: {message[:80]}")
        new_level = models.check_level_up(user["id"])

        if new_level:
            try:
                update_friend_level(user["email"], user["username"], new_level)
            except Exception:
                pass
            yield f"data: {json.dumps({'done': True, 'level_up': True, 'new_level': new_level})}\n\n"
        else:
            yield f"data: {json.dumps({'done': True})}\n\n"

        # Log to Weaviate after stream is done
        log_chat(message, response_text, user)

    return StreamingResponse(event_stream(), media_type="text/event-stream")


@app.post("/api/profile")
def api_profile(
    request: Request,
    display_name: str = Form(""),
):
    user = _get_current_user(request)
    if not user:
        return RedirectResponse("/login", status_code=303)
    models.update_profile(user["id"], display_name)
    return RedirectResponse("/profile?success=Display+name+updated", status_code=303)


@app.post("/api/password")
def api_password(
    request: Request,
    current_password: str = Form(...),
    new_password: str = Form(...),
    new_password_confirm: str = Form(...),
):
    user = _get_current_user(request)
    if not user:
        return RedirectResponse("/login", status_code=303)
    if new_password != new_password_confirm:
        return RedirectResponse("/profile?error=New+passwords+do+not+match", status_code=303)
    if len(new_password) < 8:
        return RedirectResponse("/profile?error=Password+must+be+at+least+8+characters", status_code=303)
    if not models.update_password(user["id"], current_password, new_password):
        return RedirectResponse("/profile?error=Current+password+is+incorrect", status_code=303)
    return RedirectResponse("/profile?success=Password+changed+successfully", status_code=303)


# ---------------------------------------------------------------------------
# API — Discord Link
# ---------------------------------------------------------------------------

@app.post("/api/create-link-code")
async def api_create_link_code(request: Request, x_bot_secret: str | None = Header(None)):
    """Called by Discord bot to create a verification code."""
    if not _check_bot_secret(x_bot_secret):
        return JSONResponse({"error": "Unauthorized"}, status_code=401)

    try:
        body = await request.json()
    except Exception:
        return JSONResponse({"error": "Invalid JSON"}, status_code=400)

    discord_id = body.get("discord_id", "")
    discord_name = body.get("discord_name", "")
    email = body.get("email", "").strip()
    if not discord_id or not email:
        return JSONResponse({"error": "Missing discord_id or email"}, status_code=400)

    code = models.create_link_code(str(discord_id), discord_name, email)
    if not code:
        return JSONResponse({"error": "Email not found or already linked"}, status_code=404)

    return JSONResponse({"code": code})


@app.post("/api/verify-discord")
def api_verify_discord(request: Request, code: str = Form(...)):
    """Profile page form: user enters 6-digit code to link Discord."""
    user = _get_current_user(request)
    if not user:
        return RedirectResponse("/login", status_code=303)

    discord_name = models.verify_link_code(user["id"], code.strip())
    if discord_name:
        return RedirectResponse(f"/profile?success=Discord+linked+as+{discord_name}", status_code=303)
    return RedirectResponse("/profile?error=Invalid+or+expired+code", status_code=303)


@app.post("/api/link-github")
def api_link_github(request: Request, github_username: str = Form(...)):
    """Profile page form: user enters GitHub username."""
    user = _get_current_user(request)
    if not user:
        return RedirectResponse("/login", status_code=303)

    username = github_username.strip()
    if not username:
        return RedirectResponse("/profile?error=GitHub+username+cannot+be+empty", status_code=303)

    if models.link_github(user["id"], username):
        return RedirectResponse(f"/profile?success=GitHub+linked+as+{username}", status_code=303)
    return RedirectResponse("/profile?error=GitHub+username+already+linked+to+another+account", status_code=303)


@app.post("/api/discord-activity")
async def api_discord_activity(request: Request, x_bot_secret: str | None = Header(None)):
    """Called by Discord bot to report user activity for points."""
    if not _check_bot_secret(x_bot_secret):
        return JSONResponse({"error": "Unauthorized"}, status_code=401)

    try:
        body = await request.json()
    except Exception:
        return JSONResponse({"error": "Invalid JSON"}, status_code=400)

    discord_id = str(body.get("discord_id", ""))
    points = body.get("points", 1)
    activity_type = body.get("activity_type", "discord_message")
    description = body.get("description", "Discord activity")

    user = models.get_user_by_discord_id(discord_id)
    if not user:
        return JSONResponse({"status": "ignored", "reason": "unlinked"})

    models.add_interaction_points(user["id"], points, activity_type, description)
    new_level = models.check_level_up(user["id"])

    result = {"status": "ok", "points": points}
    if new_level:
        result["level_up"] = new_level
    return JSONResponse(result)


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
