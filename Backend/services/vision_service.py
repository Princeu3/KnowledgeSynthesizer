"""
Vision AI Service - uses Gemini 2.5 Flash for analyzing images/video frames.

Extracts visual descriptions, topics, on-screen text, entities, and
educational takeaways from Instagram Reels frames.
"""

import base64
import io
import logging
import subprocess
import tempfile
from pathlib import Path
from typing import Any

import httpx
from google import genai
from PIL import Image

logger = logging.getLogger(__name__)


class VisionService:
    """Multimodal AI analysis of images and video frames."""

    ANALYSIS_PROMPT = """Analyze this frame from an Instagram Reel. Extract the following as structured JSON:

{
  "description": "A concise description of what's shown (1-2 sentences)",
  "topics": ["key topic 1", "key topic 2", ...],
  "on_screen_text": "Any text visible on screen (exact text, or empty string)",
  "entities": ["person/brand/product/tool names mentioned or shown"],
  "educational_takeaway": "If educational content: the core lesson (or empty string)",
  "mood": "The overall mood/tone (e.g. informational, entertaining, tutorial)"
}

Be specific and factual. Only include what you can actually see."""

    def __init__(self, api_key: str):
        if not api_key:
            raise ValueError("Gemini API key is required")
        self.client = genai.Client(api_key=api_key)
        self.model = "gemini-2.5-flash"

    async def analyze_image(self, image_bytes: bytes) -> dict[str, Any]:
        """Analyze a single image with Gemini Vision."""
        try:
            image = Image.open(io.BytesIO(image_bytes))

            response = self.client.models.generate_content(
                model=self.model,
                contents=[self.ANALYSIS_PROMPT, image],
            )

            return self._parse_response(response.text)

        except Exception as e:
            logger.error(f"Vision analysis failed: {e}")
            return self._empty_result()

    async def analyze_video_url(self, video_url: str, num_frames: int = 4) -> dict[str, Any]:
        """Download video, extract key frames, analyze with Gemini."""
        try:
            frames = await self._extract_frames_from_url(video_url, num_frames)
            if not frames:
                logger.warning("No frames extracted from video")
                return self._empty_result()

            # Analyze each frame and merge results
            all_results: list[dict[str, Any]] = []
            for frame_bytes in frames:
                result = await self.analyze_image(frame_bytes)
                all_results.append(result)

            return self._merge_frame_results(all_results)

        except Exception as e:
            logger.error(f"Video analysis failed: {e}")
            return self._empty_result()

    async def _extract_frames_from_url(
        self, video_url: str, num_frames: int = 4
    ) -> list[bytes]:
        """Download video and extract evenly-spaced frames using ffmpeg."""
        frames: list[bytes] = []

        try:
            async with httpx.AsyncClient(timeout=60.0) as client:
                resp = await client.get(video_url)
                resp.raise_for_status()
                video_bytes = resp.content

            with tempfile.TemporaryDirectory() as tmp_dir:
                video_path = Path(tmp_dir) / "video.mp4"
                video_path.write_bytes(video_bytes)

                # Get video duration
                probe = subprocess.run(
                    [
                        "ffprobe",
                        "-v", "quiet",
                        "-show_entries", "format=duration",
                        "-of", "default=noprint_wrappers=1:nokey=1",
                        str(video_path),
                    ],
                    capture_output=True,
                    text=True,
                )
                duration = float(probe.stdout.strip() or "10")

                # Extract frames at evenly spaced intervals
                for i in range(num_frames):
                    timestamp = (duration / (num_frames + 1)) * (i + 1)
                    output_path = Path(tmp_dir) / f"frame_{i}.jpg"

                    subprocess.run(
                        [
                            "ffmpeg",
                            "-ss", str(timestamp),
                            "-i", str(video_path),
                            "-vframes", "1",
                            "-q:v", "2",
                            str(output_path),
                        ],
                        capture_output=True,
                    )

                    if output_path.exists():
                        frames.append(output_path.read_bytes())

        except Exception as e:
            logger.error(f"Frame extraction failed: {e}")

        return frames

    def _parse_response(self, text: str) -> dict[str, Any]:
        """Parse Gemini JSON response, handling markdown code blocks."""
        import json

        cleaned = text.strip()
        if cleaned.startswith("```"):
            # Remove markdown code block wrapper
            lines = cleaned.split("\n")
            cleaned = "\n".join(lines[1:-1])

        try:
            return json.loads(cleaned)
        except json.JSONDecodeError:
            logger.warning(f"Failed to parse Gemini response as JSON: {text[:200]}")
            return {
                "description": text[:500],
                "topics": [],
                "on_screen_text": "",
                "entities": [],
                "educational_takeaway": "",
                "mood": "",
            }

    def _merge_frame_results(self, results: list[dict[str, Any]]) -> dict[str, Any]:
        """Merge analysis results from multiple frames into one."""
        if not results:
            return self._empty_result()

        descriptions = [r.get("description", "") for r in results if r.get("description")]
        all_topics: set[str] = set()
        all_entities: set[str] = set()
        all_text_parts: list[str] = []
        takeaways: list[str] = []

        for r in results:
            all_topics.update(r.get("topics", []))
            all_entities.update(r.get("entities", []))
            if r.get("on_screen_text"):
                all_text_parts.append(r["on_screen_text"])
            if r.get("educational_takeaway"):
                takeaways.append(r["educational_takeaway"])

        return {
            "description": " | ".join(descriptions[:3]),
            "topics": sorted(all_topics),
            "on_screen_text": "\n".join(all_text_parts),
            "entities": sorted(all_entities),
            "educational_takeaway": takeaways[0] if takeaways else "",
            "mood": results[0].get("mood", ""),
        }

    @staticmethod
    def _empty_result() -> dict[str, Any]:
        return {
            "description": "",
            "topics": [],
            "on_screen_text": "",
            "entities": [],
            "educational_takeaway": "",
            "mood": "",
        }
