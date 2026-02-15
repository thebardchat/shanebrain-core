"""
Facebook Graph API wrapper.
Port of mini-shanebrain's facebook.js to Python.
"""

import requests
from typing import Optional
from . import config


class FacebookAPI:
    """Handles all Facebook Graph API interactions."""

    def __init__(self, page_id=None, access_token=None):
        self.page_id = page_id or config.FACEBOOK_PAGE_ID
        self.access_token = access_token or config.FACEBOOK_ACCESS_TOKEN
        self.base = config.GRAPH_API_BASE

        if not self.page_id or not self.access_token:
            raise RuntimeError("Missing FACEBOOK_PAGE_ID or FACEBOOK_ACCESS_TOKEN")

    def post(self, message: str) -> dict:
        """Post a text message to the Facebook page."""
        url = f"{self.base}/{self.page_id}/feed"
        resp = requests.post(url, json={
            "message": message,
            "access_token": self.access_token,
        })
        data = resp.json()

        if "error" in data:
            raise RuntimeError(f"Facebook API Error: {data['error']['message']}")

        return {"success": True, "post_id": data["id"], "message": message}

    def post_with_image(self, message: str, image_url: str) -> dict:
        """Post a message with an image URL to the Facebook page."""
        url = f"{self.base}/{self.page_id}/photos"
        resp = requests.post(url, json={
            "message": message,
            "url": image_url,
            "access_token": self.access_token,
        })
        data = resp.json()

        if "error" in data:
            raise RuntimeError(f"Facebook API Error: {data['error']['message']}")

        return {"success": True, "post_id": data.get("post_id", data.get("id")), "message": message}

    def get_recent_posts(self, limit: int = 5) -> list:
        """Get recent posts from the page."""
        url = f"{self.base}/{self.page_id}/posts"
        resp = requests.get(url, params={
            "limit": limit,
            "access_token": self.access_token,
        })
        data = resp.json()

        if "error" in data:
            raise RuntimeError(f"Facebook API Error: {data['error']['message']}")

        return data.get("data", [])

    def get_post_comments(self, post_id: str, limit: int = 100) -> list:
        """Get comments on a specific post."""
        url = f"{self.base}/{post_id}/comments"
        resp = requests.get(url, params={
            "limit": limit,
            "fields": "id,from,message,created_time,like_count",
            "access_token": self.access_token,
        })
        data = resp.json()

        if "error" in data:
            raise RuntimeError(f"Facebook API Error: {data['error']['message']}")

        return data.get("data", [])

    def reply_to_comment(self, comment_id: str, message: str) -> dict:
        """Reply to a comment."""
        url = f"{self.base}/{comment_id}/comments"
        resp = requests.post(url, json={
            "message": message,
            "access_token": self.access_token,
        })
        data = resp.json()

        if "error" in data:
            raise RuntimeError(f"Facebook API Error: {data['error']['message']}")

        return {"success": True, "comment_id": data.get("id")}

    def get_post_engagement(self, post_id: str) -> dict:
        """Get engagement stats for a post."""
        url = f"{self.base}/{post_id}"
        resp = requests.get(url, params={
            "fields": "likes.summary(true),comments.summary(true),shares",
            "access_token": self.access_token,
        })
        data = resp.json()

        if "error" in data:
            raise RuntimeError(f"Facebook API Error: {data['error']['message']}")

        return {
            "likes": data.get("likes", {}).get("summary", {}).get("total_count", 0),
            "comments": data.get("comments", {}).get("summary", {}).get("total_count", 0),
            "shares": data.get("shares", {}).get("count", 0),
        }

    def verify_token(self) -> dict:
        """Verify the access token is valid."""
        url = f"{self.base}/me"
        resp = requests.get(url, params={"access_token": self.access_token})
        data = resp.json()

        if "error" in data:
            return {"valid": False, "error": data["error"]["message"]}

        return {"valid": True, "name": data.get("name"), "id": data.get("id")}
