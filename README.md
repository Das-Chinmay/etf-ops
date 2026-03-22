# etf-ops

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
