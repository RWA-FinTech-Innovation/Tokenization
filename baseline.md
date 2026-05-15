# AI Agent 原生联盟链 + 模块化 Baseline

## 1. 基线目标

本 baseline 以联盟链作为可信协作底座，以模块化架构作为系统组织方式，并将 AI Agent 作为系统的主要执行主体。系统面向多机构参与的资产确权、发行、流转、结算和审计场景，默认参与方均为已准入主体，通过许可链身份体系、共识机制和智能合约保证业务状态的一致性、可追溯性和可审计性；通过 AI Agent 完成任务理解、计划生成、工具调用、链上交易提交、状态核验、异常处理和审计归档。

该 baseline 的核心设定是：用户、机构或外部系统不直接操作底层模块，而是向 AI Agent 提交目标、约束和授权；AI Agent 根据策略和权限调用系统工具完成操作。人类或机构角色主要负责授权、治理和策略配置，系统内的资产、交易、审计、监控和异常处理操作均由 Agent 执行。

该 baseline 不追求最高性能或最复杂的隐私增强能力，而是提供一个可复现、可扩展、便于对比实验的 Agent-native 基础方案。

## 2. 设计原则

1. Agent-first：业务操作默认由 AI Agent 发起和执行，外部输入被视为任务目标、约束或授权信号。
2. 许可准入：所有节点、机构、用户、Agent 和工具均通过联盟治理流程完成注册、认证和授权。
3. 链上可信：关键业务状态、交易哈希、资产状态变更、Agent 决策摘要和审计证据上链保存。
4. 链下扩展：大文件、敏感明文数据、Agent 运行日志和高频查询数据存储在链下，只将索引、哈希和必要状态写入链上。
5. 模块解耦：Agent 编排、身份、权限、资产、交易、合约、存储、审计和 API 网关以模块形式划分，通过稳定接口协同。
6. 可插拔实现：大模型、Agent 框架、共识算法、存储后端、隐私策略和业务合约可替换，便于后续扩展和实验对比。
7. 策略约束执行：Agent 只能通过受控工具调用改变系统状态，所有高风险动作必须经过策略引擎校验。
8. 全流程审计：资产生命周期中的创建、发行、转移、冻结、销毁和结算均保留可验证记录，同时保留 Agent 的任务、计划、工具调用和结果证明。

## 3. 总体架构

系统分为六层：

1. 意图接入层：接收用户、机构和外部系统提交的自然语言目标、结构化任务、事件触发器和审批信号。
2. Agent 执行层：负责任务理解、计划拆解、多 Agent 协作、工具选择、动作执行、状态校验和异常恢复。
3. 业务工具层：将资产管理、交易管理、账户管理、合规审核、结算清算等能力封装为 Agent 可调用工具。
4. 合约层：通过智能合约定义资产状态机、权限校验、交易规则和事件日志。
5. 联盟链层：负责节点通信、共识、账本存储、交易排序、区块生成和链上事件。
6. 链下服务层：包括数据库、对象存储、向量库、消息队列、索引服务、监控审计和密钥管理服务。

推荐基础形态：

```text
User / Institution / Business System
        |
Intent API / Event Trigger / Approval Signal
        |
AI Agent Orchestrator
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
Off-chain DB / Object Storage / Vector Memory / Audit / Monitoring
```

## 4. 核心模块

### 4.1 AI Agent 执行层

职责：

- 接收目标任务并转化为可执行计划。
- 根据任务类型选择专业 Agent、工具、合约和数据源。
- 调用受控工具完成资产发行、转让、冻结、赎回、审计查询和异常处置。
- 在每一步执行前检查权限、策略、资产状态和风险等级。
- 在执行后核验链上交易、链下索引、审计记录和业务状态是否一致。
- 将任务、计划、工具调用、关键推理摘要、输入输出哈希和最终结果写入审计链路。

基础 Agent 角色：

- Orchestrator Agent：总控 Agent，负责理解任务、拆解计划、调度子 Agent 和收敛结果。
- Identity Agent：负责身份核验、权限检查、机构准入和证书状态检查。
- Asset Agent：负责资产注册、发行、拆分、合并、冻结、解冻、赎回和销毁。
- Transaction Agent：负责交易构造、签名请求、提交上链、确认等待和失败重试。
- Compliance Agent：负责 KYC、AML、限额、黑名单、监管规则和策略校验。
- Audit Agent：负责审计证据生成、链上链下记录比对、异常报告和追溯查询。
- Monitor Agent：负责监听链上事件、系统指标、失败任务和异常交易。
- Recovery Agent：负责补偿流程、重试策略、策略复核任务生成和状态修复执行。

Agent 执行状态：

```text
AgentTask {
  task_id: string
  requester: address
  assigned_agent: string
  intent: string
  plan_hash: string
  policy_result: Approved | Rejected | NeedPolicyReview
  execution_status: Pending | Running | Succeeded | Failed | Compensating
  related_tx_hashes: string[]
  evidence_hash: string
  created_at: timestamp
  updated_at: timestamp
}
```

执行约束：

- Agent 不能直接修改数据库、账本或文件，只能通过工具层执行动作。
- 每个工具必须声明输入 schema、输出 schema、权限范围、风险等级和幂等策略。
- 每个状态变更类工具必须生成审计事件。
- Agent 的自然语言推理不作为最终事实来源，最终事实以链上状态、签名结果和可验证证据为准。
- 高风险任务可以完全自动执行，但必须满足预配置策略，例如金额阈值、机构白名单、资产状态和合约规则。

### 4.2 身份与权限模块

职责：

- 管理联盟成员机构、节点、用户和服务账号。
- 管理 Agent 身份、Agent 角色、工具调用权限和任务授权范围。
- 基于证书或 DID 进行身份认证。
- 提供角色、权限、操作范围和合约调用权限控制。
- 支持用户实名信息与链上地址的映射，但不直接在链上存储敏感明文。

基础角色：

- Admin：联盟治理和系统配置。
- Issuer：资产发行方。
- Custodian：资产托管或监管节点。
- Trader：资产持有人或交易参与方。
- Auditor：审计与监管查询方。
- Agent：自动执行主体，只能在授权范围内调用工具。
- Tool：被 Agent 调用的受控执行能力，必须绑定权限和审计策略。

### 4.3 资产模块

职责：

- 定义资产类型、资产元数据、所有权关系和状态机。
- 支持资产注册、发行、拆分、合并、冻结、解冻、转让和销毁。
- 将资产核心状态写入链上，将证明文件、合同、凭证等大文件存入链下。
- 向 Asset Agent 暴露受控工具接口，禁止绕过 Agent 执行链路直接变更资产状态。

基础资产模型：

```text
Asset {
  asset_id: string
  asset_type: string
  issuer: address
  owner: address
  amount: uint64
  metadata_hash: string
  status: Created | Issued | Frozen | Transferred | Redeemed | Burned
  created_at: timestamp
  updated_at: timestamp
}
```

### 4.4 交易模块

职责：

- 接收 Agent 工具调用请求并生成链上交易。
- 校验交易双方身份、资产状态、余额、授权和合规规则。
- 维护交易生命周期，包括待确认、已上链、失败、回滚补偿等状态。
- 监听链上事件并同步链下索引。
- 向 Transaction Agent 返回交易哈希、确认状态、失败原因和补偿建议。

基础交易流程：

1. 用户或外部系统提交目标任务，例如“发行 1000 份资产给指定账户”。
2. Orchestrator Agent 解析任务并生成执行计划。
3. Identity Agent、Compliance Agent 和 Asset Agent 分别完成身份、合规和资产状态检查。
4. Transaction Agent 构造合约调用交易并提交到联盟链。
5. 联盟链完成排序、共识和区块提交。
6. Monitor Agent 监听链上事件并同步链下索引。
7. Audit Agent 记录操作日志、Agent 计划哈希、工具调用证据和链上交易哈希。
8. Orchestrator Agent 汇总执行结果并返回给请求方。

### 4.5 智能合约模块

职责：

- 实现资产状态变更规则。
- 执行权限校验和交易前置条件检查。
- 生成标准化链上事件。
- 保证同一资产在并发操作下状态一致。
- 校验调用方是否为授权 Agent、机构或系统账号。
- 记录关键 Agent Task ID，便于链上状态与 Agent 执行记录关联。

核心合约接口：

```text
registerAsset(asset_id, asset_type, metadata_hash)
issueAsset(asset_id, owner, amount)
transferAsset(asset_id, from, to, amount)
freezeAsset(asset_id, reason_hash)
unfreezeAsset(asset_id)
redeemAsset(asset_id, amount)
burnAsset(asset_id)
queryAsset(asset_id)
```

### 4.6 共识与账本模块

职责：

- 在多个联盟节点之间维护一致账本。
- 提供交易排序、区块打包、状态提交和历史查询能力。
- 支持可配置共识算法，如 PBFT、Raft 或 IBFT。

baseline 默认配置：

- 节点数量：4 个联盟节点。
- 共识机制：PBFT 或 IBFT。
- 出块间隔：1-3 秒。
- 区块大小：根据交易大小设置为 500-2000 笔交易。
- 容错目标：支持少数节点故障，不支持开放匿名节点接入。

### 4.7 链下存储模块

职责：

- 保存资产证明文件、业务合同、用户资料、Agent 任务日志、审计附件和查询索引。
- 对链下数据计算哈希，并将哈希或 Merkle Root 写入链上。
- 提供按资产、用户、交易、区块高度和时间范围的查询能力。

推荐存储划分：

- 关系型数据库：业务索引、交易状态、用户映射关系。
- 对象存储：合同、凭证、图片、PDF 等大文件。
- 搜索引擎：审计检索和复杂查询。
- 缓存：热点资产和交易状态查询。
- 向量库：Agent 任务上下文、制度规则、历史案例和业务文档检索。

### 4.8 审计与监管模块

职责：

- 记录所有关键操作的操作者、时间、请求参数摘要、交易哈希和结果。
- 支持按资产生命周期生成审计轨迹。
- 支持监管节点只读访问、异常交易告警和数据完整性校验。
- 记录 Agent 的任务输入、执行计划、工具调用序列、策略校验结果和最终状态。
- 支持回放 Agent 执行轨迹，但不要求保存完整敏感推理内容。

基础审计字段：

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
  timestamp: timestamp
}
```

## 5. 数据流

### 5.1 资产发行

1. 发行方提交目标任务、资产元数据、证明文件和授权范围。
2. Orchestrator Agent 解析发行目标，生成资产注册和发行计划。
3. Identity Agent 校验发行方身份、证书状态和 Agent 执行授权。
4. Compliance Agent 检查资产类型、发行额度、接收方资格和监管规则。
5. Asset Agent 调用链下存储工具保存文件并生成 metadata_hash。
6. Transaction Agent 调用合约工具完成资产注册和发行交易。
7. Monitor Agent 等待链上确认并同步链下索引。
8. Audit Agent 记录发行证据、Agent 执行计划哈希、工具调用哈希和交易哈希。
9. Orchestrator Agent 返回发行结果、资产 ID、交易哈希和审计入口。

### 5.2 资产转让

1. 持有人或业务系统提交转让目标，例如“将资产 A 的 100 份转给 B”。
2. Orchestrator Agent 解析任务并识别资产、转出方、转入方、数量和约束条件。
3. Identity Agent 校验转出方授权、转入方准入状态和 Agent 可调用权限。
4. Asset Agent 查询资产余额、冻结状态、锁定状态和可转让规则。
5. Compliance Agent 检查交易双方是否满足 KYC、AML、限额和黑名单规则。
6. Transaction Agent 构造并提交 transferAsset 合约交易。
7. Monitor Agent 确认链上事件，链下索引更新资产归属和交易状态。
8. Audit Agent 记录完整执行轨迹。

### 5.3 资产赎回或销毁

1. 持有人或发行方提交赎回或销毁目标。
2. Orchestrator Agent 判断任务类型并生成执行计划。
3. Identity Agent 和 Compliance Agent 校验调用权限、业务条件和监管规则。
4. Asset Agent 查询资产余额、状态和赎回条件。
5. Transaction Agent 提交 redeemAsset 或 burnAsset 合约交易。
6. Monitor Agent 确认链上状态变更。
7. Audit Agent 保留交易哈希、业务凭证哈希和 Agent 执行证据。

### 5.4 异常处理与补偿

1. Monitor Agent 发现交易失败、超时、链上链下状态不一致或规则冲突。
2. Recovery Agent 读取失败原因、当前链上状态、历史任务和补偿策略。
3. Recovery Agent 生成补偿计划，例如重试、撤销链下状态、冻结资产、触发策略复核任务或重新提交交易。
4. Compliance Agent 校验补偿计划是否符合策略。
5. Transaction Agent 或对应业务 Agent 执行补偿动作。
6. Audit Agent 记录异常原因、补偿计划、执行结果和最终状态。

## 6. 模块接口基线

### 6.1 意图与任务接口

外部系统不直接调用资产变更接口，而是创建 Agent 任务：

```text
POST /agent/tasks
GET  /agent/tasks/{task_id}
POST /agent/tasks/{task_id}/approve
POST /agent/tasks/{task_id}/cancel
GET  /agent/tasks/{task_id}/audit
GET  /agent/tasks/{task_id}/events
```

任务请求结构：

```text
CreateAgentTaskRequest {
  requester: string
  intent: string
  constraints: object
  attachments: string[]
  authorization_scope: string[]
  risk_preference: Low | Medium | High
  idempotency_key: string
}
```

### 6.2 Agent 工具接口

Agent 通过工具层调用业务能力，工具接口必须可审计、可限权、可重放校验：

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

工具描述基线：

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

### 6.3 兼容 API 接口

如需兼容传统系统，可以保留资产 API，但这些 API 只作为任务生成入口，内部仍转换为 Agent Task：

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

### 6.4 事件接口

```text
AgentTaskCreated(task_id, requester, intent_hash)
AgentPlanGenerated(task_id, agent_id, plan_hash)
AgentToolCalled(task_id, agent_id, tool_name, tool_call_hash)
AgentTaskCompleted(task_id, status, evidence_hash)
AssetRegistered(asset_id, issuer, metadata_hash)
AssetIssued(asset_id, owner, amount)
AssetTransferred(asset_id, from, to, amount)
AssetFrozen(asset_id, operator, reason_hash)
AssetUnfrozen(asset_id, operator)
AssetRedeemed(asset_id, owner, amount)
AssetBurned(asset_id, operator)
```

## 7. 安全基线

1. Agent 身份认证：所有 Agent、工具、节点、机构和用户都必须绑定可验证身份。
2. 工具权限控制：Agent 只能调用授权工具，工具自身必须校验调用方角色、任务授权和策略结果。
3. 双层权限校验：业务层和合约层都必须执行权限校验，不能只依赖 Agent 判断。
4. 策略引擎前置：高风险操作必须经过策略引擎，策略结果写入审计记录。
5. 数据隐私：链上只保存必要状态、索引、哈希和 Agent 执行证据，不保存敏感明文和完整隐私推理内容。
6. 密钥管理：私钥由 KMS、HSM 或安全钱包托管，Agent 不直接接触明文私钥。
7. 防重放：Agent 任务和链上交易必须包含 nonce、时间戳、idempotency_key 或唯一请求编号。
8. Prompt 注入隔离：外部文档、用户输入和网页内容只能作为不可信上下文，不能直接改变工具权限和系统策略。
9. 输出校验：Agent 生成的计划、参数和合约调用输入必须通过 schema、策略和状态校验。
10. 完整性校验：链下文件、Agent 计划和工具调用记录必须可通过链上哈希验证。
11. 审计留痕：关键操作不可绕过审计模块，所有状态变更必须可追溯到 Agent Task。

## 8. 实验与评测指标

为了将该方案作为 baseline，可从以下指标进行评测：

1. Agent 任务成功率：Agent Task 从创建到成功完成的比例。
2. Agent 执行延迟：从任务提交到链上确认和审计完成的平均时间、P95 时间。
3. 计划正确率：Agent 生成的计划是否满足业务规则、权限规则和合约约束。
4. 工具调用正确率：Agent 调用工具的参数是否完整、合法、可执行。
5. 链上吞吐量：每秒成功处理的资产注册、发行和转让交易数量。
6. 系统延迟：从 Agent 决策、工具调用、交易提交到链上确认的分段耗时。
7. 可扩展性：节点数量、Agent 数量、资产数量和并发任务增加时的性能变化。
8. 一致性：多节点账本状态、链下索引状态和 Agent 任务状态是否保持一致。
9. 可用性：少数节点、工具或 Agent 失败时系统是否仍能处理任务。
10. 存储开销：链上状态、区块数据、链下索引、Agent 记忆和审计日志的存储增长。
11. 审计完整性：是否可以从任一资产追溯完整生命周期和对应 Agent 执行轨迹。
12. 策略违规率：Agent 计划或工具调用被策略引擎拒绝的比例。
13. 模块替换成本：替换模型、Agent 框架、共识、存储或合约实现时需要修改的代码范围。

基础实验配置：

```text
联盟节点：4 个
Agent 数量：8-16 个专业 Agent
客户端并发任务：10 / 50 / 100 / 500
交易类型：注册、发行、转让、冻结、赎回
Agent 任务类型：单步任务、多步任务、异常补偿任务、审计查询任务
测试时长：每组 10-30 分钟
统计指标：任务成功率、工具调用成功率、TPS、平均延迟、P95 延迟、失败率、资源占用
```

## 9. 可扩展方向

该 baseline 后续可以扩展为以下版本：

1. 自主治理版本：由 Governance Agent 发起参数调整、合约升级建议和联盟成员投票流程。
2. 隐私增强版本：引入零知识证明、隐私交易、通道隔离或机密计算。
3. 跨链 Agent 版本：由 Cross-chain Agent 支持不同联盟链之间的资产映射、锁定和跨链结算。
4. 合规增强版本：接入 KYC、AML、黑名单、限额和监管报送模块，并由 Compliance Agent 自动执行。
5. 高性能版本：优化 Agent 任务队列、交易批处理、异步确认、事件索引和缓存策略。
6. 多模型协作版本：针对计划、校验、合规和异常恢复使用不同模型或规则引擎协同。
7. 治理增强版本：引入联盟成员投票、合约升级审批和参数变更治理。

## 10. Baseline 总结

本 baseline 的核心思想是：使用 AI Agent 作为系统执行主体，使用联盟链解决多机构之间的可信协作和状态一致性问题，使用模块化架构解决系统复杂度、可维护性和可扩展性问题。用户和外部系统只提交目标、约束和授权，Agent 负责计划、调用工具、执行交易、校验结果和生成审计证据。链上承载必要的可信状态、交易哈希和 Agent 执行证明，链下承载大规模数据存储、查询、Agent 记忆和业务编排。该方案适合作为资产 tokenization、多方协作账本、供应链金融、数字凭证和受监管交易系统的 Agent-native 基础实现与对比基线。
