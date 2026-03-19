from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Optional
from database import get_db
import models

router = APIRouter()

class StepUpdate(BaseModel):
    status: str
    approved_by: Optional[str] = None
    notes: Optional[str] = None

@router.get("/")
def get_workflows(db: Session = Depends(get_db)):
    workflows = db.query(models.Workflow).all()
    result = []
    for w in workflows:
        steps = db.query(models.WorkflowStep).filter(
            models.WorkflowStep.workflow_id == w.id
        ).order_by(models.WorkflowStep.step_number).all()
        result.append({
            "id": w.id, "name": w.name, "status": w.status,
            "current_step": w.current_step, "total_steps": w.total_steps,
            "assignee": w.assignee, "due_date": str(w.due_date) if w.due_date else None,
            "steps": [{
                "id": s.id, "step_number": s.step_number, "title": s.title,
                "status": s.status, "assignee": s.assignee,
                "evidence_ref": s.evidence_ref, "notes": s.notes
            } for s in steps]
        })
    return result

@router.patch("/{workflow_id}/steps/{step_id}")
def update_step(workflow_id: int, step_id: int, data: StepUpdate, db: Session = Depends(get_db)):
    step = db.query(models.WorkflowStep).filter(models.WorkflowStep.id == step_id).first()
    if not step:
        raise HTTPException(status_code=404, detail="Step not found")
    step.status = data.status
    if data.approved_by:
        step.approved_by = data.approved_by
    if data.notes:
        step.notes = data.notes
    if data.status == "complete":
        from datetime import datetime
        step.completed_at = datetime.now()
        step.evidence_ref = f"Evidence #{step_id * 100}"
        workflow = db.query(models.Workflow).filter(models.Workflow.id == workflow_id).first()
        if workflow:
            workflow.current_step = min(workflow.current_step + 1, workflow.total_steps)
    log = models.AuditLog(
        event_type="APPROVE" if data.status == "complete" else "UPDATE",
        actor=data.approved_by or "user",
        resource=f"workflow/{workflow_id}/step/{step_id}",
        action=f"Step '{step.title}' marked {data.status}",
        evidence_ref=step.evidence_ref
    )
    db.add(log)
    db.commit()
    return {"status": "updated", "step_id": step_id}
