-- ETF Ops Platform — Database Schema + Seed Data

CREATE TABLE IF NOT EXISTS funds (
    id SERIAL PRIMARY KEY,
    ticker VARCHAR(10) UNIQUE NOT NULL,
    name VARCHAR(200) NOT NULL,
    aum NUMERIC(18,2) DEFAULT 0,
    nav NUMERIC(10,4) DEFAULT 0,
    inception_date DATE,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS filings (
    id SERIAL PRIMARY KEY,
    form_type VARCHAR(20) NOT NULL,
    fund_id INTEGER REFERENCES funds(id),
    description TEXT,
    status VARCHAR(30) DEFAULT 'not_started',
    assignee VARCHAR(100),
    due_date DATE,
    edgar_status VARCHAR(30) DEFAULT 'not_submitted',
    accession_number VARCHAR(50),
    ixbrl_status VARCHAR(30) DEFAULT 'not_started',
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS workflows (
    id SERIAL PRIMARY KEY,
    filing_id INTEGER REFERENCES filings(id),
    name VARCHAR(200) NOT NULL,
    status VARCHAR(30) DEFAULT 'pending',
    current_step INTEGER DEFAULT 1,
    total_steps INTEGER DEFAULT 5,
    assignee VARCHAR(100),
    due_date DATE,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS workflow_steps (
    id SERIAL PRIMARY KEY,
    workflow_id INTEGER REFERENCES workflows(id),
    step_number INTEGER NOT NULL,
    title VARCHAR(200) NOT NULL,
    description TEXT,
    status VARCHAR(30) DEFAULT 'pending',
    assignee VARCHAR(100),
    completed_at TIMESTAMP,
    approved_by VARCHAR(100),
    notes TEXT,
    evidence_ref VARCHAR(100)
);

CREATE TABLE IF NOT EXISTS audit_log (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMP DEFAULT NOW(),
    event_type VARCHAR(30) NOT NULL,
    actor VARCHAR(100) NOT NULL,
    resource VARCHAR(200) NOT NULL,
    action TEXT NOT NULL,
    evidence_ref VARCHAR(100),
    ip_address VARCHAR(45),
    extra_metadata JSONB
);

CREATE TABLE IF NOT EXISTS exceptions (
    id SERIAL PRIMARY KEY,
    severity VARCHAR(20) NOT NULL,
    category VARCHAR(50) NOT NULL,
    title VARCHAR(200) NOT NULL,
    description TEXT,
    fund_id INTEGER REFERENCES funds(id),
    status VARCHAR(30) DEFAULT 'open',
    assignee VARCHAR(100),
    raised_at TIMESTAMP DEFAULT NOW(),
    resolved_at TIMESTAMP,
    resolution_notes TEXT
);

CREATE TABLE IF NOT EXISTS holdings (
    id SERIAL PRIMARY KEY,
    fund_id INTEGER REFERENCES funds(id),
    ticker VARCHAR(20),
    name VARCHAR(200),
    isin VARCHAR(20),
    weight NUMERIC(8,4),
    shares BIGINT,
    price NUMERIC(12,4),
    market_value NUMERIC(18,2),
    recon_status VARCHAR(30) DEFAULT 'ok',
    as_of_date DATE DEFAULT CURRENT_DATE,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS pipeline_runs (
    id SERIAL PRIMARY KEY,
    vendor VARCHAR(100) NOT NULL,
    data_type VARCHAR(50) NOT NULL,
    method VARCHAR(20) NOT NULL,
    status VARCHAR(30) DEFAULT 'pending',
    rows_processed INTEGER DEFAULT 0,
    exceptions_raised INTEGER DEFAULT 0,
    sla_met BOOLEAN DEFAULT TRUE,
    file_name VARCHAR(200),
    started_at TIMESTAMP DEFAULT NOW(),
    completed_at TIMESTAMP
);

INSERT INTO funds (ticker, name, aum, nav, inception_date) VALUES ('CRGX', 'Corgi Growth ETF', 1400000000, 48.23, '2020-03-01') ON CONFLICT (ticker) DO NOTHING;
INSERT INTO funds (ticker, name, aum, nav, inception_date) VALUES ('CRGB', 'Corgi Bond ETF', 680000000, 31.07, '2021-06-15') ON CONFLICT (ticker) DO NOTHING;
INSERT INTO funds (ticker, name, aum, nav, inception_date) VALUES ('CRGG', 'Corgi Global ETF', 320000000, 22.81, '2022-01-10') ON CONFLICT (ticker) DO NOTHING;

INSERT INTO filings (form_type, fund_id, description, status, assignee, due_date, edgar_status, ixbrl_status) VALUES ('N-PORT', 1, 'Monthly Portfolio Holdings - CRGX', 'in_review', 'Sarah Chen', '2026-03-21', 'draft', 'in_progress') ON CONFLICT DO NOTHING;
INSERT INTO filings (form_type, fund_id, description, status, assignee, due_date, edgar_status, ixbrl_status) VALUES ('N-CEN', NULL, 'Annual Report for Registered Funds', 'in_progress', 'Marcus Lee', '2026-04-15', 'not_submitted', 'not_started') ON CONFLICT DO NOTHING;
INSERT INTO filings (form_type, fund_id, description, status, assignee, due_date, edgar_status, ixbrl_status) VALUES ('485BPOS', 2, 'Post-Effective Prospectus Amendment - CRGB', 'pending_approval', 'Alex Rivera', '2026-04-30', 'ixbrl_needed', 'in_progress') ON CONFLICT DO NOTHING;
INSERT INTO filings (form_type, fund_id, description, status, assignee, due_date, edgar_status, ixbrl_status) VALUES ('N-PORT', 3, 'Monthly Portfolio Holdings - CRGG', 'filed', 'Sarah Chen', '2026-02-21', 'accepted', 'complete') ON CONFLICT DO NOTHING;
INSERT INTO filings (form_type, fund_id, description, status, assignee, due_date, edgar_status, ixbrl_status) VALUES ('497', 1, 'Definitive Materials - Fee Update', 'filed', 'Marcus Lee', '2026-02-10', 'accepted', 'complete') ON CONFLICT DO NOTHING;

INSERT INTO exceptions (severity, category, title, description, fund_id, status, assignee) VALUES ('CRITICAL', 'Price Recon', 'GOOGL price mismatch - Bloomberg vs ICE', 'ISIN US02079K3059 exceeds 0.05% threshold', 1, 'open', 'Sarah Chen') ON CONFLICT DO NOTHING;
INSERT INTO exceptions (severity, category, title, description, fund_id, status, assignee) VALUES ('CRITICAL', 'N-PORT', 'Position count mismatch - 847 vs 849', 'EDGAR pre-validation: position count differs from fund admin', 1, 'open', 'Sarah Chen') ON CONFLICT DO NOTHING;
INSERT INTO exceptions (severity, category, title, description, fund_id, status, assignee) VALUES ('HIGH', 'Corp Action', 'MSFT dividend adjustment missing', 'Expected DRIP adjustment not received from Broadridge', 1, 'in_review', 'Marcus Lee') ON CONFLICT DO NOTHING;
INSERT INTO exceptions (severity, category, title, description, fund_id, status, assignee) VALUES ('HIGH', 'Vendor SLA', 'Broadridge file 34m past SLA', 'Corporate actions file delayed', NULL, 'open', NULL) ON CONFLICT DO NOTHING;
INSERT INTO exceptions (severity, category, title, description, fund_id, status, assignee) VALUES ('MEDIUM', 'Disclosure', 'Fee table change not reflected on web page', 'CRGB expense ratio updated in doc but not on fund page', 2, 'in_progress', 'Marcus Lee') ON CONFLICT DO NOTHING;
INSERT INTO exceptions (severity, category, title, description, fund_id, status, assignee) VALUES ('MEDIUM', 'Data Quality', 'Sector classification mismatch - 3 securities', 'GICS sector codes differ between Bloomberg and ICE', 3, 'in_review', 'Alex Rivera') ON CONFLICT DO NOTHING;
INSERT INTO exceptions (severity, category, title, description, fund_id, status, assignee) VALUES ('LOW', 'Reporting', 'Stale NAV on public fund page - 2h delay', 'CRGX NAV not updated after market close', 1, 'open', NULL) ON CONFLICT DO NOTHING;

INSERT INTO holdings (fund_id, ticker, name, isin, weight, shares, price, market_value, recon_status) VALUES (1, 'AAPL', 'Apple Inc.', 'US0378331005', 7.42, 842000, 237.04, 199607680, 'ok') ON CONFLICT DO NOTHING;
INSERT INTO holdings (fund_id, ticker, name, isin, weight, shares, price, market_value, recon_status) VALUES (1, 'MSFT', 'Microsoft Corp.', 'US5949181045', 6.91, 511000, 385.20, 196737200, 'corp_action') ON CONFLICT DO NOTHING;
INSERT INTO holdings (fund_id, ticker, name, isin, weight, shares, price, market_value, recon_status) VALUES (1, 'NVDA', 'NVIDIA Corp.', 'US67066G1040', 5.88, 1204000, 138.44, 166681760, 'ok') ON CONFLICT DO NOTHING;
INSERT INTO holdings (fund_id, ticker, name, isin, weight, shares, price, market_value, recon_status) VALUES (1, 'GOOGL', 'Alphabet Inc. Cl A', 'US02079K3059', 4.21, 702000, 170.58, 119747160, 'price_break') ON CONFLICT DO NOTHING;
INSERT INTO holdings (fund_id, ticker, name, isin, weight, shares, price, market_value, recon_status) VALUES (1, 'AMZN', 'Amazon.com Inc.', 'US0231351067', 4.05, 615000, 234.22, 144045300, 'ok') ON CONFLICT DO NOTHING;

INSERT INTO pipeline_runs (vendor, data_type, method, status, rows_processed, exceptions_raised, sla_met, file_name) VALUES ('State Street', 'Holdings', 'SFTP', 'complete', 2847, 0, true, 'holdings_20260318.csv') ON CONFLICT DO NOTHING;
INSERT INTO pipeline_runs (vendor, data_type, method, status, rows_processed, exceptions_raised, sla_met, file_name) VALUES ('Bloomberg', 'Prices', 'API', 'complete', 4201, 1, true, NULL) ON CONFLICT DO NOTHING;
INSERT INTO pipeline_runs (vendor, data_type, method, status, rows_processed, exceptions_raised, sla_met, file_name) VALUES ('ICE Data', 'Prices', 'API', 'complete', 4199, 0, true, NULL) ON CONFLICT DO NOTHING;
INSERT INTO pipeline_runs (vendor, data_type, method, status, rows_processed, exceptions_raised, sla_met, file_name) VALUES ('Broadridge', 'Corporate Actions', 'SFTP', 'delayed', 0, 1, false, NULL) ON CONFLICT DO NOTHING;
INSERT INTO pipeline_runs (vendor, data_type, method, status, rows_processed, exceptions_raised, sla_met, file_name) VALUES ('DTCC', 'Settlement/NAV', 'API', 'scheduled', 0, 0, true, NULL) ON CONFLICT DO NOTHING;

INSERT INTO audit_log (event_type, actor, resource, action, evidence_ref, ip_address) VALUES ('APPROVE', 'Sarah Chen', 'N-PORT/CRGX/2026-03', 'Approved draft for filing', 'Evidence #1847', '10.0.1.42') ON CONFLICT DO NOTHING;
INSERT INTO audit_log (event_type, actor, resource, action, evidence_ref, ip_address) VALUES ('INGEST', 'pipeline-bot', 'holdings.SFTP.state-street', 'File received, 2847 rows parsed', 'Job #8821', '10.0.2.11') ON CONFLICT DO NOTHING;
INSERT INTO audit_log (event_type, actor, resource, action, evidence_ref, ip_address) VALUES ('FLAG', 'recon-engine', 'price/US02079K3059', 'Price discrepancy exceeds threshold', 'Alert #294', '10.0.2.11') ON CONFLICT DO NOTHING;
INSERT INTO audit_log (event_type, actor, resource, action, evidence_ref, ip_address) VALUES ('UPDATE', 'Marcus Lee', 'doc/485BPOS/CRGB/v4.1', 'Fee table revised', 'Diff #442', '10.0.1.88') ON CONFLICT DO NOTHING;
INSERT INTO audit_log (event_type, actor, resource, action, evidence_ref, ip_address) VALUES ('APPROVE', 'Outside Counsel', 'doc/485BPOS/CRGB/legal', 'Legal sign-off granted', 'Evidence #1801', 'External') ON CONFLICT DO NOTHING;
INSERT INTO audit_log (event_type, actor, resource, action, evidence_ref, ip_address) VALUES ('FILED', 'Sarah Chen', 'EDGAR/N-PORT/CRGX/FEB', 'Submitted to EDGAR - accession received', 'Accession #098', '10.0.1.42') ON CONFLICT DO NOTHING;
