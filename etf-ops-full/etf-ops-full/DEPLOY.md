# Corgi ETF Ops — Deploy Guide
## Free forever: Supabase (DB) + Render (backend + frontend)

---

## STEP 1 — Get a free Gemini API key (2 min)

1. Go to → https://aistudio.google.com
2. Click **"Get API Key"** → **"Create API key"**
3. Copy the key — looks like: `AIzaSy...`
4. Save it somewhere safe

---

## STEP 2 — Push code to GitHub (3 min)

Install GitHub CLI if you don't have it:
- Mac: `brew install gh`
- Windows: https://cli.github.com

Then run:
```bash
cd etf-ops-full

git init
git add .
git commit -m "initial commit"

gh auth login        # follow prompts, choose GitHub.com → HTTPS → browser
gh repo create etf-ops --public --push --source .
```

✅ Your code is now at: `https://github.com/YOUR_USERNAME/etf-ops`

---

## STEP 3 — Create free Supabase database (3 min)

1. Go to → https://supabase.com
2. Click **"Start your project"** → sign up free (use GitHub login)
3. Click **"New Project"**
   - Name: `etf-ops`
   - Database Password: make something up, **save it**
   - Region: pick closest to you
   - Click **"Create new project"** → wait ~1 min
4. Go to **Settings** (gear icon, bottom left) → **Database**
5. Scroll to **"Connection string"** → select **"URI"** tab
6. Copy the string — looks like:
   ```
   postgresql://postgres:[YOUR-PASSWORD]@db.xxxx.supabase.co:5432/postgres
   ```
7. Replace `[YOUR-PASSWORD]` with the password you set in step 3

✅ Save this — it's your `DATABASE_URL`

---

## STEP 4 — Deploy backend on Render (5 min)

1. Go to → https://render.com → **"Get Started for Free"** → sign up (use GitHub)
2. Click **"New +"** → **"Web Service"**
3. Click **"Connect a repository"** → select your `etf-ops` repo
4. Fill in these settings:
   ```
   Name:          etf-ops-backend
   Root Directory: backend
   Runtime:       Python 3
   Build Command: pip install -r requirements.txt
   Start Command: uvicorn main:app --host 0.0.0.0 --port $PORT
   Instance Type: Free
   ```
5. Scroll down to **"Environment Variables"** → click **"Add Environment Variable"**:

   | Key | Value |
   |-----|-------|
   | `DATABASE_URL` | (paste your Supabase connection string from Step 3) |
   | `LLM_PROVIDER` | `gemini` |
   | `LLM_API_KEY` | (paste your Gemini key from Step 1) |

6. Click **"Create Web Service"**
7. Wait ~3 min for it to build and deploy
8. You'll see: **"Your service is live"** 🎉
9. Copy your backend URL — looks like: `https://etf-ops-backend.onrender.com`

✅ Test it: open `https://etf-ops-backend.onrender.com/health` → should show `{"status":"healthy"}`

---

## STEP 5 — Point frontend at your backend (2 min)

Open `frontend/index.html` in your editor.

Find line ~368:
```js
const API = window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1'
  ? 'http://localhost:8000/api'
  : '/api';
```

Change the last line to your Render backend URL:
```js
const API = window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1'
  ? 'http://localhost:8000/api'
  : 'https://etf-ops-backend.onrender.com/api';
```

Save, then push:
```bash
git add frontend/index.html
git commit -m "point frontend at render backend"
git push
```

---

## STEP 6 — Deploy frontend on Render (3 min)

1. In Render dashboard → **"New +"** → **"Static Site"**
2. Connect same `etf-ops` repo
3. Fill in:
   ```
   Name:           etf-ops-frontend
   Root Directory: frontend
   Build Command:  (leave empty)
   Publish Dir:    .
   ```
4. Click **"Create Static Site"**
5. Wait ~1 min → you'll get a URL like: `https://etf-ops-frontend.onrender.com`

---

## ✅ Done! Your app is live

```
Frontend:  https://etf-ops-frontend.onrender.com
API:       https://etf-ops-backend.onrender.com
API Docs:  https://etf-ops-backend.onrender.com/docs
```

Share the frontend URL in your job application!

---

## Troubleshooting

**Backend logs showing DB errors?**
→ Check your DATABASE_URL env var on Render — make sure password is correct and no `[brackets]` left in it

**Frontend shows "Loading..." forever?**
→ The backend may be sleeping (free tier). Wait 30 seconds and refresh.
→ Or open the API health URL first: `https://etf-ops-backend.onrender.com/health`

**AI Review not working?**
→ Check LLM_API_KEY env var on Render is set correctly

**Want to update the app after changes?**
```bash
git add .
git commit -m "update"
git push
```
Render auto-deploys on every push.

---

## Costs

| Service | Cost |
|---------|------|
| Supabase Postgres | Free forever (500MB) |
| Render Backend | Free (sleeps after 15min inactivity) |
| Render Frontend | Free forever |
| Gemini API | Free tier (generous limits) |
| **Total** | **$0** |
