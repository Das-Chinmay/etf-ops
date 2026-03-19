from sqlalchemy import Column, Integer, String, Numeric, Date, DateTime, Boolean, Text, BigInteger, ForeignKey
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.sql import func
from database import Base

class Fund(Base):
    __tablename__ = "funds"
    id = Column(Integer, primary_key=True)
    ticker = Column(String(10), unique=True, nullable=False)
    name = Column(String(200), nullable=False)
    aum = Column(Numeric(18, 2), default=0)
    nav = Column(Numeric(10, 4), default=0)
    inception_date = Column(Date)
    created_at = Column(DateTime, default=func.now())

class Filing(Base):
    __tablename__ = "filings"
    id = Column(Integer, primary_key=True)
    form_type = Column(String(20), nullable=False)
    fund_id = Column(Integer, ForeignKey("funds.id"))
    description = Column(Text)
    status = Column(String(30), default="not_started")
    assignee = Column(String(100))
    due_date = Column(Date)
    edgar_status = Column(String(30), default="not_submitted")
    accession_number = Column(String(50))
    ixbrl_status = Column(String(30), default="not_started")
    notes = Column(Text)
    created_at = Column(DateTime, default=func.now())
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now())

class Workflow(Base):
    __tablename__ = "workflows"
    id = Column(Integer, primary_key=True)
    filing_id = Column(Integer, ForeignKey("filings.id"))
    name = Column(String(200), nullable=False)
    status = Column(String(30), default="pending")
    current_step = Column(Integer, default=1)
    total_steps = Column(Integer, default=5)
    assignee = Column(String(100))
    due_date = Column(Date)
    created_at = Column(DateTime, default=func.now())
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now())

class WorkflowStep(Base):
    __tablename__ = "workflow_steps"
    id = Column(Integer, primary_key=True)
    workflow_id = Column(Integer, ForeignKey("workflows.id"))
    step_number = Column(Integer, nullable=False)
    title = Column(String(200), nullable=False)
    description = Column(Text)
    status = Column(String(30), default="pending")
    assignee = Column(String(100))
    completed_at = Column(DateTime)
    approved_by = Column(String(100))
    notes = Column(Text)
    evidence_ref = Column(String(100))

class AuditLog(Base):
    __tablename__ = "audit_log"
    id = Column(Integer, primary_key=True)
    timestamp = Column(DateTime, default=func.now())
    event_type = Column(String(30), nullable=False)
    actor = Column(String(100), nullable=False)
    resource = Column(String(200), nullable=False)
    action = Column(Text, nullable=False)
    evidence_ref = Column(String(100))
    ip_address = Column(String(45))
    extra_metadata = Column(JSONB)

class Exception(Base):
    __tablename__ = "exceptions"
    id = Column(Integer, primary_key=True)
    severity = Column(String(20), nullable=False)
    category = Column(String(50), nullable=False)
    title = Column(String(200), nullable=False)
    description = Column(Text)
    fund_id = Column(Integer, ForeignKey("funds.id"))
    status = Column(String(30), default="open")
    assignee = Column(String(100))
    raised_at = Column(DateTime, default=func.now())
    resolved_at = Column(DateTime)
    resolution_notes = Column(Text)

class Holding(Base):
    __tablename__ = "holdings"
    id = Column(Integer, primary_key=True)
    fund_id = Column(Integer, ForeignKey("funds.id"))
    ticker = Column(String(20))
    name = Column(String(200))
    isin = Column(String(20))
    weight = Column(Numeric(8, 4))
    shares = Column(BigInteger)
    price = Column(Numeric(12, 4))
    market_value = Column(Numeric(18, 2))
    recon_status = Column(String(30), default="ok")
    as_of_date = Column(Date, default=func.current_date())
    created_at = Column(DateTime, default=func.now())

class PipelineRun(Base):
    __tablename__ = "pipeline_runs"
    id = Column(Integer, primary_key=True)
    vendor = Column(String(100), nullable=False)
    data_type = Column(String(50), nullable=False)
    method = Column(String(20), nullable=False)
    status = Column(String(30), default="pending")
    rows_processed = Column(Integer, default=0)
    exceptions_raised = Column(Integer, default=0)
    sla_met = Column(Boolean, default=True)
    file_name = Column(String(200))
    started_at = Column(DateTime, default=func.now())
    completed_at = Column(DateTime)
