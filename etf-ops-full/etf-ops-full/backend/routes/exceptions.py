from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Optional
from datetime import datetime
from database import get_db
import models

router = APIRouter()

class ExceptionUpdate(BaseModel):
    status: Optional[str] = None
    assignee: Optional[str] = None
    resolution_notes: Optional[str] = None

def exc_to_dict(e, db):
    fund = db.query(models.Fund).filter(models.Fund.id == e.fund_id).first() if e.fund_id else None
    return {
        "id": e.id, "severity": e.severity, "category": e.category,
        "title": e.title, "description": e.description,
        "fund": {"ticker": fund.ticker} if fund else None,
        "status": e.status, "assignee": e.assignee,
        "raised_at": str(e.raised_at), "resolved_at": str(e.resolved_at) if e.resolved_at else None,
        "resolution_notes": e.resolution_notes
    }

@router.get("/")
def get_exceptions(status: Optional[str] = None, db: Session = Depends(get_db)):
    q = db.query(models.Exception)
    if status:
        q = q.filter(models.Exception.status == status)
    return [exc_to_dict(e, db) for e in q.order_by(models.Exception.raised_at.desc()).all()]

@router.patch("/{exc_id}")
def update_exception(exc_id: int, data: ExceptionUpdate, db: Session = Depends(get_db)):
    exc = db.query(models.Exception).filter(models.Exception.id == exc_id).first()
    if not exc:
        raise HTTPException(status_code=404, detail="Exception not found")
    for k, v in data.model_dump(exclude_none=True).items():
        setattr(exc, k, v)
    if data.status == "resolved":
        exc.resolved_at = datetime.now()
    log = models.AuditLog(
        event_type="UPDATE", actor="user",
        resource=f"exception/{exc_id}", action=f"Exception updated: {data.model_dump(exclude_none=True)}"
    )
    db.add(log)
    db.commit()
    return exc_to_dict(exc, db)

@router.post("/{exc_id}/resolve")
def resolve_exception(exc_id: int, actor: str, notes: str, db: Session = Depends(get_db)):
    exc = db.query(models.Exception).filter(models.Exception.id == exc_id).first()
    if not exc:
        raise HTTPException(status_code=404, detail="Exception not found")
    exc.status = "resolved"
    exc.resolved_at = datetime.now()
    exc.resolution_notes = notes
    log = models.AuditLog(
        event_type="RESOLVE", actor=actor,
        resource=f"exception/{exc_id}", action=f"Exception resolved: {notes}"
    )
    db.add(log)
    db.commit()
    return {"status": "resolved", "exception_id": exc_id}
