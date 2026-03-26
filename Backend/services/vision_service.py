"""
Video Analysis Service - uses Gemini 2.5 Flash for full video understanding.

Sends the entire video file to Gemini for combined visual + audio analysis.
Single API call extracts: speech transcript, visual description, topics,
entities, on-screen text, and educational takeaways.
"""

import io
import json
import logging
import tempfile
from pathlib import Path
from typing import Any

import httpx
from google import genai
from google.genai import types
from PIL import Image

logger = logging.getLogger(__name__)


class VisionService:
    """Multimodal AI analysis using Gemini - video, audio, and images."""

    VIDEO_ANALYSIS_PROMPT = """You are analyzing an Instagram Reel video. Listen to the audio AND watch the visuals carefully.

Extract the following as structured JSON:

{
  "transcript": "Full word-for-word transcription of everything spoken in the video. If no speech, use empty string.",
  "description": "A concise description of what's visually shown in the video (2-3 sentences)",
  "topics": ["key topic 1", "key topic 2", ...],
  "on_screen_text": "Any text overlaid or visible on screen (exact text, or empty string)",
  "entities": ["person/brand/product/tool names mentioned or shown"],
  "educational_takeaway": "If educational content: the core lesson or key information shared (or empty string)",
  "mood": "The overall mood/tone (e.g. informational, entertaining, tutorial, promotional)"
}

IMPORTANT:
- The transcript should capture ALL spoken words accurately
- Be specific and factual about what you see and hear
- Include brand names, technical terms, and proper nouns exactly as spoken"""

    IMAGE_ANALYSIS_PROMPT = """Analyze this image. Extract the following as structured JSON:

{
  "transcript": "",
  "description": "A concise description of what's shown (1-2 sentences)",
  "topics": ["key topic 1", "key topic 2", ...],
  "on_screen_text": "Any text visible on screen (exact text, or empty string)",
  "entities": ["person/brand/product/tool names mentioned or shown"],
  "educational_takeaway": "If educational content: the core lesson (or empty string)",
  "mood": "The overall mood/tone"
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
            # Download the video
            async with httpx.AsyncClient(timeout=60.0) as client:
                resp = await client.get(video_url)
                resp.raise_for_status()
                video_bytes = resp.content

            logger.info(f"Downloaded video: {len(video_bytes) / 1024 / 1024:.1f}MB")

            # Upload video to Gemini Files API for processing
            with tempfile.NamedTemporaryFile(suffix=".mp4", delete=False) as tmp:
                tmp.write(video_bytes)
                tmp_path = tmp.name

            try:
                uploaded_file = self.client.files.upload(
                    file=tmp_path,
                    config=types.UploadFileConfig(mime_type="video/mp4"),
                )
                logger.info(f"Uploaded to Gemini Files API: {uploaded_file.name}")

                # Wait for file to be processed
                import time
                while uploaded_file.state.name == "PROCESSING":
                    time.sleep(1)
                    uploaded_file = self.client.files.get(name=uploaded_file.name)

                if uploaded_file.state.name == "FAILED":
                    raise Exception(f"Gemini file processing failed: {uploaded_file.state}")

                # Single API call: analyze video (visual + audio)
                response = self.client.models.generate_content(
                    model=self.model,
                    contents=[self.VIDEO_ANALYSIS_PROMPT, uploaded_file],
                )

                result = self._parse_response(response.text)
                logger.info(f"Video analysis complete. Transcript length: {len(result.get('transcript', ''))}")
                return result

            finally:
                # Clean up temp file
                Path(tmp_path).unlink(missing_ok=True)
                # Clean up uploaded file from Gemini
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
            return {
                "transcript": "",
                "description": text[:500],
                "topics": [],
                "on_screen_text": "",
                "entities": [],
                "educational_takeaway": "",
                "mood": "",
            }

    @staticmethod
    def _empty_result() -> dict[str, Any]:
        return {
            "transcript": "",
            "description": "",
            "topics": [],
            "on_screen_text": "",
            "entities": [],
            "educational_takeaway": "",
            "mood": "",
        }
