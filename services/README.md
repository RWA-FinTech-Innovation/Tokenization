# Services

This directory is the implementation skeleton for the AI-agent-native consortium-chain tokenization system.

Use `engineering/services/service-skeleton.md` as the service boundary reference before adding implementation code.

The current runnable MVP still lives in `mvp/app.py`. The following production controls have already been landed there as in-process modules and should be split into these services later:

- KYC/AML and licensed-institution registry -> `policy-engine` / `agent-runtime`
- legal document and token-rights mapping -> `asset-service` / `storage-service`
- custody wallet and signature request flow -> `transaction-service`
- oracle attestation verification -> `audit-service` / `chain-indexer`
- external chain adapter boundary -> `transaction-service`

## Current Service Folders

```text
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
```

## Rule

No service should expose a direct state mutation path that bypasses AgentTask, policy evaluation, controlled tool execution, transaction submission, or audit.
