from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
import os, httpx

router = APIRouter()

SYSTEM_PROMPT = """You are an SEC compliance expert specializing in ETF disclosure review. 
Analyze the provided fund disclosure text for:
1. Regulatory compliance issues (N-1A, Securities Act, Investment Company Act requirements)
2. Factual consistency flags (position counts, percentage thresholds, investment minimums)
3. Required disclosure completeness
4. Risk factor gaps or missing language
Be specific, cite rules where applicable, flag CRITICAL issues clearly. Keep response under 250 words."""

class ReviewRequest(BaseModel):
    text: str
    context: str = "general"

async def call_gemini(text: str) -> str:
    api_key = os.getenv("LLM_API_KEY")
    url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key={api_key}"
    payload = {
        "contents": [{"parts": [{"text": f"{SYSTEM_PROMPT}\n\nReview this ETF disclosure:\n\n{text}"}]}]
    }
    async with httpx.AsyncClient(timeout=30) as client:
        r = await client.post(url, json=payload)
        r.raise_for_status()
        return r.json()["candidates"][0]["content"]["parts"][0]["text"]

async def call_openai(text: str) -> str:
    api_key = os.getenv("LLM_API_KEY")
    async with httpx.AsyncClient(timeout=30) as client:
        r = await client.post(
            "https://api.openai.com/v1/chat/completions",
            headers={"Authorization": f"Bearer {api_key}"},
            json={"model": "gpt-4o-mini", "messages": [
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": f"Review this ETF disclosure:\n\n{text}"}
            ]}
        )
        r.raise_for_status()
        return r.json()["choices"][0]["message"]["content"]

async def call_anthropic(text: str) -> str:
    api_key = os.getenv("LLM_API_KEY")
    async with httpx.AsyncClient(timeout=30) as client:
        r = await client.post(
            "https://api.anthropic.com/v1/messages",
            headers={"x-api-key": api_key, "anthropic-version": "2023-06-01"},
            json={"model": "claude-haiku-4-5-20251001", "max_tokens": 1024,
                  "system": SYSTEM_PROMPT,
                  "messages": [{"role": "user", "content": f"Review this ETF disclosure:\n\n{text}"}]}
        )
        r.raise_for_status()
        return r.json()["content"][0]["text"]

async def call_groq(text: str) -> str:
    api_key = os.getenv("LLM_API_KEY")
    async with httpx.AsyncClient(timeout=30) as client:
        r = await client.post(
            "https://api.groq.com/openai/v1/chat/completions",
            headers={"Authorization": f"Bearer {api_key}"},
            json={"model": "llama3-8b-8192", "messages": [
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": f"Review this ETF disclosure:\n\n{text}"}
            ]}
        )
        r.raise_for_status()
        return r.json()["choices"][0]["message"]["content"]

@router.post("/review")
async def ai_review(req: ReviewRequest):
    provider = os.getenv("LLM_PROVIDER", "gemini").lower()
    api_key = os.getenv("LLM_API_KEY", "")
    if not api_key or api_key == "your_api_key_here":
        return {"result": "⚠ No API key configured. Add LLM_API_KEY to your .env file.\n\nDemo analysis: The disclosure appears to reference 847 positions which conflicts with the N-PORT exception showing 849. Recommend reconciling position count before filing. The 80% policy threshold language meets N-1A requirements.", "provider": "demo"}
    try:
        if provider == "gemini":
            result = await call_gemini(req.text)
        elif provider == "openai":
            result = await call_openai(req.text)
        elif provider == "anthropic":
            result = await call_anthropic(req.text)
        elif provider == "groq":
            result = await call_groq(req.text)
        else:
            raise HTTPException(status_code=400, detail=f"Unknown provider: {provider}")
        return {"result": result, "provider": provider}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
