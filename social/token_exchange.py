"""
Facebook Token Exchange Utility.
Port of mini-shanebrain's token-setup.js to Python.

Exchanges a short-lived user token for a PERMANENT page access token.

Flow:
  1. Short-lived User Token (~1 hour)
  2. -> Long-lived User Token (~60 days)
  3. -> Page Access Token (NEVER expires)

Usage:
  python -m social.token_exchange YOUR_SHORT_LIVED_TOKEN

Get your short-lived token from:
  https://developers.facebook.com/tools/explorer/
  - Select your app
  - Add permissions: pages_manage_posts, pages_read_engagement
  - Click "Generate Access Token"
  - Copy the token and pass it to this script
"""

import sys
import requests
from pathlib import Path
from . import config

# Colors
GREEN = '\033[92m'
RED = '\033[91m'
YELLOW = '\033[93m'
BLUE = '\033[94m'
CYAN = '\033[96m'
DIM = '\033[2m'
RESET = '\033[0m'


def log(msg, level="info"):
    prefix = {
        "info": f"{CYAN}[INFO]{RESET}",
        "success": f"{GREEN}[OK]{RESET}",
        "warn": f"{YELLOW}[WARN]{RESET}",
        "error": f"{RED}[ERROR]{RESET}",
    }
    print(f"{prefix.get(level, '')} {msg}")


def get_long_lived_user_token(short_token, app_id, app_secret):
    """Step 1: Exchange short-lived token for long-lived user token."""
    url = f"{config.GRAPH_API_BASE}/oauth/access_token"
    resp = requests.get(url, params={
        "grant_type": "fb_exchange_token",
        "client_id": app_id,
        "client_secret": app_secret,
        "fb_exchange_token": short_token,
    })
    data = resp.json()

    if "error" in data:
        raise RuntimeError(f"Token exchange failed: {data['error']['message']}")

    return {"token": data["access_token"], "expires_in": data.get("expires_in", 0)}


def get_page_access_token(long_lived_user_token, page_id):
    """Step 2: Get permanent page access token using long-lived user token."""
    url = f"{config.GRAPH_API_BASE}/me/accounts"
    resp = requests.get(url, params={"access_token": long_lived_user_token})
    data = resp.json()

    if "error" in data:
        raise RuntimeError(f"Page token request failed: {data['error']['message']}")

    pages = data.get("data", [])
    page = next((p for p in pages if p["id"] == page_id), None)

    if not page:
        available = "\n  ".join(f"{p['name']} ({p['id']})" for p in pages) or "none"
        raise RuntimeError(
            f"Page ID {page_id} not found. Available pages:\n  {available}\n"
            f"Update FACEBOOK_PAGE_ID in .env if needed."
        )

    return {"token": page["access_token"], "name": page["name"], "id": page["id"]}


def debug_token(token, app_id, app_secret):
    """Verify a token and check if it expires."""
    url = f"{config.GRAPH_API_BASE}/debug_token"
    resp = requests.get(url, params={
        "input_token": token,
        "access_token": f"{app_id}|{app_secret}",
    })
    data = resp.json()

    if "error" in data:
        return {"valid": False, "error": data["error"]["message"]}

    info = data.get("data", {})
    expires_at = info.get("expires_at", 0)
    return {
        "valid": info.get("is_valid", False),
        "expires": "NEVER" if expires_at == 0 else str(expires_at),
        "scopes": info.get("scopes", []),
        "type": info.get("type", "unknown"),
    }


def update_env_token(new_token):
    """Update .env file with new token."""
    env_path = config.SHANEBRAIN_ROOT / ".env"
    content = env_path.read_text()

    if "FACEBOOK_ACCESS_TOKEN=" in content:
        import re
        content = re.sub(r"FACEBOOK_ACCESS_TOKEN=.*", f"FACEBOOK_ACCESS_TOKEN={new_token}", content)
    else:
        content += f"\nFACEBOOK_ACCESS_TOKEN={new_token}\n"

    env_path.write_text(content)


def main():
    print(f"\n{CYAN}{'='*50}{RESET}")
    print(f"{CYAN}  Facebook Token Setup — ShaneBrain Social{RESET}")
    print(f"{CYAN}{'='*50}{RESET}\n")

    short_token = sys.argv[1] if len(sys.argv) > 1 else None
    app_id = config.FB_APP_ID
    app_secret = config.FB_APP_SECRET
    page_id = config.FACEBOOK_PAGE_ID

    if not short_token:
        print("Usage: python -m social.token_exchange YOUR_SHORT_LIVED_TOKEN\n")
        print("Steps:")
        print("  1. Go to https://developers.facebook.com/tools/explorer/")
        print("  2. Select your app from the dropdown")
        print('  3. Click "Add a Permission" -> pages_manage_posts, pages_read_engagement')
        print('  4. Click "Generate Access Token" and authorize')
        print("  5. Copy the token and run:\n")
        print("     python -m social.token_exchange PASTE_TOKEN_HERE\n")
        return

    if not app_id or not app_secret:
        log("Missing FB_APP_ID or FB_APP_SECRET in .env", "error")
        return

    # Step 1
    log("Step 1/3: Exchanging for long-lived user token...")
    long_lived = get_long_lived_user_token(short_token, app_id, app_secret)
    days = round(long_lived["expires_in"] / 86400) if long_lived["expires_in"] else "?"
    log(f"Long-lived user token obtained (expires in {days} days)", "success")

    # Step 2
    log("Step 2/3: Getting permanent page access token...")
    page = get_page_access_token(long_lived["token"], page_id)
    log(f"Page token obtained for: {page['name']}", "success")

    # Step 3
    log("Step 3/3: Verifying token is permanent...")
    debug = debug_token(page["token"], app_id, app_secret)

    if debug["valid"]:
        log(f"Token valid! Expires: {debug['expires']}", "success")
        log(f"Scopes: {', '.join(debug['scopes'])}", "info")
    else:
        log(f"Token verification issue: {debug.get('error', 'unknown')}", "warn")
        log("Token was still saved — it may work fine.", "warn")

    # Save
    update_env_token(page["token"])
    log("Token saved to .env", "success")

    expires_msg = "NEVER expires" if debug.get("expires") == "NEVER" else "is set"
    print(f"\n{GREEN}Done!{RESET} Your page token {expires_msg}.")
    print(f"Test it: {CYAN}python -m social.fb_bot --verify{RESET}\n")


if __name__ == "__main__":
    main()
