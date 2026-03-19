# Corgi ETF Ops Platform

Full-stack compliance & operations platform for ETF issuers.
Built as a working demo for the Corgi engineering role.

## Stack
- **Frontend**: Vanilla JS/HTML, Chart.js, IBM Plex fonts
- **Backend**: Python FastAPI, SQLAlchemy
- **Database**: PostgreSQL
- **AI**: Gemini / OpenAI / Anthropic / Groq (swap via .env)
- **Deploy**: Docker Compose (local) · Railway (cloud)

---

## Option A — Run Locally (5 min)

### 1. Install Docker Desktop
→ https://www.docker.com/products/docker-desktop

### 2. Clone / unzip this project
```bash
cd etf-ops-full
```

### 3. Add your API key
Edit `.env`:
```
LLM_PROVIDER=gemini
LLM_API_KEY=your_key_here   # free at aistudio.google.com
```

### 4. Run everything
```bash
docker compose up
```

### 5. Open the app
→ http://localhost:3000

API docs → http://localhost:8000/docs

---

## Option B — Deploy to Railway (live URL, ~15 min, free tier)

### 1. Push to GitHub
```bash
git init
git add .
git commit -m "initial commit"
gh repo create etf-ops --public --push
```

### 2. Deploy backend on Railway
1. Go to → https://railway.app
2. New Project → Deploy from GitHub → select `etf-ops`
3. Set **Root Directory** to `backend`
4. Add environment variables:
   ```
   LLM_PROVIDER=gemini
   LLM_API_KEY=your_key_here
   DATABASE_URL=(auto-filled when you add Postgres below)
   ```
5. Add Postgres: click **+ New** → **Database** → **PostgreSQL**
   - Railway auto-sets `DATABASE_URL`
6. Run the seed SQL: open Postgres service → **Query** tab → paste contents of `backend/init.sql`
7. Note your backend URL: `https://etf-ops-backend.up.railway.app`

### 3. Deploy frontend on Railway
1. New service → same repo
2. Set **Root Directory** to `frontend`
3. Add environment variable:
   ```
   API_URL=https://your-backend.up.railway.app
   ```
4. Update `frontend/index.html` line 2:
   ```js
   const API = 'https://your-backend.up.railway.app/api';
   ```
5. Redeploy → get your frontend URL

### 4. Done!
Share the frontend URL in your application.

---

## Option C — Deploy to Render (also free)

Backend:
1. → https://render.com → New Web Service → connect GitHub
2. Root: `backend`, Build: `pip install -r requirements.txt`, Start: `uvicorn main:app --host 0.0.0.0 --port $PORT`
3. Add env vars + free Postgres database

Frontend:
1. New Static Site → Root: `frontend`

---

## Features

| Section | What it does |
|---|---|
| Dashboard | Live AUM, filing calendar, audit feed, control health scoring |
| SEC Filings | Create/track N-PORT, N-CEN, 485BPOS with iXBRL status |
| Workflows | Step-by-step approval checklists with evidence capture |
| Audit Log | Immutable event trail — Rule 17a-4 compliant |
| Pipelines | Vendor connection monitor (SFTP/API), SLA tracking, recon breaks |
| Fund Data | Holdings source-of-truth with per-position reconciliation |
| Exceptions | CRITICAL/HIGH/MEDIUM/LOW queue with assignment + resolution |
| AI Review | Paste disclosure text → instant SEC compliance analysis |

## API Endpoints

```
GET  /api/funds/                 - All funds
GET  /api/funds/stats            - Dashboard stats
GET  /api/funds/{id}/holdings    - Fund holdings
GET  /api/filings/               - All filings
POST /api/filings/               - Create filing
PATCH /api/filings/{id}          - Update filing
POST /api/filings/{id}/approve   - Approve with evidence
GET  /api/exceptions/            - Exception queue
POST /api/exceptions/{id}/resolve - Resolve exception
GET  /api/audit/                 - Audit log
GET  /api/pipelines/             - Pipeline status
POST /api/ai/review              - AI compliance review
```

Full interactive docs: `http://localhost:8000/docs`
