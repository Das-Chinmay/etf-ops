from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from database import get_db
import models

router = APIRouter()

@router.get("/")
def get_funds(db: Session = Depends(get_db)):
    funds = db.query(models.Fund).all()
    return [{"id": f.id, "ticker": f.ticker, "name": f.name, "aum": float(f.aum or 0), "nav": float(f.nav or 0)} for f in funds]

@router.get("/{fund_id}/holdings")
def get_holdings(fund_id: int, db: Session = Depends(get_db)):
    holdings = db.query(models.Holding).filter(models.Holding.fund_id == fund_id).all()
    return [{
        "id": h.id, "ticker": h.ticker, "name": h.name, "isin": h.isin,
        "weight": float(h.weight or 0), "shares": h.shares,
        "price": float(h.price or 0), "market_value": float(h.market_value or 0),
        "recon_status": h.recon_status
    } for h in holdings]

@router.get("/stats")
def get_stats(db: Session = Depends(get_db)):
    funds = db.query(models.Fund).all()
    total_aum = sum(float(f.aum or 0) for f in funds)
    open_exceptions = db.query(models.Exception).filter(models.Exception.status == "open").count()
    pending_filings = db.query(models.Filing).filter(models.Filing.status.in_(["in_review", "in_progress", "pending_approval"])).count()
    return {
        "total_aum": total_aum,
        "open_exceptions": open_exceptions,
        "pending_filings": pending_filings,
        "funds": len(funds)
    }
