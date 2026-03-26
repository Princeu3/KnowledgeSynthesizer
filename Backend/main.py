"""
Knowledge Synthesizer - FastAPI Backend

Provides content extraction, Vision AI analysis, and LLM processing
for the iOS Knowledge Synthesizer app.
"""

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from config import get_settings
from models.schemas import HealthResponse
from routers import extract

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)


@asynccontextmanager
async def lifespan(app: FastAPI):
    settings = get_settings()
    logging.info(f"Starting {settings.app_name}")
    yield
    logging.info("Shutting down")


app = FastAPI(
    title="Knowledge Synthesizer API",
    version="0.1.0",
    lifespan=lifespan,
)

# CORS - allow iOS app to connect
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Restrict in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Routers
app.include_router(extract.router)


@app.get("/health", response_model=HealthResponse)
async def health_check():
    return HealthResponse(status="ok")


@app.get("/")
async def root():
    return {"message": "Knowledge Synthesizer API", "docs": "/docs"}
