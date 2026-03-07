"""
Smoke tests for Angel Cloud Gateway.
Tests health, auth, rate limiting, and session persistence.

Run: pytest tests/test_gateway.py -v
"""

import sys
import os
import tempfile
import shutil

# Add angel-cloud to path so gateway's bare imports work
ANGEL_DIR = os.path.join(os.path.dirname(__file__), "..", "angel-cloud")
sys.path.insert(0, ANGEL_DIR)

# Also add repo root for scripts/ imports
REPO_ROOT = os.path.join(os.path.dirname(__file__), "..")
sys.path.insert(0, REPO_ROOT)

# Use a temp DB so tests don't touch production data
_test_db = tempfile.mktemp(suffix=".db")
os.environ["ANGEL_CLOUD_DB"] = _test_db

import pytest
from fastapi.testclient import TestClient

# Patch models.DB_PATH before importing gateway
import models
models.DB_PATH = _test_db

# Monkey-patch weaviate_bridge functions to avoid needing a live Weaviate
import weaviate_bridge
weaviate_bridge.register_user_in_weaviate = lambda *a, **k: True
weaviate_bridge.get_weaviate_stats = lambda: {"weaviate": "offline"}
weaviate_bridge.update_friend_level = lambda *a, **k: True
weaviate_bridge.log_security_event = lambda *a, **k: True
weaviate_bridge.log_privacy_event = lambda *a, **k: True

# Monkey-patch chat_engine to avoid needing Ollama
import chat_engine
chat_engine.stream_response = lambda msg, user: iter(["test response"])
chat_engine.log_chat = lambda *a, **k: None

import gateway

client = TestClient(gateway.app)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture(autouse=True)
def reset_state():
    """Reset DB and rate limit state between tests."""
    models.init_db()
    gateway._login_attempts.clear()
    gateway._register_attempts.clear()
    yield
    # Clean up sessions table
    try:
        conn = models.get_db()
        conn.execute("DELETE FROM sessions")
        conn.execute("DELETE FROM users")
        conn.execute("DELETE FROM activity_log")
        conn.execute("DELETE FROM link_codes")
        conn.commit()
        conn.close()
    except Exception:
        pass


def _register(username="testuser", email="test@test.com", password="testpass123"):
    """Helper to register a user."""
    return client.post("/api/register", data={
        "username": username,
        "email": email,
        "password": password,
        "password_confirm": password,
    }, follow_redirects=False)


def _login(email="test@test.com", password="testpass123"):
    """Helper to login."""
    return client.post("/api/login", data={
        "email": email,
        "password": password,
    }, follow_redirects=False)


# ---------------------------------------------------------------------------
# Health & Public Endpoints
# ---------------------------------------------------------------------------

class TestHealth:
    def test_health_endpoint(self):
        resp = client.get("/api/health")
        assert resp.status_code == 200
        data = resp.json()
        assert data["status"] == "ok"
        assert data["service"] == "angel-cloud-gateway"
        assert "uptime_seconds" in data

    def test_stats_endpoint(self):
        resp = client.get("/api/stats")
        assert resp.status_code == 200
        data = resp.json()
        assert "users" in data
        assert "uptime_seconds" in data

    def test_landing_page(self):
        resp = client.get("/")
        assert resp.status_code == 200


# ---------------------------------------------------------------------------
# Registration
# ---------------------------------------------------------------------------

class TestRegistration:
    def test_register_success(self):
        resp = _register()
        assert resp.status_code == 303
        assert resp.headers["location"] == "/welcome"

    def test_register_duplicate_username(self):
        _register()
        resp = _register(email="other@test.com")
        assert resp.status_code == 409

    def test_register_duplicate_email(self):
        _register()
        resp = _register(username="other")
        assert resp.status_code == 409

    def test_register_password_mismatch(self):
        resp = client.post("/api/register", data={
            "username": "testuser",
            "email": "test@test.com",
            "password": "testpass123",
            "password_confirm": "different",
        }, follow_redirects=False)
        assert resp.status_code == 400

    def test_register_short_password(self):
        resp = client.post("/api/register", data={
            "username": "testuser",
            "email": "test@test.com",
            "password": "short",
            "password_confirm": "short",
        }, follow_redirects=False)
        assert resp.status_code == 400

    def test_register_invalid_username(self):
        resp = client.post("/api/register", data={
            "username": "ab",  # too short
            "email": "test@test.com",
            "password": "testpass123",
            "password_confirm": "testpass123",
        }, follow_redirects=False)
        assert resp.status_code == 400


# ---------------------------------------------------------------------------
# Login
# ---------------------------------------------------------------------------

class TestLogin:
    def test_login_success(self):
        _register()
        resp = _login()
        assert resp.status_code == 303
        assert resp.headers["location"] == "/welcome"
        assert "session" in resp.cookies

    def test_login_wrong_password(self):
        _register()
        resp = _login(password="wrongpassword")
        assert resp.status_code == 401

    def test_login_nonexistent_email(self):
        resp = _login(email="nobody@test.com")
        assert resp.status_code == 401


# ---------------------------------------------------------------------------
# Rate Limiting
# ---------------------------------------------------------------------------

class TestRateLimiting:
    def test_login_rate_limit(self):
        """After 5 failed attempts, 6th should return 429."""
        _register()
        for i in range(5):
            resp = _login(password="wrong")
            assert resp.status_code == 401
        resp = _login(password="wrong")
        assert resp.status_code == 429

    def test_successful_login_clears_rate_limit(self):
        """Successful login resets the counter."""
        _register()
        for i in range(3):
            _login(password="wrong")
        # Successful login
        resp = _login()
        assert resp.status_code == 303
        # Should be able to fail again without hitting limit
        resp = _login(password="wrong")
        assert resp.status_code == 401

    def test_registration_rate_limit(self):
        """After 3 registrations, 4th should return 429."""
        for i in range(3):
            _register(username=f"user{i}", email=f"user{i}@test.com")
        resp = _register(username="user3", email="user3@test.com")
        assert resp.status_code == 429


# ---------------------------------------------------------------------------
# Sessions
# ---------------------------------------------------------------------------

class TestSessions:
    def test_session_persists(self):
        """Session cookie should authenticate subsequent requests."""
        _register()
        resp = _login()
        cookies = resp.cookies
        # Access welcome page with session
        resp = client.get("/welcome", cookies=cookies)
        assert resp.status_code == 200

    def test_no_session_redirects(self):
        """Protected pages redirect to login without session."""
        resp = client.get("/welcome", follow_redirects=False)
        assert resp.status_code == 303
        assert "/login" in resp.headers["location"]

    def test_logout_clears_session(self):
        """After logout, session cookie should be invalid."""
        _register()
        resp = _login()
        cookies = resp.cookies
        # Logout
        client.get("/logout", cookies=cookies)
        # Session should now be invalid
        resp = client.get("/welcome", cookies=cookies, follow_redirects=False)
        assert resp.status_code == 303

    def test_chat_requires_auth(self):
        resp = client.get("/chat", follow_redirects=False)
        assert resp.status_code == 303

    def test_profile_requires_auth(self):
        resp = client.get("/profile", follow_redirects=False)
        assert resp.status_code == 303


# ---------------------------------------------------------------------------
# Password Change
# ---------------------------------------------------------------------------

class TestPasswordChange:
    def test_change_password(self):
        _register()
        resp = _login()
        cookies = resp.cookies
        resp = client.post("/api/password", data={
            "current_password": "testpass123",
            "new_password": "newpass12345",
            "new_password_confirm": "newpass12345",
        }, cookies=cookies, follow_redirects=False)
        assert resp.status_code == 303
        assert "success" in resp.headers["location"].lower()

        # Old password should fail
        resp = _login(password="testpass123")
        assert resp.status_code == 401

        # New password should work
        resp = _login(password="newpass12345")
        assert resp.status_code == 303

    def test_wrong_current_password(self):
        _register()
        resp = _login()
        cookies = resp.cookies
        resp = client.post("/api/password", data={
            "current_password": "wrongcurrent",
            "new_password": "newpass12345",
            "new_password_confirm": "newpass12345",
        }, cookies=cookies, follow_redirects=False)
        assert resp.status_code == 303
        assert "error" in resp.headers["location"].lower()


# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------

@pytest.fixture(scope="session", autouse=True)
def cleanup_test_db():
    yield
    try:
        os.unlink(_test_db)
    except Exception:
        pass
