# Service Directory Skeleton

This skeleton maps the architecture into deployable services. Each service owns a narrow boundary and communicates through authenticated APIs, events, and controlled tools. State-changing execution still flows through AgentTask, policy evaluation, tool calls, transaction submission, and audit.

## Directory Layout

```text
services/
  agent-orchestrator/
  agent-runtime/
  tool-registry/
  policy-engine/
  asset-service/
  transaction-service/
  audit-service/
  chain-indexer/
  storage-service/
  monitor-service/
  recovery-service/
contracts/
engineering/
  agents/
  api/
  contracts/
  database/
  services/
```

## Service Boundaries

| Service | Owns | Does Not Own |
| --- | --- | --- |
| agent-orchestrator | AgentTask lifecycle, planning coordination, handoffs | Direct asset mutation |
| agent-runtime | Specialized Agent execution, prompt/spec loading, tool selection | Tool permission source of truth |
| tool-registry | Tool schemas, roles, risk levels, timeouts, audit requirements | Business execution |
| policy-engine | Policy decisions, policy versioning, reason codes | Chain transaction submission |
| asset-service | Asset business validation, indexed asset query, contract parameter preparation | Final chain state |
| transaction-service | Contract payload, signing request, tx submit, confirmation wait | Private-key custody |
| audit-service | AuditLog, evidence hashes, lifecycle trails | Silent best-effort audit |
| chain-indexer | Chain event subscription and off-chain index sync | Contract state mutation |
| storage-service | Object storage, hash verification, Merkle roots | Asset ownership |
| monitor-service | Metrics, stuck task detection, chain/index divergence detection | Recovery execution |
| recovery-service | Compensation plans and recovery execution | Policy bypass |

## Recommended Internal Packages

Each service should use this internal shape when implementation starts:

```text
src/
  api/          # REST/gRPC handlers
  domain/       # service-owned business logic
  adapters/     # DB, chain, queue, KMS, storage, external systems
  events/       # publishers/subscribers
  config/       # typed runtime configuration
  observability/# metrics, tracing, logging
  tests/        # unit and integration tests
```

## Cross-Service Events

```text
AgentTaskCreated
AgentPlanGenerated
PolicyEvaluated
ToolCallStarted
ToolCallCompleted
TransactionSubmitted
TransactionConfirmed
ChainEventObserved
AuditEvidenceWritten
TaskRecoveryRequested
TaskCompleted
TaskFailed
```

## Critical Execution Path

```text
intent-gateway
  -> agent-orchestrator
  -> identity/compliance via agent-runtime and controlled tools
  -> legal rights mapping and document hash verification
  -> asset-service
  -> custody signing through transaction-service
  -> transaction-service
  -> consortium chain
  -> chain-indexer and oracle attestation verification
  -> audit-service
  -> monitor-service
```

Recovery path:

```text
monitor-service
  -> recovery-service
  -> policy-engine
  -> relevant controlled tool
  -> audit-service
```

## Minimum MVP Ownership

- `agent-orchestrator`: create task, update status, emit lifecycle events.
- `agent-runtime`: run Orchestrator, Identity, Asset, Transaction, Audit Agents.
- `tool-registry`: register and validate baseline tool definitions.
- `policy-engine`: approve/reject asset operations; own KYC/AML profile checks, licensed-institution checks, risk reason codes, and policy snapshots.
- `asset-service`: validate asset transitions, query indexed asset state, and verify legal document to token-rights mappings.
- `transaction-service`: submit pseudocode contract calls through the selected chain SDK and route signing through custody/KMS adapters.
- `audit-service`: persist AuditLog and return trails by task, asset, or tx hash.
- `chain-indexer`: subscribe to asset events, external oracle attestations, and update indexes.
- `storage-service`: store documents and verify content hashes.
- `monitor-service`: detect stuck tasks and chain/index lag.
- `recovery-service`: retry idempotent tool calls and replay chain events.
