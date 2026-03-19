from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from typing import Optional
from database import get_db
import models

router = APIRouter()

@router.get("/")
def get_audit_log(limit: int = 50, event_type: Optional[str] = None, actor: Optional[str] = None, db: Session = Depends(get_db)):
    q = db.query(models.AuditLog)
    if event_type:
        q = q.filter(models.AuditLog.event_type == event_type)
    if actor:
        q = q.filter(models.AuditLog.actor.ilike(f"%{actor}%"))
    logs = q.order_by(models.AuditLog.timestamp.desc()).limit(limit).all()
    return [{
        "id": l.id, "timestamp": str(l.timestamp),
        "event_type": l.event_type, "actor": l.actor,
        "resource": l.resource, "action": l.action,
        "evidence_ref": l.evidence_ref, "ip_address": l.ip_address
    } for l in logs]
