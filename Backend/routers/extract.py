"""
Content extraction router - handles incoming URLs and returns enriched knowledge.
"""

import logging

from fastapi import APIRouter, Depends, HTTPException

from config import Settings, get_settings
from models.schemas import ExtractionRequest, ExtractionResponse
from services.instagram_service import InstagramService, TokenExpiredError, ExtractionFailedError
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

        # Step 2: If we got a media_url (video), analyze with Gemini
        analysis = {}
        media_url = data.get("media_url")
        if media_url:
            try:
                analysis = await vision.analyze_video_url(media_url)
            except Exception as e:
                logger.warning(f"Vision analysis failed, continuing without: {e}")

        # Use AI-generated title if available, fall back to caption
        title = analysis.get("title") or data.get("title", "")

        # Build clean content: summary bullets as primary content
        summary_bullets = analysis.get("summary", [])
        transcript = analysis.get("transcript", "")
        caption = data.get("content", "")

        content_parts = []
        if summary_bullets:
            content_parts.append("\n".join(f"• {b}" for b in summary_bullets))
        if caption:
            content_parts.append(f"\nCaption: {caption}")
        if transcript:
            content_parts.append(f"\nTranscript: {transcript}")

        full_content = "\n".join(content_parts) if content_parts else caption

        # Build vision_analysis as a readable summary
        vision_analysis = "\n".join(f"• {b}" for b in summary_bullets) if summary_bullets else None

        # Merge topics and entities
        all_topics = list(set(data.get("topics", []) + analysis.get("topics", [])))
        all_entities = list(set(data.get("entities", []) + analysis.get("entities", [])))

        # Add resources to metadata
        metadata = data.get("metadata", {})
        resources = analysis.get("resources", [])
        if resources:
            metadata["resources"] = ", ".join(resources)
        if analysis.get("mood"):
            metadata["mood"] = analysis["mood"]

        return ExtractionResponse(
            title=title,
            content=full_content,
            thumbnail_url=data.get("thumbnail_url"),
            vision_analysis=vision_analysis,
            topics=all_topics,
            entities=all_entities,
            category="instagram",
            content_date=data.get("content_date"),
            metadata=metadata,
        )

    except TokenExpiredError:
        raise HTTPException(
            status_code=401,
            detail="Instagram access token expired. Please reconnect.",
        )
    except ExtractionFailedError as e:
        logger.warning(f"Extraction failed: {e}")
        raise HTTPException(status_code=422, detail=str(e))
    except Exception as e:
        logger.error(f"Instagram extraction failed: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Extraction error: {e}",
        )
