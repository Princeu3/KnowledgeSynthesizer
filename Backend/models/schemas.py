from pydantic import BaseModel
from typing import Optional


class ExtractionRequest(BaseModel):
    url: str
    source_type: Optional[str] = None


class ExtractionResponse(BaseModel):
    title: str
    content: str
    thumbnail_url: Optional[str] = None
    vision_analysis: Optional[str] = None
    topics: list[str] = []
    entities: list[str] = []
    category: Optional[str] = None
    content_date: Optional[str] = None
    metadata: Optional[dict[str, str]] = None


class HealthResponse(BaseModel):
    status: str
    version: str = "0.1.0"
