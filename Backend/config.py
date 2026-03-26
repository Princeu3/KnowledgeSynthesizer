from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    # Server
    app_name: str = "KnowledgeSynthesizer API"
    debug: bool = False

    # Instagram Graph API
    instagram_app_id: str = ""
    instagram_app_secret: str = ""
    instagram_access_token: str = ""
    instagram_user_id: str = ""

    # Gemini AI (for vision analysis)
    gemini_api_key: str = ""

    # Claude API (for entity extraction, RAG)
    anthropic_api_key: str = ""

    # Backend URL (for OAuth redirect)
    backend_url: str = "http://localhost:8000"

    model_config = {"env_file": ".env", "env_file_encoding": "utf-8"}


@lru_cache
def get_settings() -> Settings:
    return Settings()
