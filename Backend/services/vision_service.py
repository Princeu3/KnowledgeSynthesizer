"""
Video Analysis Service - uses Gemini 2.5 Flash for full video understanding.

Sends the entire video file to Gemini for combined visual + audio analysis.
Single API call extracts: speech transcript, summary bullets, topics,
entities, resources, and key takeaways.
"""

import io
import json
import logging
import tempfile
import time
from pathlib import Path
from typing import Any

import httpx
from google import genai
from google.genai import types
from PIL import Image

logger = logging.getLogger(__name__)


class VisionService:
    """Multimodal AI analysis using Gemini - video, audio, and images."""

    VIDEO_ANALYSIS_PROMPT = """You are a knowledge extraction assistant. Analyze this Instagram Reel video — listen to the audio AND watch the visuals.

Your job is to SYNTHESIZE the knowledge from this reel into a clean, useful format someone can quickly scan later.

Return structured JSON:

{
  "summary": [
    "Key point 1 — the most important takeaway",
    "Key point 2 — another important detail",
    "Key point 3 — etc (3-6 bullet points max)"
  ],
  "title": "A clear, descriptive title for this knowledge item (not the caption, but what the reel is actually about)",
  "transcript": "Full word-for-word transcription of everything spoken. If no speech, use empty string.",
  "topics": ["topic1", "topic2"],
  "entities": ["specific names of people, companies, tools, or products mentioned"],
  "resources": ["Any URLs, book titles, tools, or references mentioned that the viewer should check out"],
  "mood": "informational | tutorial | entertainment | promotional | opinion"
}

RULES:
- summary bullets should be ACTIONABLE knowledge, not descriptions of the video
- Write bullets as if you're taking notes for yourself — direct, no fluff
- Translate non-English speech to English in the summary (keep original transcript as-is)
- entities should only include proper nouns (Netflix, Python, etc.), not generic terms
- resources should capture anything the creator recommends (links, tools, books, blogs)"""

    IMAGE_ANALYSIS_PROMPT = """You are a knowledge extraction assistant. Analyze this image and extract useful knowledge.

Return structured JSON:

{
  "summary": ["Key point 1", "Key point 2"],
  "title": "What this image is about",
  "transcript": "",
  "topics": ["topic1", "topic2"],
  "entities": ["proper nouns only"],
  "resources": [],
  "mood": "informational"
}

Be specific and factual. Only include what you can actually see."""

    def __init__(self, api_key: str):
        if not api_key:
            raise ValueError("Gemini API key is required")
        self.client = genai.Client(api_key=api_key)
        self.model = "gemini-2.5-flash"

    async def analyze_video_url(self, video_url: str) -> dict[str, Any]:
        """Download video and analyze with Gemini (single API call for audio + visual)."""
        try:
            async with httpx.AsyncClient(timeout=60.0) as client:
                resp = await client.get(video_url)
                resp.raise_for_status()
                video_bytes = resp.content

            logger.info(f"Downloaded video: {len(video_bytes) / 1024 / 1024:.1f}MB")

            with tempfile.NamedTemporaryFile(suffix=".mp4", delete=False) as tmp:
                tmp.write(video_bytes)
                tmp_path = tmp.name

            try:
                uploaded_file = self.client.files.upload(
                    file=tmp_path,
                    config=types.UploadFileConfig(mime_type="video/mp4"),
                )
                logger.info(f"Uploaded to Gemini Files API: {uploaded_file.name}")

                while uploaded_file.state.name == "PROCESSING":
                    time.sleep(1)
                    uploaded_file = self.client.files.get(name=uploaded_file.name)

                if uploaded_file.state.name == "FAILED":
                    raise Exception(f"Gemini file processing failed: {uploaded_file.state}")

                response = self.client.models.generate_content(
                    model=self.model,
                    contents=[self.VIDEO_ANALYSIS_PROMPT, uploaded_file],
                )

                result = self._parse_response(response.text)
                logger.info(f"Video analysis complete. Summary points: {len(result.get('summary', []))}")
                return result

            finally:
                Path(tmp_path).unlink(missing_ok=True)
                try:
                    self.client.files.delete(name=uploaded_file.name)
                except Exception:
                    pass

        except Exception as e:
            logger.error(f"Video analysis failed: {e}")
            return self._empty_result()

    async def analyze_image(self, image_bytes: bytes) -> dict[str, Any]:
        """Analyze a single image with Gemini Vision."""
        try:
            image = Image.open(io.BytesIO(image_bytes))
            response = self.client.models.generate_content(
                model=self.model,
                contents=[self.IMAGE_ANALYSIS_PROMPT, image],
            )
            return self._parse_response(response.text)
        except Exception as e:
            logger.error(f"Image analysis failed: {e}")
            return self._empty_result()

    def _parse_response(self, text: str) -> dict[str, Any]:
        """Parse Gemini JSON response, handling markdown code blocks."""
        cleaned = text.strip()
        if cleaned.startswith("```"):
            lines = cleaned.split("\n")
            cleaned = "\n".join(lines[1:-1])

        try:
            return json.loads(cleaned)
        except json.JSONDecodeError:
            logger.warning(f"Failed to parse Gemini response as JSON: {text[:200]}")
            return self._empty_result()

    @staticmethod
    def _empty_result() -> dict[str, Any]:
        return {
            "summary": [],
            "title": "",
            "transcript": "",
            "topics": [],
            "entities": [],
            "resources": [],
            "mood": "",
        }
