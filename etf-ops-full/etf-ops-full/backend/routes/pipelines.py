from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from database import get_db
import models

router = APIRouter()

@router.get("/")
def get_pipelines(db: Session = Depends(get_db)):
    runs = db.query(models.PipelineRun).order_by(models.PipelineRun.started_at.desc()).all()
    # Get latest per vendor
    seen = {}
    for r in runs:
        if r.vendor not in seen:
            seen[r.vendor] = r
    return [{
        "id": r.id, "vendor": r.vendor, "data_type": r.data_type,
        "method": r.method, "status": r.status,
        "rows_processed": r.rows_processed, "exceptions_raised": r.exceptions_raised,
        "sla_met": r.sla_met, "file_name": r.file_name,
        "started_at": str(r.started_at),
        "completed_at": str(r.completed_at) if r.completed_at else None
    } for r in seen.values()]

@router.get("/stats")
def get_pipeline_stats(db: Session = Depends(get_db)):
    runs = db.query(models.PipelineRun).all()
    total_rows = sum(r.rows_processed for r in runs)
    sla_breaches = sum(1 for r in runs if not r.sla_met)
    total_exceptions = sum(r.exceptions_raised for r in runs)
    return {
        "files_today": len(runs),
        "total_rows": total_rows,
        "sla_breaches": sla_breaches,
        "total_exceptions": total_exceptions
    }
