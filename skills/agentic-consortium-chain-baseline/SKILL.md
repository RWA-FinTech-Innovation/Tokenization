---
name: agentic-consortium-chain-baseline
description: Create, refine, or review AI-agent-native consortium blockchain baselines and tokenization system designs. Use when Codex needs to draft architecture documents, module boundaries, Agent execution flows, controlled tool interfaces, smart contract/API baselines, security controls, audit trails, or evaluation metrics for systems where AI Agents execute all operations on top of a permissioned consortium chain.
---

# Agentic Consortium Chain Baseline

## Operating Principle

Design the system as Agent-native by default: users, institutions, and external systems submit goals, constraints, and authorization; AI Agents plan and execute all system operations through controlled tools. Do not design direct human or external writes to assets, ledgers, databases, or files.

Use a permissioned consortium chain as the trust and consistency layer, and use modular architecture to isolate Agent orchestration, identity, policy, asset, transaction, contract, storage, audit, and monitoring concerns.

## Workflow

1. Identify the requested artifact: baseline document, architecture plan, implementation skeleton, API/schema design, security review, experiment design, or gap analysis.
2. Collect missing local context from the repo first. If the user has not specified a stack, use the baseline defaults in this skill.
3. Load `references/baseline.md` when the task needs complete section wording, exact schemas, full module lists, data flows, or evaluation metrics.
4. Produce the artifact in the requested format. If no format is given, use concise Markdown with clear sections.
5. Check the output against the Agent-native constraints before finishing.

## Baseline Defaults

Use these defaults unless the user or repo indicates otherwise:

- Consortium network: permissioned, 4 validator nodes, PBFT or IBFT consensus.
- Execution model: Orchestrator Agent coordinates specialized Agents and controlled tools.
- Specialized Agents: Identity, Asset, Transaction, Compliance, Audit, Monitor, and Recovery.
- State changes: only through audited tool calls and smart contract transactions.
- Storage: chain stores trusted state, transaction hashes, event hashes, and Agent evidence hashes; off-chain stores documents, indexes, Agent logs, vector memory, and large files.
- Humans/institutions: provide authorization, governance, and policy configuration; they do not directly mutate system state.
- High-risk actions: allowed only after policy engine approval and schema/state validation.

## Architecture Checklist

For a complete design, cover these layers:

1. Intent access layer: natural language goals, structured tasks, event triggers, and authorization signals.
2. Agent execution layer: task parsing, planning, multi-Agent coordination, tool selection, execution, verification, and recovery.
3. Controlled tool layer: schema-bound, permissioned, auditable tools wrapping business capabilities.
4. Smart contract layer: asset state machine, permission checks, transaction rules, and events.
5. Consortium chain layer: consensus, ledger, blocks, transaction ordering, and chain events.
6. Off-chain services: relational DB, object storage, search, cache, vector memory, audit, monitoring, and key management.

For core modules, include Agent execution, identity/permission, asset, transaction, smart contract, consensus/ledger, off-chain storage, audit/regulatory, policy, and monitoring.

## Agent Execution Requirements

When designing Agent behavior:

- Use an `AgentTask` as the unit of execution.
- Include task ID, requester, assigned Agent, intent, plan hash, policy result, execution status, related transaction hashes, evidence hash, and timestamps.
- Require every state-changing tool to declare input schema, output schema, required role, risk level, idempotency, timeout, and audit requirement.
- Treat Agent natural-language reasoning as non-authoritative. Final truth must come from chain state, signatures, policy results, and verifiable evidence.
- Include compensation and recovery paths for failed, timed-out, or inconsistent operations.

## Required Data Flows

When documenting business flows, express them as Agent-executed workflows:

- Asset issuance: Orchestrator parses intent; Identity and Compliance verify; Asset stores metadata and hashes; Transaction submits register/issue contract calls; Monitor confirms; Audit records evidence.
- Asset transfer: Orchestrator parses parties and amount; Identity verifies authorization; Asset checks state; Compliance checks rules; Transaction submits transfer; Monitor syncs indexes; Audit records trail.
- Redemption or burn: Orchestrator plans; Identity and Compliance verify; Asset checks conditions; Transaction submits redeem/burn; Monitor confirms; Audit stores evidence.
- Exception handling: Monitor detects failure or inconsistency; Recovery generates compensation; Compliance validates; relevant Agent executes; Audit records final state.

## Interface Guidance

Prefer task and tool interfaces over direct asset mutation APIs:

```text
POST /agent/tasks
GET  /agent/tasks/{task_id}
POST /agent/tasks/{task_id}/approve
POST /agent/tasks/{task_id}/cancel
GET  /agent/tasks/{task_id}/audit
GET  /agent/tasks/{task_id}/events
```

Expose asset APIs only as compatibility wrappers that create `AgentTask` records. Do not let compatibility APIs bypass Agent execution, policy validation, or audit.

Recommended controlled tools:

```text
tool.identity.verifySubject
tool.policy.evaluate
tool.asset.register
tool.asset.issue
tool.asset.transfer
tool.asset.freeze
tool.asset.unfreeze
tool.asset.redeem
tool.asset.burn
tool.asset.query
tool.transaction.submit
tool.transaction.waitForConfirmation
tool.audit.writeEvidence
tool.audit.queryAssetTrail
tool.storage.putObject
tool.storage.verifyHash
```

## Security And Audit Checklist

Include these controls in any serious design:

- Agent, tool, node, institution, and user identities are all verifiable.
- Agent permissions are scoped to tools, roles, task authorization, and policy results.
- Business layer and contract layer both validate authorization.
- Agents never access plaintext private keys; use KMS, HSM, or secure wallets.
- External documents and user input are untrusted context and cannot change tool permissions or system policy.
- Plans, tool parameters, and contract inputs pass schema, policy, and state validation.
- Chain state, off-chain files, Agent plans, and tool calls are linked by hashes.
- Every state mutation traces back to an `AgentTask`.

## Evaluation Metrics

When asked for experiments or baseline comparison, include:

- Agent task success rate.
- Agent execution latency from task creation to chain confirmation and audit completion.
- Plan correctness and tool-call correctness.
- Chain TPS and transaction confirmation latency.
- Consistency among chain state, off-chain indexes, and Agent task state.
- Availability under node, tool, or Agent failure.
- Storage growth for ledger, indexes, Agent memory, and audit logs.
- Audit completeness across asset lifecycle and Agent execution trail.
- Policy violation or rejection rate.
- Module replacement cost for model, Agent framework, consensus, storage, or contracts.

## Reference

Read `references/baseline.md` for the full Chinese baseline, including detailed module descriptions, schemas, events, data flows, default experiment configuration, and extension directions.
