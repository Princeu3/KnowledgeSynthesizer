"""
Instagram Graph API Service - adapted from Trufluence patterns.

Fetches reel metadata, captions, media URLs, and engagement metrics
via Instagram Graph API v20.0 (Business Discovery + OAuth).
"""

import logging
import re
from typing import Any, Optional

import httpx
from tenacity import (
    before_sleep_log,
    retry,
    retry_if_exception_type,
    stop_after_attempt,
    wait_exponential,
)

logger = logging.getLogger(__name__)


class RateLimitExceeded(Exception):
    pass


class TokenExpiredError(Exception):
    pass


class ExtractionFailedError(Exception):
    """Raised when content extraction fails and should be shown as failed."""
    pass


class InstagramService:
    """Instagram Graph API client for knowledge extraction."""

    BASE_URL = "https://graph.facebook.com/v20.0"

    def __init__(
        self,
        app_id: str,
        app_secret: str,
        access_token: str,
        own_ig_user_id: str | None = None,
    ):
        if not app_id:
            raise ValueError("Instagram App ID is required")
        if not access_token:
            raise ValueError("Instagram Access Token is required")

        self.app_id = app_id
        self.app_secret = app_secret
        self.access_token = access_token
        self.own_ig_user_id = own_ig_user_id

        limits = httpx.Limits(max_keepalive_connections=10, max_connections=20)
        self.client = httpx.AsyncClient(
            timeout=30.0, limits=limits, http2=True
        )

    async def close(self):
        await self.client.aclose()

    # ── API Request with retry ─────────────────────────────────────

    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=2, max=10),
        retry=retry_if_exception_type((httpx.HTTPStatusError, httpx.RequestError)),
        before_sleep=before_sleep_log(logger, logging.WARNING),
        reraise=True,
    )
    async def _make_request(
        self, endpoint: str, params: dict[str, Any] | None = None
    ) -> dict[str, Any]:
        url = f"{self.BASE_URL}/{endpoint}"
        if params is None:
            params = {}
        params["access_token"] = self.access_token

        try:
            response = await self.client.get(url, params=params)

            if response.status_code == 429:
                raise RateLimitExceeded("Instagram API rate limit hit")

            response.raise_for_status()
            return response.json()

        except httpx.HTTPStatusError as e:
            error_data = {}
            try:
                error_data = e.response.json()
            except Exception:
                pass

            error_code = error_data.get("error", {}).get("code")
            if error_code == 190:
                raise TokenExpiredError(
                    "Instagram access token is invalid or expired"
                )
            if error_code == 4:
                raise RateLimitExceeded("Instagram API rate limit exceeded")

            logger.error(f"Instagram API error: {error_data}")
            raise

    # ── OAuth Token Exchange ───────────────────────────────────────

    async def exchange_code_for_token(
        self, code: str, redirect_uri: str
    ) -> dict[str, Any]:
        """Exchange authorization code for short-lived token, then long-lived."""
        # Step 1: Short-lived token
        short_resp = await self.client.post(
            "https://api.instagram.com/oauth/access_token",
            data={
                "client_id": self.app_id,
                "client_secret": self.app_secret,
                "grant_type": "authorization_code",
                "redirect_uri": redirect_uri,
                "code": code,
            },
        )
        short_resp.raise_for_status()
        short_data = short_resp.json()
        short_token = short_data["access_token"]
        user_id = short_data.get("user_id")

        # Step 2: Exchange for long-lived token (60 days)
        long_resp = await self.client.get(
            "https://graph.instagram.com/access_token",
            params={
                "grant_type": "ig_exchange_token",
                "client_secret": self.app_secret,
                "access_token": short_token,
            },
        )
        long_resp.raise_for_status()
        long_data = long_resp.json()

        return {
            "access_token": long_data["access_token"],
            "token_type": "bearer",
            "expires_in": long_data.get("expires_in"),
            "instagram_user_id": str(user_id),
        }

    # ── Extract Reel from URL ──────────────────────────────────────

    async def extract_from_url(self, url: str) -> dict[str, Any]:
        """
        Extract knowledge from an Instagram URL.
        Tries to fetch via Graph API if we have a token,
        otherwise returns just the parsed URL metadata.
        """
        shortcode = self._extract_shortcode(url)
        username = self._parse_username_from_url(url)

        # If no username in URL (e.g. instagram.com/reel/CODE), resolve via oEmbed
        if not username and shortcode:
            username = await self._resolve_username_from_oembed(url)
            logger.info(f"Resolved username from oEmbed: {username}")

        if not username:
            raise ExtractionFailedError(
                f"Could not resolve Instagram username from URL: {url}"
            )

        if not self.own_ig_user_id:
            raise ExtractionFailedError("Instagram user ID not configured")

        profile = await self._fetch_profile(username)

        # Search up to 4 pages (200 items) for the specific reel
        matching = await self._search_media_paginated(
            username, url, max_pages=10
        )
        if not matching:
            raise ExtractionFailedError(
                f"Reel not found in @{username}'s recent posts "
                f"(searched 500 items). Shortcode: {shortcode}"
            )

        result: dict[str, Any] = {
            "title": (matching.get("caption") or "")[:80],
            "content": matching.get("caption") or "",
            "thumbnail_url": matching.get("thumbnail_url"),
            "media_url": matching.get("media_url"),
            "topics": [],
            "entities": [],
            "content_date": matching.get("timestamp"),
            "metadata": {
                "source_url": url,
                "platform": "instagram",
                "media_type": matching.get("media_type", ""),
                "like_count": str(matching.get("like_count", 0)),
                "comments_count": str(matching.get("comments_count", 0)),
                "permalink": matching.get("permalink", url),
                "username": username,
                "followers": str(profile.get("followers_count", 0)),
            },
        }

        return result

    # ── Internal helpers ───────────────────────────────────────────

    async def _resolve_username_from_oembed(self, url: str) -> str | None:
        """Resolve username from any Instagram URL by fetching the page.

        Works for instagram.com/reel/CODE URLs that don't have a username.
        Instagram's HTML contains the username in internal URL patterns.
        """
        try:
            resp = await self.client.get(
                url,
                headers={
                    "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
                    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                    "Accept-Language": "en-US,en;q=0.9",
                },
                follow_redirects=True,
            )
            if resp.status_code == 200:
                # Try username from URL pattern in HTML
                match = re.search(
                    r"instagram\.com/([a-zA-Z0-9_.]+)/(?:reel|p)/", resp.text
                )
                if match:
                    username = match.group(1)
                    if username not in ("reel", "p", "stories", "explore"):
                        return username
                # Fallback: try JSON embedded in page
                match2 = re.search(r'"username":"([^"]+)"', resp.text)
                if match2:
                    return match2.group(1)
        except Exception as e:
            logger.warning(f"Username resolution failed: {e}")
        return None

    async def _fetch_profile(self, username: str) -> dict[str, Any]:
        params = {
            "fields": f"business_discovery.username({username})"
            "{id,username,name,biography,followers_count,"
            "follows_count,media_count,profile_picture_url}"
        }
        data = await self._make_request(self.own_ig_user_id, params)
        return data.get("business_discovery", {})

    async def _search_media_paginated(
        self, username: str, url: str, max_pages: int = 4
    ) -> dict[str, Any] | None:
        """Search through paginated media to find a specific post by shortcode.

        Searches up to max_pages * 50 items, stopping early when found.
        """
        shortcode = self._extract_shortcode(url)
        if not shortcode:
            return None

        fields = (
            "id,caption,media_type,media_url,thumbnail_url,"
            "permalink,timestamp,like_count,comments_count"
        )
        after_cursor: str | None = None

        for page in range(max_pages):
            media_part = f"media.limit(50){{{fields}}}"
            if after_cursor:
                media_part = f"media.after({after_cursor}).limit(50){{{fields}}}"

            params = {
                "fields": f"business_discovery.username({username})"
                f"{{{media_part}}}"
            }
            data = await self._make_request(self.own_ig_user_id, params)
            media_obj = (
                data.get("business_discovery", {}).get("media", {})
            )
            items = media_obj.get("data", [])

            # Search this page for the matching shortcode
            for item in items:
                if shortcode in item.get("permalink", ""):
                    logger.info(
                        f"Found matching media on page {page + 1}"
                    )
                    return item

            # Get next page cursor
            after_cursor = (
                media_obj.get("paging", {})
                .get("cursors", {})
                .get("after")
            )
            if not after_cursor or not items:
                break

            logger.info(
                f"Media not found on page {page + 1}, "
                f"fetching next page..."
            )

        return None

    @staticmethod
    def _parse_username_from_url(url: str) -> str | None:
        """Extract username from instagram.com URLs.

        Handles formats:
          instagram.com/username/reel/CODE
          instagram.com/username/p/CODE
          instagram.com/username/
          instagram.com/reel/CODE  (no username - returns None)
        """
        # Pattern: instagram.com/USERNAME/reel|p/CODE
        match = re.search(
            r"instagram\.com/([a-zA-Z0-9_.]+)/(?:reel|p|stories)/", url
        )
        if match:
            return match.group(1)

        # Pattern: instagram.com/USERNAME (profile URL, no media)
        match = re.search(r"instagram\.com/([a-zA-Z0-9_.]+)/?(?:\?|$)", url)
        if match:
            username = match.group(1)
            excluded = {"reel", "p", "stories", "explore", "accounts", "direct"}
            if username not in excluded:
                return username

        return None

    @staticmethod
    def _extract_shortcode(url: str) -> str | None:
        """Extract reel/post shortcode from any Instagram URL format.

        Handles:
          instagram.com/reel/CODE
          instagram.com/username/reel/CODE
          instagram.com/p/CODE
          instagram.com/username/p/CODE
        """
        match = re.search(
            r"instagram\.com/(?:[a-zA-Z0-9_.]+/)?(?:reel|p)/([a-zA-Z0-9_-]+)",
            url,
        )
        return match.group(1) if match else None
