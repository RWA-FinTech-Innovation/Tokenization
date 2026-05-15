# AI Agent 原生联盟链 Tokenization 系统技术方案

## 1. 文档目标

本文档定义一个以 AI Agent 为主要执行主体、以联盟链为可信协作底座、以模块化为工程组织方式的资产 tokenization 系统技术方案。系统适用于多机构参与的资产确权、发行、流转、冻结、赎回、销毁、审计和监管场景。

核心设计原则是：外部用户、机构和业务系统只提交目标、约束和授权信号；系统内部所有资产、交易、审计、监控和异常处理操作均由 AI Agent 通过受控工具执行。任何状态变更都必须经过权限校验、策略校验、工具调用审计和链上或链下可验证证据记录。

## 2. 范围与假设

### 2.1 范围

本方案覆盖：

- AI Agent 原生执行架构。
- 联盟链网络与智能合约基线。
- AgentTask、ToolCall、Asset、Transaction、AuditLog 等核心数据模型。
- 意图接入 API、Agent 工具接口、兼容资产 API 和链上事件。
- 资产发行、转让、冻结、赎回、销毁、异常补偿和审计查询流程。
- 安全、权限、策略、密钥、审计、监控和评测指标。
- MVP 到生产化的交付路径。

### 2.2 假设

- 联盟参与方均为许可准入机构。
- 初始联盟链节点数量为 4 个，默认使用 PBFT 或 IBFT 共识。
- 链上只保存必要可信状态、交易哈希、事件哈希和证据哈希。
- 链下保存大文件、用户资料、Agent 运行日志、索引、向量记忆和审计附件。
- Agent 不直接持有明文私钥，所有签名通过 KMS、HSM 或安全钱包完成。
- 人类或机构可以配置策略、授权任务和参与治理，但不直接绕过 Agent 修改系统状态。

### 2.3 非目标

- 不设计开放匿名公链网络。
- 不在 MVP 阶段实现完整零知识证明或复杂隐私计算。
- 不允许任意自然语言指令直接执行高风险交易。
- 不把 Agent 推理文本作为最终事实来源。

## 3. 总体架构

系统分为六层：

1. 意图接入层：接收自然语言目标、结构化任务、事件触发器和授权信号。
2. Agent 执行层：负责任务理解、计划拆解、多 Agent 协作、工具选择、执行、校验和恢复。
3. 受控工具层：将业务能力封装为 schema-bound、permissioned、auditable 工具。
4. 业务模块层：提供身份、资产、交易、合规、结算、审计、存储、监控等领域能力。
5. 合约与联盟链层：执行资产状态机、权限校验、交易规则、共识和账本提交。
6. 链下服务层：提供数据库、对象存储、搜索、缓存、向量库、消息队列、KMS 和可观测性。

```text
User / Institution / Business System
        |
Intent API / Event Trigger / Authorization Signal
        |
Agent Orchestrator
        |
Specialized Agents
        |
Controlled Tool Layer
        |
Business Modules
        |
Smart Contracts
        |
Consortium Blockchain Network
        |
Off-chain Storage / Index / Vector Memory / Audit / Monitoring
```

## 4. 部署拓扑

### 4.1 基础节点

```text
Institution A: Validator Node + API Gateway + Agent Runtime
Institution B: Validator Node + API Gateway + Read Replica
Institution C: Validator Node + Audit Service + Indexer
Regulator:     Validator Node + Regulatory Query + Audit Dashboard
```

### 4.2 服务组件

- `intent-gateway`：接收外部任务，完成认证、限流、幂等和请求摘要。
- `agent-orchestrator`：创建 AgentTask，调度专业 Agent，管理任务状态。
- `agent-runtime`：运行专业 Agent，执行计划、工具选择和结果校验。
- `tool-registry`：登记工具 schema、权限、风险等级、幂等策略和审计要求。
- `policy-engine`：执行权限、额度、黑名单、KYC、AML、机构准入和高风险策略。
- `asset-service`：封装资产状态查询和资产业务规则。
- `transaction-service`：构造合约调用、发起签名、提交交易、等待确认。
- `audit-service`：记录 AgentTask、ToolCall、交易哈希、证据哈希和审计链路。
- `chain-indexer`：监听链上事件并同步链下索引。
- `storage-service`：管理对象存储、哈希校验和元数据索引。
- `monitor-service`：采集系统指标、链上事件、Agent 失败和异常状态。
- `recovery-service`：执行补偿计划、重试、状态修复和策略复核任务。

### 4.3 香港场景落地控制

本系统不把 MVP 直接声明为“已满足香港监管合规”。落地路径是把香港金融机构实际需要的控制点做成可替换模块，并让每个控制点都进入 AgentTask、ToolCall、PolicyEvaluation、TransactionRecord 和 AuditLog。

| 控制点 | MVP 落地方式 | 生产化替换对象 |
| --- | --- | --- |
| KYC / AML | `kyc_aml_profiles` 表、`tool.compliance.verifyKycAml` 工具、Identity Agent 强制校验 | 持牌 KYC/AML provider、制裁名单、PEP、风险评级、持续监控 |
| 持牌机构接入 | `licensed_institutions` 表、机构 license 状态和 permitted activities 校验 | SFC/HKMA/TCSP/托管人真实资质、机构证书、联盟成员准入流程 |
| 法律文件和 token 权益映射 | `legal_documents`、`asset_rights_mappings`、`tool.legal.verifyRightsMapping` | 基金文件、认购协议、股权/收益权法律意见、托管协议、文件哈希存证 |
| 真实联盟链或 Project Ensemble 类结算接口 | `ChainAdapter` 抽象，默认 mock，HTTP adapter 可对接外部链网关 | 联盟链 SDK、银行 tokenised deposit/wCBDC 结算网关、链上合约服务 |
| 托管、钱包、签名、密钥管理 | `custody_wallets`、`signature_requests`、`tool.custody.signTransaction` | KMS/HSM、MPC/托管钱包、审批工作流、交易签名策略 |
| 真实审计数据源和 oracle | `oracle_attestations`、`tool.oracle.verifyAttestation` | 算力计量系统、托管人确认、审计师报告、收益分配系统、外部 oracle |

因此，每一笔 `FundShareToken`、`PortfolioEquityRWA`、`ComputePowerToken` 操作都不是单纯写资产表，而是至少经过：身份/KYC/AML、持牌机构、法律权益映射、策略审批、托管签名、链交易、审计证据。算力收益类任务还必须经过 oracle attestation。

## 5. Agent 执行模型

### 5.1 Agent 角色

- Orchestrator Agent：解析任务、拆解计划、调度子 Agent、收敛结果。
- Identity Agent：核验用户、机构、Agent、节点、证书和授权范围。
- Asset Agent：执行资产注册、发行、拆分、合并、冻结、解冻、赎回和销毁。
- Transaction Agent：构造交易、请求签名、提交链上、确认交易和失败重试。
- Compliance Agent：执行 KYC、AML、黑名单、限额、监管规则和策略校验。
- Audit Agent：生成证据、比对链上链下状态、输出审计轨迹。
- Monitor Agent：监听链上事件、任务状态、系统指标和异常交易。
- Recovery Agent：生成并执行补偿计划，处理失败、超时和状态不一致。
- Governance Agent：辅助合约升级、参数调整、成员准入和联盟投票流程。

### 5.2 AgentTask 状态机

```text
Created
  -> Planning
  -> PolicyChecking
  -> ToolExecuting
  -> ChainConfirming
  -> Auditing
  -> Succeeded

Failed
  -> Recovering
  -> Compensating
  -> Succeeded | Failed

PolicyRejected
  -> Closed
```

状态含义：

- `Created`：任务已创建，尚未解析。
- `Planning`：Orchestrator Agent 正在生成执行计划。
- `PolicyChecking`：Compliance Agent 和 policy-engine 正在检查策略。
- `ToolExecuting`：专业 Agent 正在调用受控工具。
- `ChainConfirming`：链上交易已提交，等待确认。
- `Auditing`：Audit Agent 正在记录和校验审计证据。
- `Succeeded`：任务完成，链上链下状态一致。
- `Failed`：执行失败，需要恢复或关闭。
- `Recovering`：Recovery Agent 正在生成恢复计划。
- `Compensating`：正在执行补偿动作。
- `PolicyRejected`：策略拒绝，不执行状态变更。

### 5.3 执行约束

- Agent 不能直接修改数据库、账本、对象存储或文件。
- Agent 必须通过 tool-registry 中注册的工具执行动作。
- 每次工具调用必须有 `agent_task_id`、`agent_id`、`tool_name`、`input_hash`、`output_hash` 和 `policy_result`。
- 状态变更类工具必须写入 AuditLog。
- 合约交易必须包含 `agent_task_id` 或其哈希，用于关联链上事件和 Agent 执行记录。
- Agent 的自然语言推理只作为辅助上下文，不作为最终事实来源。

## 6. 核心数据模型

### 6.1 AgentTask

```text
AgentTask {
  task_id: string
  requester: string
  requester_type: User | Institution | System
  intent: string
  intent_hash: string
  constraints: object
  authorization_scope: string[]
  assigned_agent: string
  plan_hash: string
  policy_result: Approved | Rejected | NeedPolicyReview
  execution_status: Created | Planning | PolicyChecking | ToolExecuting | ChainConfirming | Auditing | Succeeded | Failed | Recovering | Compensating | PolicyRejected
  related_tx_hashes: string[]
  evidence_hash: string
  idempotency_key: string
  created_at: timestamp
  updated_at: timestamp
}
```

### 6.2 AgentPlan

```text
AgentPlan {
  plan_id: string
  task_id: string
  planner_agent_id: string
  steps: PlanStep[]
  required_tools: string[]
  risk_level: Low | Medium | High | Critical
  policy_snapshot_hash: string
  plan_hash: string
  status: Draft | Approved | Rejected | Executed
  created_at: timestamp
}
```

### 6.3 ToolCall

```text
ToolCall {
  tool_call_id: string
  task_id: string
  agent_id: string
  tool_name: string
  input_hash: string
  output_hash: string
  required_role: string
  risk_level: Low | Medium | High | Critical
  policy_result: Approved | Rejected
  result: Success | Failed
  error_code: string
  started_at: timestamp
  finished_at: timestamp
}
```

### 6.4 Asset

```text
Asset {
  asset_id: string
  asset_type: string
  issuer: address
  owner: address
  amount: uint64
  metadata_hash: string
  status: Created | Issued | Frozen | Transferred | Redeemed | Burned
  created_by_task_id: string
  updated_by_task_id: string
  created_at: timestamp
  updated_at: timestamp
}
```

### 6.5 TransactionRecord

```text
TransactionRecord {
  tx_id: string
  tx_hash: string
  task_id: string
  contract_name: string
  method_name: string
  caller: address
  status: Pending | Confirmed | Failed | Reverted
  block_height: uint64
  block_hash: string
  submitted_at: timestamp
  confirmed_at: timestamp
}
```

### 6.6 AuditLog

```text
AuditLog {
  log_id: string
  operator: address
  action: string
  target_id: string
  agent_task_id: string
  agent_id: string
  tx_hash: string
  tool_call_hash: string
  request_hash: string
  result: Success | Failed
  evidence_hash: string
  timestamp: timestamp
}
```

## 7. 受控工具接口

### 7.1 工具定义

```text
AgentTool {
  tool_name: string
  input_schema: object
  output_schema: object
  required_role: string
  risk_level: Low | Medium | High | Critical
  idempotent: boolean
  audit_required: boolean
  timeout_ms: uint64
}
```

### 7.2 工具清单

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

### 7.3 工具调用规则

- 所有工具调用必须带 `task_id` 和 `agent_id`。
- 高风险工具必须先调用 `tool.policy.evaluate`。
- 状态变更工具必须是幂等或显式声明非幂等并提供补偿策略。
- 工具输入和输出必须保存哈希，敏感明文只存链下受控区域。
- 工具失败必须返回标准错误码、可重试标识和补偿建议。

## 8. API 设计

### 8.1 Agent 任务 API

```text
POST /agent/tasks
GET  /agent/tasks/{task_id}
POST /agent/tasks/{task_id}/approve
POST /agent/tasks/{task_id}/cancel
GET  /agent/tasks/{task_id}/audit
GET  /agent/tasks/{task_id}/events
```

`approve` 表示机构授权信号，不表示人工直接执行系统操作。授权后仍由 Agent 完成具体动作。

### 8.2 创建任务请求

```text
CreateAgentTaskRequest {
  requester: string
  requester_signature: string
  intent: string
  constraints: object
  attachments: string[]
  authorization_scope: string[]
  risk_preference: Low | Medium | High
  idempotency_key: string
}
```

### 8.3 创建任务响应

```text
CreateAgentTaskResponse {
  task_id: string
  status: Created
  intent_hash: string
  estimated_risk_level: Low | Medium | High | Critical
  audit_url: string
}
```

### 8.4 兼容资产 API

```text
POST /assets/register -> creates AgentTask
POST /assets/issue    -> creates AgentTask
POST /assets/transfer -> creates AgentTask
POST /assets/freeze   -> creates AgentTask
POST /assets/redeem   -> creates AgentTask
GET  /assets/{asset_id}
GET  /transactions/{tx_hash}
GET  /audit/assets/{asset_id}
```

兼容资产 API 只作为任务生成入口，不允许绕过 AgentTask、policy-engine、tool-registry 或 audit-service。

## 9. 智能合约设计

### 9.1 合约职责

- 维护资产状态机。
- 校验调用方是否为授权机构、授权 Agent 或系统账号。
- 校验资产状态、余额、冻结状态和交易前置条件。
- 记录 `agent_task_id_hash`，关联链上事件与 Agent 执行轨迹。
- 发出标准事件，供 chain-indexer 和 Monitor Agent 订阅。

### 9.2 核心接口

```text
registerAsset(agent_task_id_hash, asset_id, asset_type, metadata_hash)
issueAsset(agent_task_id_hash, asset_id, owner, amount)
transferAsset(agent_task_id_hash, asset_id, from, to, amount)
freezeAsset(agent_task_id_hash, asset_id, reason_hash)
unfreezeAsset(agent_task_id_hash, asset_id)
redeemAsset(agent_task_id_hash, asset_id, amount)
burnAsset(agent_task_id_hash, asset_id)
queryAsset(asset_id)
```

### 9.3 链上事件

```text
AgentTaskLinked(agent_task_id_hash, tx_hash)
AssetRegistered(asset_id, issuer, metadata_hash)
AssetIssued(asset_id, owner, amount)
AssetTransferred(asset_id, from, to, amount)
AssetFrozen(asset_id, operator, reason_hash)
AssetUnfrozen(asset_id, operator)
AssetRedeemed(asset_id, owner, amount)
AssetBurned(asset_id, operator)
```

## 10. 核心业务流程

### 10.1 资产发行

1. 发行方提交目标任务、资产元数据、证明文件和授权范围。
2. Orchestrator Agent 创建 AgentTask 并生成发行计划。
3. Identity Agent 校验发行方、接收方、Agent 和工具权限。
4. Compliance Agent 检查资产类型、发行额度、接收方资格和监管规则。
5. Asset Agent 调用 `tool.storage.putObject` 保存文件并生成 `metadata_hash`。
6. Asset Agent 调用 `tool.asset.register` 准备资产注册参数。
7. Transaction Agent 调用 `tool.transaction.submit` 提交 `registerAsset`。
8. Transaction Agent 提交 `issueAsset`。
9. Monitor Agent 等待链上确认并同步链下索引。
10. Audit Agent 记录计划哈希、工具调用哈希、交易哈希和证据哈希。
11. Orchestrator Agent 返回发行结果、资产 ID、交易哈希和审计入口。

### 10.2 资产转让

1. 持有人提交转让目标和授权签名。
2. Orchestrator Agent 解析资产 ID、转出方、转入方、数量和约束。
3. Identity Agent 校验双方身份和授权范围。
4. Asset Agent 查询资产余额、状态、冻结状态和可转让规则。
5. Compliance Agent 执行 KYC、AML、黑名单、限额和监管检查。
6. Transaction Agent 提交 `transferAsset` 合约交易。
7. Monitor Agent 确认链上 `AssetTransferred` 事件。
8. chain-indexer 更新链下索引。
9. Audit Agent 记录执行轨迹。

### 10.3 冻结与解冻

1. 监管机构、托管机构或策略触发器提交冻结目标。
2. Compliance Agent 校验冻结原因和权限。
3. Asset Agent 查询资产状态。
4. Transaction Agent 提交 `freezeAsset` 或 `unfreezeAsset`。
5. Audit Agent 记录原因哈希、任务哈希和交易哈希。

### 10.4 赎回与销毁

1. 持有人或发行方提交赎回或销毁目标。
2. Orchestrator Agent 生成执行计划。
3. Identity Agent 和 Compliance Agent 校验业务条件。
4. Asset Agent 查询资产状态和余额。
5. Transaction Agent 提交 `redeemAsset` 或 `burnAsset`。
6. Monitor Agent 确认链上状态变更。
7. Audit Agent 生成完整生命周期审计记录。

### 10.5 异常补偿

1. Monitor Agent 发现交易失败、超时、索引不一致或策略冲突。
2. Recovery Agent 读取失败原因、当前链上状态、历史任务和补偿策略。
3. Recovery Agent 生成补偿计划。
4. Compliance Agent 校验补偿计划。
5. 对应 Agent 执行重试、冻结、索引回滚、状态修复或关闭任务。
6. Audit Agent 记录异常原因、补偿计划、执行结果和最终状态。

## 11. 链下存储与索引

### 11.1 存储分层

- 关系型数据库：AgentTask、ToolCall、TransactionRecord、AuditLog、用户映射、业务索引。
- 对象存储：合同、凭证、图片、PDF、合规材料和审计附件。
- 搜索引擎：资产生命周期、审计日志、交易记录和异常报告检索。
- 缓存：热点资产、交易状态、策略快照和任务状态。
- 向量库：制度规则、历史案例、业务文档、Agent 任务上下文和知识检索。

### 11.2 完整性策略

- 链下文件生成 `content_hash`。
- 多文件批次生成 Merkle Root。
- `metadata_hash` 或 Merkle Root 写入链上交易。
- Agent plan、tool input、tool output 和 audit evidence 均生成哈希。
- 审计查询必须能从资产 ID 追溯到 AgentTask、ToolCall、TransactionRecord 和链上事件。

## 12. 安全设计

### 12.1 身份与权限

- 所有用户、机构、节点、Agent 和工具都使用可验证身份。
- Agent 权限由角色、工具范围、任务授权、机构授权和策略结果共同决定。
- 合约层和业务层均执行权限校验。
- 工具不能只信任 Agent 声明，必须独立校验调用上下文。

### 12.2 策略引擎

策略引擎至少覆盖：

- 机构准入。
- 用户 KYC 状态。
- AML 和黑名单。
- 资产类型白名单。
- 单笔和累计额度。
- 高风险动作阈值。
- 合约调用权限。
- Agent 角色和工具权限。
- 时间窗口、区域和监管限制。

### 12.3 密钥管理

- 私钥由 KMS、HSM 或安全钱包托管。
- Agent 只能发起签名请求，不能读取私钥。
- 签名前必须校验 task、policy、tool_call 和 contract payload。
- 签名请求和签名结果都必须进入审计记录。

### 12.4 Prompt 注入隔离

- 外部文档、网页、用户输入和附件均视为不可信上下文。
- 不可信上下文不能改变系统指令、工具权限、策略或签名规则。
- Agent 生成的参数必须通过 schema 校验和策略校验。
- 高风险工具不接受自由文本作为唯一执行参数。

### 12.5 审计不可绕过

- 状态变更必须先创建 AgentTask。
- 状态变更必须产生 ToolCall。
- 链上交易必须关联 AgentTask。
- 审计记录必须关联 tool_call_hash、request_hash、tx_hash 和 evidence_hash。

## 13. 可观测性与运维

### 13.1 关键指标

- AgentTask 创建数、成功率、失败率、补偿率。
- Agent 计划耗时、工具调用耗时、链上确认耗时、审计完成耗时。
- 工具调用成功率和错误码分布。
- 策略拒绝率和高风险任务比例。
- 链上 TPS、出块时间、确认延迟和节点健康状态。
- 链下索引延迟和链上链下一致性。
- 对象存储哈希校验失败数。

### 13.2 日志与追踪

每个请求必须贯穿以下追踪字段：

```text
request_id
task_id
agent_id
tool_call_id
tx_hash
block_height
evidence_hash
```

### 13.3 告警

- AgentTask 长时间停留在非终态。
- ToolCall 失败率超过阈值。
- 链上确认延迟超过阈值。
- 链下索引落后超过阈值。
- policy-engine 异常或不可用。
- 哈希校验失败。
- 审计写入失败。
- 节点共识异常。

## 14. 一致性与故障恢复

### 14.1 一致性原则

- 链上状态是资产最终可信状态。
- 链下索引用于查询加速，不作为最终事实来源。
- AgentTask 状态必须与交易状态和审计状态对齐。
- Recovery Agent 修复状态时必须先读取链上状态。

### 14.2 幂等策略

- `POST /agent/tasks` 使用 `idempotency_key` 防止重复任务。
- 工具调用使用 `tool_call_id` 防止重复执行。
- 合约调用使用 nonce 或请求编号防止重放。
- 链下写入通过 content hash 防止重复对象。

### 14.3 补偿策略

- 交易未提交：关闭任务或重新生成交易。
- 交易已提交但未确认：等待、查询或重提状态查询。
- 交易失败：记录失败原因，执行可重试策略或关闭任务。
- 链上成功但链下索引失败：重放链上事件修复索引。
- 审计失败：阻塞任务完成，直到 AuditLog 写入成功。

## 15. 技术选型基线

本方案不强制具体实现栈，但建议 MVP 采用以下可替换组件：

- Agent runtime：支持工具调用、状态机、任务队列和可观测性的 Agent 框架。
- API service：REST/gRPC 网关。
- Policy engine：规则引擎或策略服务。
- Blockchain：支持 PBFT/IBFT 的许可链平台。
- Smart contracts：资产状态机合约。
- Database：PostgreSQL 或兼容关系型数据库。
- Object storage：S3 兼容对象存储。
- Search：OpenSearch 或 Elasticsearch。
- Cache：Redis。
- Vector store：pgvector、Milvus 或同类向量库。
- Queue：Kafka、NATS 或 RabbitMQ。
- KMS/HSM：云 KMS、机构 HSM 或安全钱包。
- Observability：OpenTelemetry、Prometheus、Grafana 和集中日志。

## 16. MVP 交付计划

### 16.1 第一阶段：基础闭环

- 搭建 4 节点联盟链。
- 实现资产注册、发行、转让、冻结、赎回合约。
- 实现 AgentTask、ToolCall、AuditLog 基础表。
- 实现 Orchestrator、Identity、Asset、Transaction、Audit Agent。
- 实现 `POST /agent/tasks` 和任务查询 API。
- 实现对象存储哈希上链。
- 完成资产发行和转让闭环。

### 16.2 第二阶段：合规与恢复

- 实现 Compliance Agent 和 policy-engine。
- 实现 KYC、黑名单、额度和高风险策略。
- 实现 Monitor Agent 和链上事件 indexer。
- 实现 Recovery Agent 和补偿策略。
- 增加冻结、解冻、赎回、销毁流程。
- 完成链上链下一致性校验。

### 16.3 第三阶段：生产化

- 接入 KMS/HSM。
- 完成全链路审计与监管查询。
- 增加多机构治理流程。
- 增加性能压测和故障演练。
- 增加向量知识库和策略文档检索。
- 增加安全评审和 prompt 注入防护测试。

## 17. 评测方案

### 17.1 实验配置

```text
联盟节点：4 个
Agent 数量：8-16 个专业 Agent
客户端并发任务：10 / 50 / 100 / 500
交易类型：注册、发行、转让、冻结、赎回
Agent 任务类型：单步任务、多步任务、异常补偿任务、审计查询任务
测试时长：每组 10-30 分钟
```

### 17.2 指标

- Agent 任务成功率。
- Agent 执行平均延迟和 P95 延迟。
- 计划正确率。
- 工具调用正确率。
- 链上 TPS。
- 链上确认平均延迟和 P95 延迟。
- 链上链下一致性。
- 节点、工具或 Agent 故障下的可用性。
- 存储增长：账本、索引、Agent 记忆和审计日志。
- 审计完整性。
- 策略拒绝率和违规率。
- 模型、Agent 框架、共识、存储或合约替换成本。

## 18. 风险与缓解

| 风险 | 影响 | 缓解 |
| --- | --- | --- |
| Agent 生成错误计划 | 错误交易或任务失败 | schema 校验、策略校验、状态校验、低风险灰度 |
| Prompt 注入 | 越权工具调用 | 不可信上下文隔离、工具权限固定、策略引擎前置 |
| 私钥泄露 | 资产被盗 | KMS/HSM、Agent 不接触私钥、签名审计 |
| 链下索引不一致 | 查询错误 | 链上事件重放、Monitor Agent 校验、索引修复 |
| 审计缺失 | 不可追溯 | 状态变更强制 AuditLog，审计失败阻塞任务完成 |
| 合约升级风险 | 资产状态异常 | 治理审批、测试网验证、版本化合约 |
| 单点服务故障 | 任务中断 | 服务冗余、队列持久化、Recovery Agent 补偿 |

## 19. 输出质量检查

本方案按 `$agentic-consortium-chain-baseline` skill 的检查项生成，覆盖情况如下：

| 检查项 | 状态 |
| --- | --- |
| Agent-native 操作原则 | 已覆盖 |
| 六层总体架构 | 已覆盖 |
| 专业 Agent 角色 | 已覆盖 |
| AgentTask 执行状态 | 已覆盖 |
| 受控工具层与工具清单 | 已覆盖 |
| 资产、交易、审计数据模型 | 已覆盖 |
| 任务 API 与兼容 API | 已覆盖 |
| 智能合约接口与事件 | 已覆盖 |
| 发行、转让、冻结、赎回、补偿流程 | 已覆盖 |
| 链下存储与哈希完整性 | 已覆盖 |
| 身份、权限、策略、密钥、安全设计 | 已覆盖 |
| 可观测性、故障恢复、幂等 | 已覆盖 |
| MVP 阶段计划 | 已覆盖 |
| 实验与评测指标 | 已覆盖 |

结论：该 skill 能够稳定产出一份结构完整、Agent-native 约束明确、可进入实现拆解阶段的系统技术方案。后续可继续用该 skill 生成更细的数据库 DDL、合约伪代码、服务接口 OpenAPI、Agent prompt/spec 和测试用例。
