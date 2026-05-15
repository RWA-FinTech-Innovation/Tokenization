-- PostgreSQL baseline schema for an AI-agent-native consortium-chain tokenization system.
-- Chain state remains authoritative. These tables store Agent execution, indexes,
-- audit evidence, policy decisions, and off-chain metadata.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

DO $$ BEGIN
  CREATE TYPE requester_type AS ENUM ('user', 'institution', 'system');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE risk_level AS ENUM ('low', 'medium', 'high', 'critical');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE policy_result AS ENUM ('approved', 'rejected', 'need_policy_review');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE task_status AS ENUM (
    'created',
    'planning',
    'policy_checking',
    'tool_executing',
    'chain_confirming',
    'auditing',
    'succeeded',
    'failed',
    'recovering',
    'compensating',
    'policy_rejected',
    'cancelled'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE plan_status AS ENUM ('draft', 'approved', 'rejected', 'executed');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE call_result AS ENUM ('success', 'failed');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE asset_status AS ENUM ('created', 'issued', 'frozen', 'transferred', 'redeemed', 'burned');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE tx_status AS ENUM ('pending', 'confirmed', 'failed', 'reverted');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE TABLE institutions (
  institution_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  did TEXT UNIQUE,
  certificate_fingerprint TEXT UNIQUE,
  status TEXT NOT NULL DEFAULT 'active',
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE subjects (
  subject_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  institution_id UUID REFERENCES institutions(institution_id),
  subject_type requester_type NOT NULL,
  external_ref TEXT,
  address TEXT UNIQUE,
  did TEXT UNIQUE,
  status TEXT NOT NULL DEFAULT 'active',
  kyc_status TEXT NOT NULL DEFAULT 'unknown',
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE licensed_institutions (
  institution_id UUID PRIMARY KEY REFERENCES institutions(institution_id),
  license_type TEXT NOT NULL,
  license_number TEXT NOT NULL,
  jurisdiction TEXT NOT NULL DEFAULT 'HK',
  regulator TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'valid',
  permitted_activities TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
  valid_until DATE,
  evidence_hash TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE kyc_aml_profiles (
  profile_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  subject_ref TEXT NOT NULL UNIQUE,
  subject_type requester_type NOT NULL,
  kyc_status TEXT NOT NULL,
  aml_status TEXT NOT NULL,
  risk_rating risk_level NOT NULL DEFAULT 'low',
  professional_investor BOOLEAN NOT NULL DEFAULT false,
  sanctions_checked_at TIMESTAMPTZ,
  provider_ref TEXT,
  evidence_hash TEXT NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE legal_documents (
  document_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  document_type TEXT NOT NULL,
  content_hash TEXT UNIQUE NOT NULL,
  storage_uri TEXT NOT NULL,
  jurisdiction TEXT NOT NULL DEFAULT 'HK',
  status TEXT NOT NULL DEFAULT 'active',
  effective_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE asset_rights_mappings (
  rights_mapping_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  asset_id TEXT NOT NULL,
  asset_type TEXT NOT NULL,
  rights_type TEXT NOT NULL,
  document_id UUID NOT NULL REFERENCES legal_documents(document_id),
  rights_summary TEXT NOT NULL,
  redemption_terms TEXT,
  transfer_restrictions JSONB NOT NULL DEFAULT '{}'::jsonb,
  status TEXT NOT NULL DEFAULT 'active',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (asset_id, rights_type)
);

CREATE TABLE custody_wallets (
  wallet_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_ref TEXT NOT NULL,
  owner_type requester_type NOT NULL,
  wallet_address TEXT UNIQUE NOT NULL,
  kms_key_ref TEXT NOT NULL,
  custody_provider TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'active',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE oracle_attestations (
  attestation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  source TEXT NOT NULL,
  source_ref TEXT NOT NULL,
  subject_id TEXT NOT NULL,
  period TEXT NOT NULL,
  content_hash TEXT NOT NULL,
  value JSONB NOT NULL,
  status TEXT NOT NULL DEFAULT 'verified',
  observed_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (source, subject_id, period)
);

CREATE TABLE agents (
  agent_id TEXT PRIMARY KEY,
  agent_type TEXT NOT NULL,
  role TEXT NOT NULL,
  institution_id UUID REFERENCES institutions(institution_id),
  model_ref TEXT,
  status TEXT NOT NULL DEFAULT 'active',
  permission_scope TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE tools (
  tool_name TEXT PRIMARY KEY,
  input_schema JSONB NOT NULL,
  output_schema JSONB NOT NULL,
  required_role TEXT NOT NULL,
  risk_level risk_level NOT NULL,
  idempotent BOOLEAN NOT NULL DEFAULT true,
  audit_required BOOLEAN NOT NULL DEFAULT true,
  timeout_ms BIGINT NOT NULL DEFAULT 30000,
  status TEXT NOT NULL DEFAULT 'active',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE agent_tasks (
  task_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  requester TEXT NOT NULL,
  requester_type requester_type NOT NULL,
  requester_signature TEXT,
  intent TEXT NOT NULL,
  intent_hash TEXT NOT NULL,
  constraints JSONB NOT NULL DEFAULT '{}'::jsonb,
  authorization_scope TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
  assigned_agent TEXT REFERENCES agents(agent_id),
  plan_hash TEXT,
  policy_result policy_result,
  execution_status task_status NOT NULL DEFAULT 'created',
  related_tx_hashes TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
  evidence_hash TEXT,
  idempotency_key TEXT NOT NULL,
  risk_preference risk_level,
  estimated_risk_level risk_level,
  error_code TEXT,
  error_message TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (requester, idempotency_key)
);

CREATE TABLE signature_requests (
  signature_request_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id UUID NOT NULL REFERENCES agent_tasks(task_id) ON DELETE CASCADE,
  wallet_id UUID NOT NULL REFERENCES custody_wallets(wallet_id),
  signer_ref TEXT NOT NULL,
  payload_hash TEXT NOT NULL,
  signature_hash TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'signed',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE agent_plans (
  plan_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id UUID NOT NULL REFERENCES agent_tasks(task_id) ON DELETE CASCADE,
  planner_agent_id TEXT NOT NULL REFERENCES agents(agent_id),
  required_tools TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
  risk_level risk_level NOT NULL,
  policy_snapshot_hash TEXT,
  plan_hash TEXT NOT NULL UNIQUE,
  status plan_status NOT NULL DEFAULT 'draft',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE plan_steps (
  step_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id UUID NOT NULL REFERENCES agent_plans(plan_id) ON DELETE CASCADE,
  step_order INT NOT NULL,
  agent_id TEXT REFERENCES agents(agent_id),
  tool_name TEXT REFERENCES tools(tool_name),
  description TEXT NOT NULL,
  input_template JSONB NOT NULL DEFAULT '{}'::jsonb,
  expected_output JSONB NOT NULL DEFAULT '{}'::jsonb,
  risk_level risk_level NOT NULL DEFAULT 'low',
  UNIQUE (plan_id, step_order)
);

CREATE TABLE policy_evaluations (
  policy_evaluation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id UUID NOT NULL REFERENCES agent_tasks(task_id) ON DELETE CASCADE,
  agent_id TEXT REFERENCES agents(agent_id),
  tool_name TEXT REFERENCES tools(tool_name),
  policy_set_version TEXT NOT NULL,
  input_hash TEXT NOT NULL,
  result policy_result NOT NULL,
  reasons JSONB NOT NULL DEFAULT '[]'::jsonb,
  evaluated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE tool_calls (
  tool_call_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id UUID NOT NULL REFERENCES agent_tasks(task_id) ON DELETE CASCADE,
  agent_id TEXT NOT NULL REFERENCES agents(agent_id),
  tool_name TEXT NOT NULL REFERENCES tools(tool_name),
  input_hash TEXT NOT NULL,
  output_hash TEXT,
  required_role TEXT NOT NULL,
  risk_level risk_level NOT NULL,
  policy_result policy_result,
  result call_result,
  error_code TEXT,
  error_message TEXT,
  retryable BOOLEAN NOT NULL DEFAULT false,
  started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  finished_at TIMESTAMPTZ
);

CREATE TABLE storage_objects (
  object_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id UUID REFERENCES agent_tasks(task_id),
  bucket TEXT NOT NULL,
  object_key TEXT NOT NULL,
  content_hash TEXT NOT NULL,
  merkle_root TEXT,
  content_type TEXT,
  size_bytes BIGINT,
  encryption_ref TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (bucket, object_key)
);

CREATE TABLE assets (
  asset_id TEXT PRIMARY KEY,
  asset_type TEXT NOT NULL,
  issuer_address TEXT NOT NULL,
  owner_address TEXT NOT NULL,
  amount NUMERIC(38, 0) NOT NULL CHECK (amount >= 0),
  metadata_hash TEXT NOT NULL,
  status asset_status NOT NULL DEFAULT 'created',
  created_by_task_id UUID REFERENCES agent_tasks(task_id),
  updated_by_task_id UUID REFERENCES agent_tasks(task_id),
  chain_tx_hash TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE transaction_records (
  tx_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tx_hash TEXT UNIQUE NOT NULL,
  task_id UUID NOT NULL REFERENCES agent_tasks(task_id) ON DELETE CASCADE,
  contract_name TEXT NOT NULL,
  method_name TEXT NOT NULL,
  caller_address TEXT NOT NULL,
  payload_hash TEXT NOT NULL,
  status tx_status NOT NULL DEFAULT 'pending',
  block_height BIGINT,
  block_hash TEXT,
  failure_reason TEXT,
  submitted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  confirmed_at TIMESTAMPTZ
);

CREATE TABLE chain_events (
  event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tx_hash TEXT NOT NULL,
  block_height BIGINT NOT NULL,
  block_hash TEXT NOT NULL,
  event_name TEXT NOT NULL,
  agent_task_id_hash TEXT,
  asset_id TEXT,
  event_payload JSONB NOT NULL,
  observed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (tx_hash, event_name, block_height)
);

CREATE TABLE audit_logs (
  log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  operator_address TEXT NOT NULL,
  action TEXT NOT NULL,
  target_id TEXT NOT NULL,
  agent_task_id UUID NOT NULL REFERENCES agent_tasks(task_id) ON DELETE CASCADE,
  agent_id TEXT REFERENCES agents(agent_id),
  tx_hash TEXT,
  tool_call_hash TEXT,
  request_hash TEXT NOT NULL,
  result call_result NOT NULL,
  evidence_hash TEXT NOT NULL,
  details JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE outbox_events (
  outbox_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  aggregate_type TEXT NOT NULL,
  aggregate_id TEXT NOT NULL,
  event_type TEXT NOT NULL,
  payload JSONB NOT NULL,
  published BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  published_at TIMESTAMPTZ
);

CREATE INDEX idx_agent_tasks_status ON agent_tasks(execution_status);
CREATE INDEX idx_agent_tasks_requester ON agent_tasks(requester);
CREATE INDEX idx_kyc_aml_profiles_subject ON kyc_aml_profiles(subject_ref);
CREATE INDEX idx_asset_rights_mappings_asset ON asset_rights_mappings(asset_id);
CREATE INDEX idx_signature_requests_task ON signature_requests(task_id);
CREATE INDEX idx_oracle_attestations_subject ON oracle_attestations(subject_id, period);
CREATE INDEX idx_tool_calls_task ON tool_calls(task_id);
CREATE INDEX idx_tool_calls_tool ON tool_calls(tool_name);
CREATE INDEX idx_assets_owner ON assets(owner_address);
CREATE INDEX idx_assets_status ON assets(status);
CREATE INDEX idx_transaction_records_task ON transaction_records(task_id);
CREATE INDEX idx_transaction_records_status ON transaction_records(status);
CREATE INDEX idx_chain_events_asset ON chain_events(asset_id);
CREATE INDEX idx_audit_logs_task ON audit_logs(agent_task_id);
CREATE INDEX idx_audit_logs_target ON audit_logs(target_id);
CREATE INDEX idx_policy_evaluations_task ON policy_evaluations(task_id);
