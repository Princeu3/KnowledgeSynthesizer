# Knowledge Synthesizer

A native iOS app that captures knowledge from Instagram Reels (and soon other platforms) using AI-powered visual analysis. Share a reel link → the app extracts the caption, downloads the video, analyzes frames with Gemini Vision AI, and stores everything in a searchable knowledge base.

## How It Works

```
Share reel from Instagram → iOS Share Extension captures URL
    → Backend resolves username & fetches metadata via Instagram Graph API
    → Downloads video → Extracts key frames with ffmpeg
    → Gemini 2.5 Flash analyzes each frame (topics, entities, on-screen text)
    → Enriched knowledge item appears in your feed
```

## Features

- **iOS Share Extension** — Share links from Safari, Instagram, or any app
- **Instagram Reel Extraction** — Captions, thumbnails, engagement metrics via Graph API (Business Discovery, no OAuth needed)
- **AI Visual Analysis** — Gemini 2.5 Flash extracts descriptions, topics, entities, on-screen text from video frames
- **On-Device OCR** — Apple Vision framework for screenshot text extraction
- **Full-Text Search** — Search across all ingested content, topics, entities, and tags
- **Source Tracking** — Every item traced back to its original source
- **Auto-Enrichment** — Items are automatically enriched when saved

## Architecture

```
┌──────────────────────────────────┐
│   iOS App (SwiftUI + SwiftData)  │
│   ├─ Share Extension             │
│   ├─ Apple Vision OCR            │
│   ├─ Feed / Search / Add views   │
│   └─ Auto-enrichment service     │
└──────────────┬───────────────────┘
               │ HTTPS
               ▼
┌──────────────────────────────────┐
│   Backend (Python FastAPI)       │
│   ├─ Instagram Graph API         │
│   ├─ Gemini 2.5 Flash (Vision)  │
│   ├─ Video frame extraction      │
│   └─ Content enrichment pipeline │
└──────────────────────────────────┘
```

## Tech Stack

| Layer | Technology |
|-------|-----------|
| iOS App | SwiftUI, SwiftData, iOS 17+ |
| Share Extension | App Groups, NSExtensionItem |
| OCR | Apple Vision (VNRecognizeTextRequest) |
| Backend | Python 3.13, FastAPI, httpx |
| Instagram API | Graph API v20.0 (Business Discovery) |
| Vision AI | Gemini 2.5 Flash |
| Video Processing | ffmpeg |
| Deployment | Railway |

## Setup

### Backend

```bash
cd Backend
cp .env.example .env
# Fill in your API keys in .env

python3.13 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

uvicorn main:app --reload
```

### iOS App

1. Open `KnowledgeSynthesizer.xcodeproj` in Xcode
2. Set your Development Team in project settings
3. Run on simulator or device

### Required API Keys

| Key | Where to Get | Cost |
|-----|-------------|------|
| Instagram Graph API | [developers.facebook.com](https://developers.facebook.com) | Free |
| Gemini API | [aistudio.google.com](https://aistudio.google.com) | Free tier (1500 req/day) |

## Roadmap

Platforms are added one at a time:

- [x] Instagram Reels
- [ ] YouTube (transcripts + metadata)
- [ ] GitHub (READMEs, issues, code)
- [ ] Websites (article extraction)
- [ ] Screenshots/OCR
- [ ] Twitter/X
- [ ] LinkedIn
- [ ] Knowledge Graph visualization
- [ ] RAG-powered chat over your knowledge

## License

MIT
