from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import PlainTextResponse
from contextlib import asynccontextmanager
from database import engine, Base, SessionLocal
import models, os, httpx

from routes import filings, exceptions, audit, pipelines, funds, workflows, ai_review

def seed_database():
    try:
        db = SessionLocal()
        count = db.query(models.Fund).count()
        db.close()
        if count > 0:
            print(f"Database already has {count} funds, skipping seed")
            return
        sql_path = os.path.join(os.path.dirname(__file__), "init.sql")
        if os.path.exists(sql_path):
            with engine.connect() as conn:
                with open(sql_path) as f:
                    from sqlalchemy import text
                    for s in f.read().split(";"):
                        s = s.strip()
                        if s and not s.startswith("--"):
                            try:
                                conn.execute(text(s))
                            except Exception as e:
                                print(f"Statement skipped: {e}")
                    conn.commit()
            print("Database seeded successfully")
    except Exception as e:
        print(f"Seed error: {e}")

@asynccontextmanager
async def lifespan(app: FastAPI):
    try:
        Base.metadata.create_all(bind=engine)
        print("Tables created successfully")
    except Exception as e:
        print(f"DB error: {e}")
        raise
    seed_database()
    yield

app = FastAPI(
    title="Corgi ETF Ops API",
    description="Compliance and operations platform for ETF issuers",
    version="1.0.0",
    lifespan=lifespan
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(funds.router,      prefix="/api/funds",      tags=["Funds"])
app.include_router(filings.router,    prefix="/api/filings",    tags=["Filings"])
app.include_router(workflows.router,  prefix="/api/workflows",  tags=["Workflows"])
app.include_router(exceptions.router, prefix="/api/exceptions", tags=["Exceptions"])
app.include_router(pipelines.router,  prefix="/api/pipelines",  tags=["Pipelines"])
app.include_router(audit.router,      prefix="/api/audit",      tags=["Audit"])
app.include_router(ai_review.router,  prefix="/api/ai",         tags=["AI Review"])

@app.get("/")
def root():
    return {"status": "ok", "service": "Corgi ETF Ops API", "version": "1.0.0"}

@app.get("/health")
def health():
    return {"status": "healthy"}

@app.post("/api/admin/reseed")
def reseed():
    seed_database()
    return {"status": "reseeded"}

@app.get("/api/edgar/recent", response_class=PlainTextResponse)
async def edgar_recent():
    url = "https://www.sec.gov/cgi-bin/browse-edgar?action=getcurrent&type=N-PORT&dateb=&owner=include&count=10&search_text=&output=atom"
    try:
        async with httpx.AsyncClient(timeout=15) as client:
            r = await client.get(url, headers={
                "User-Agent": "Corgi ETF Ops demo@example.com",
                "Accept": "application/atom+xml"
            })
            return r.text
    except Exception as e:
        return f"<error>{str(e)}</error>"
