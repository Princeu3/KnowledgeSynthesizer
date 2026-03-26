"""
Content extraction router - handles incoming URLs and returns enriched knowledge.
"""

import logging

from fastapi import APIRouter, Depends, HTTPException

from config import Settings, get_settings
from models.schemas import ExtractionRequest, ExtractionResponse
from services.instagram_service import InstagramService, TokenExpiredError
from services.vision_service import VisionService

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/extract", tags=["extraction"])


def get_instagram_service(settings: Settings = Depends(get_settings)) -> InstagramService:
    return InstagramService(
        app_id=settings.instagram_app_id,
        app_secret=settings.instagram_app_secret,
        access_token=settings.instagram_access_token,
        own_ig_user_id=settings.instagram_user_id or None,
    )


def get_vision_service(settings: Settings = Depends(get_settings)) -> VisionService:
    return VisionService(api_key=settings.gemini_api_key)


@router.post("/instagram", response_model=ExtractionResponse)
async def extract_instagram(
    request: ExtractionRequest,
    instagram: InstagramService = Depends(get_instagram_service),
    vision: VisionService = Depends(get_vision_service),
):
    """
    Extract knowledge from an Instagram URL (reels, posts).
    Uses Business Discovery API with system token - no per-user OAuth needed.
    """
    try:
        # Step 1: Fetch metadata from Instagram Graph API (Business Discovery)
        data = await instagram.extract_from_url(request.url)

        # Step 2: If we got a media_url (video), analyze with Vision AI
        vision_analysis = None
        vision_topics: list[str] = []
        vision_entities: list[str] = []

        media_url = data.get("media_url")
        if media_url:
            try:
                analysis = await vision.analyze_video_url(media_url)
                vision_analysis = _format_vision_analysis(analysis)
                vision_topics = analysis.get("topics", [])
                vision_entities = analysis.get("entities", [])
            except Exception as e:
                logger.warning(f"Vision analysis failed, continuing without: {e}")

        # Merge topics and entities from Instagram metadata + vision
        all_topics = list(set(data.get("topics", []) + vision_topics))
        all_entities = list(set(data.get("entities", []) + vision_entities))

        return ExtractionResponse(
            title=data.get("title", ""),
            content=data.get("content", ""),
            thumbnail_url=data.get("thumbnail_url"),
            vision_analysis=vision_analysis,
            topics=all_topics,
            entities=all_entities,
            category="instagram",
            content_date=data.get("content_date"),
            metadata=data.get("metadata"),
        )

    except TokenExpiredError:
        raise HTTPException(
            status_code=401,
            detail="Instagram access token expired. Please reconnect.",
        )
    except Exception as e:
        logger.error(f"Instagram extraction failed: {e}")
        # Return a minimal response with just the URL
        return ExtractionResponse(
            title=f"Instagram: {request.url}",
            content=f"Shared from Instagram: {request.url}",
            topics=[],
            entities=[],
            metadata={"source_url": request.url, "error": str(e)},
        )


def _format_vision_analysis(analysis: dict) -> str:
    """Format vision analysis dict into readable text."""
    parts: list[str] = []

    if desc := analysis.get("description"):
        parts.append(f"Visual: {desc}")
    if text := analysis.get("on_screen_text"):
        parts.append(f"On-screen text: {text}")
    if takeaway := analysis.get("educational_takeaway"):
        parts.append(f"Key takeaway: {takeaway}")
    if mood := analysis.get("mood"):
        parts.append(f"Mood: {mood}")

    return "\n".join(parts) if parts else ""
