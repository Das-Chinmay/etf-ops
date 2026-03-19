from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Optional
from datetime import date
from database import get_db
import models

router = APIRouter()

class FilingCreate(BaseModel):
    form_type: str
    fund_id: Optional[int] = None
    description: Optional[str] = None
    assignee: Optional[str] = None
    due_date: Optional[date] = None
    notes: Optional[str] = None

class FilingUpdate(BaseModel):
    status: Optional[str] = None
    assignee: Optional[str] = None
    edgar_status: Optional[str] = None
    ixbrl_status: Optional[str] = None
    accession_number: Optional[str] = None
    notes: Optional[str] = None

def filing_to_dict(f, db):
    fund = db.query(models.Fund).filter(models.Fund.id == f.fund_id).first() if f.fund_id else None
    return {
        "id": f.id, "form_type": f.form_type,
        "fund": {"ticker": fund.ticker, "name": fund.name} if fund else None,
        "description": f.description, "status": f.status,
        "assignee": f.assignee, "due_date": str(f.due_date) if f.due_date else None,
        "edgar_status": f.edgar_status, "ixbrl_status": f.ixbrl_status,
        "accession_number": f.accession_number, "notes": f.notes,
        "created_at": str(f.created_at)
    }

@router.get("/")
def get_filings(db: Session = Depends(get_db)):
    filings = db.query(models.Filing).order_by(models.Filing.due_date).all()
    return [filing_to_dict(f, db) for f in filings]

@router.post("/")
def create_filing(data: FilingCreate, db: Session = Depends(get_db)):
    filing = models.Filing(**data.model_dump())
    db.add(filing)
    db.commit()
    db.refresh(filing)
    log = models.AuditLog(
        event_type="CREATE", actor="system",
        resource=f"filing/{data.form_type}", action=f"New filing created: {data.form_type} {data.description or ''}"
    )
    db.add(log)
    db.commit()
    return filing_to_dict(filing, db)

@router.patch("/{filing_id}")
def update_filing(filing_id: int, data: FilingUpdate, db: Session = Depends(get_db)):
    filing = db.query(models.Filing).filter(models.Filing.id == filing_id).first()
    if not filing:
        raise HTTPException(status_code=404, detail="Filing not found")
    for k, v in data.model_dump(exclude_none=True).items():
        setattr(filing, k, v)
    db.commit()
    log = models.AuditLog(
        event_type="UPDATE", actor="user",
        resource=f"filing/{filing.form_type}/{filing_id}",
        action=f"Filing updated: {data.model_dump(exclude_none=True)}"
    )
    db.add(log)
    db.commit()
    return filing_to_dict(filing, db)

@router.post("/{filing_id}/approve")
def approve_filing(filing_id: int, approver: str, notes: str, db: Session = Depends(get_db)):
    filing = db.query(models.Filing).filter(models.Filing.id == filing_id).first()
    if not filing:
        raise HTTPException(status_code=404, detail="Filing not found")
    filing.status = "approved"
    log = models.AuditLog(
        event_type="APPROVE", actor=approver,
        resource=f"filing/{filing.form_type}/{filing_id}",
        action=f"Filing approved. Notes: {notes}", evidence_ref=f"Evidence #{filing_id}00"
    )
    db.add(log)
    db.commit()
    return {"status": "approved", "filing_id": filing_id}
