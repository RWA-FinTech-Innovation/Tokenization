const state = {
  assetId: 'fund-share-hkpe-alice-001',
  tasks: [],
  lastResponse: {},
};

const $ = (id) => document.getElementById(id);

function readForm(form) {
  return Object.fromEntries(new FormData(form).entries());
}

function showToast(message) {
  const toast = $('toast');
  toast.textContent = message;
  toast.classList.add('show');
  window.clearTimeout(showToast.timer);
  showToast.timer = window.setTimeout(() => toast.classList.remove('show'), 2600);
}

function setRaw(payload) {
  state.lastResponse = payload;
  $('rawOutput').textContent = JSON.stringify(payload, null, 2);
}

async function api(path, options = {}) {
  const response = await fetch(path, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...(options.headers || {}),
    },
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(data.message || `${response.status} ${response.statusText}`);
  }
  setRaw(data);
  return data;
}

function badge(value) {
  const normalized = String(value || '').toLowerCase();
  const cls = normalized.includes('succeeded') || normalized.includes('approved') || normalized.includes('confirmed')
    ? 'badge ok'
    : normalized.includes('failed') || normalized.includes('rejected')
      ? 'badge bad'
      : 'badge amber';
  return `<span class="${cls}">${escapeHtml(value || '-')}</span>`;
}

function escapeHtml(value) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#039;');
}

function shortHash(value) {
  if (!value) return '-';
  const text = String(value);
  return text.length > 24 ? `${text.slice(0, 12)}...${text.slice(-8)}` : text;
}

function intentLabel(intent) {
  return {
    subscribe_fund_share: 'LP 认购基金份额',
    invest_portfolio_equity: 'GP 投资项目',
    record_compute_revenue: '算力收益审计',
    issue_asset: '通用资产发行',
    transfer_asset: '通用资产转让',
  }[intent] || intent;
}

function toolLabel(toolName) {
  return {
    'tool.identity.verifySubject': '身份与主体校验',
    'tool.policy.evaluate': '策略审批',
    'tool.compliance.verifyKycAml': 'KYC / AML 与持牌检查',
    'tool.legal.verifyRightsMapping': '法律文件与权益映射',
    'tool.oracle.verifyAttestation': '算力收益 oracle 证明',
    'tool.custody.signTransaction': '托管钱包签名',
    'tool.transaction.submit': '提交联盟链交易',
    'tool.asset.issue': '写入资产索引',
    'tool.asset.recordComputeRevenue': '记录算力收益资产',
    'tool.asset.transfer': '更新资产持有人',
    'tool.asset.query': '查询资产状态',
  }[toolName] || toolName;
}

function assetBusinessRows(asset) {
  if (asset.asset_type === 'FundShareToken') {
    return [
      ['业务链路', 'LP subscription -> FundShareToken'],
      ['权益锚定', 'HK PE Fund I fund interest'],
    ];
  }
  if (asset.asset_type === 'PortfolioEquityRWA') {
    return [
      ['业务链路', 'GP investment -> PortfolioEquityRWA'],
      ['权益锚定', 'AI Compute Infrastructure Ltd'],
    ];
  }
  if (asset.asset_type === 'ComputePowerToken') {
    return [
      ['业务链路', 'Compute revenue -> audited token record'],
      ['权益锚定', 'AI Compute Cluster A revenue evidence'],
    ];
  }
  return [];
}

async function checkHealth() {
  try {
    const data = await api('/health');
    $('healthPill').textContent = data.status === 'ok' ? '后端在线' : '状态未知';
    $('healthPill').className = data.status === 'ok' ? 'status-pill ok' : 'status-pill neutral';
  } catch (error) {
    $('healthPill').textContent = '后端离线';
    $('healthPill').className = 'status-pill bad';
  }
}

async function createFundSubscriptionTask(event) {
  event.preventDefault();
  const values = readForm(event.currentTarget);
  state.assetId = values.asset_id;
  const task = await api('/agent/tasks', {
    method: 'POST',
    body: JSON.stringify({
      requester: values.lp,
      requester_type: 'user',
      requester_signature: `sig-${values.lp}`,
      intent: 'subscribe_fund_share',
      constraints: {
        asset_id: values.asset_id,
        fund_id: values.fund_id,
        fund_manager: values.fund_manager,
        lp: values.lp,
        share_units: Number(values.share_units),
        subscription_amount_hkd: Number(values.subscription_amount_hkd),
        metadata_hash: `hash-${values.fund_id}-${values.lp}`,
      },
      authorization_scope: ['subscribe_fund_share'],
      risk_preference: 'medium',
      idempotency_key: `ui-fund-subscribe-${values.asset_id}-${Date.now()}`,
    }),
  });
  rememberTask(task);
  const completed = await waitForTask(task.task_id);
  rememberTask(completed);
  await refreshAll();
  showToast('基金份额认购已完成');
}

async function createPortfolioInvestmentTask(event) {
  event.preventDefault();
  const values = readForm(event.currentTarget);
  state.assetId = values.asset_id;
  const task = await api('/agent/tasks', {
    method: 'POST',
    body: JSON.stringify({
      requester: values.fund_manager,
      requester_type: 'institution',
      requester_signature: `sig-${values.fund_manager}`,
      intent: 'invest_portfolio_equity',
      constraints: {
        asset_id: values.asset_id,
        fund_id: values.fund_id,
        fund_manager: values.fund_manager,
        portfolio_company: values.portfolio_company,
        equity_units: Number(values.equity_units),
        investment_amount_hkd: Number(values.investment_amount_hkd),
        metadata_hash: `hash-${values.fund_id}-${values.portfolio_company}`,
      },
      authorization_scope: ['invest_portfolio_equity'],
      risk_preference: 'medium',
      idempotency_key: `ui-portfolio-invest-${values.asset_id}-${Date.now()}`,
    }),
  });
  rememberTask(task);
  const completed = await waitForTask(task.task_id);
  rememberTask(completed);
  await refreshAll();
  showToast('项目股权 RWA 已生成');
}

async function createComputeRevenueTask(event) {
  event.preventDefault();
  const values = readForm(event.currentTarget);
  state.assetId = values.asset_id;
  const task = await api('/agent/tasks', {
    method: 'POST',
    body: JSON.stringify({
      requester: values.operator,
      requester_type: 'institution',
      requester_signature: `sig-${values.operator}`,
      intent: 'record_compute_revenue',
      constraints: {
        asset_id: values.asset_id,
        compute_project: values.compute_project,
        operator: values.operator,
        beneficiary: values.beneficiary,
        compute_units: Number(values.compute_units),
        revenue_amount_hkd: Number(values.revenue_amount_hkd),
        revenue_period: '2026-Q2',
        metadata_hash: `hash-${values.compute_project}-${values.beneficiary}`,
      },
      authorization_scope: ['record_compute_revenue'],
      risk_preference: 'medium',
      idempotency_key: `ui-compute-revenue-${values.asset_id}-${Date.now()}`,
    }),
  });
  rememberTask(task);
  const completed = await waitForTask(task.task_id);
  rememberTask(completed);
  await refreshAll();
  showToast('算力收益审计已记录');
}

async function waitForTask(taskId) {
  for (let i = 0; i < 40; i += 1) {
    const task = await api(`/agent/tasks/${encodeURIComponent(taskId)}`);
    rememberTask(task);
    if (['succeeded', 'failed', 'policy_rejected', 'cancelled'].includes(task.execution_status)) {
      return task;
    }
    await new Promise((resolve) => window.setTimeout(resolve, 180));
  }
  throw new Error(`任务超时: ${taskId}`);
}

function rememberTask(task) {
  state.tasks = [task, ...state.tasks.filter((item) => item.task_id !== task.task_id)].slice(0, 8);
  renderTasks();
}

async function refreshAll() {
  await Promise.allSettled([queryAsset(), queryAudit(), loadIdentity(), loadControls()]);
  renderMetrics();
}

async function loadIdentity() {
  const [institutions, users] = await Promise.all([
    api('/institutions'),
    api('/users'),
  ]);
  renderIdentity(institutions.institutions || [], users.users || []);
}

async function loadControls() {
  const [licenses, kycAml, legalDocs, rights, wallets, oracle, signatures] = await Promise.all([
    api('/compliance/licenses'),
    api('/compliance/kyc-aml'),
    api('/legal/documents'),
    api('/legal/rights'),
    api('/custody/wallets'),
    api('/oracle/attestations'),
    api('/custody/signatures'),
  ]);
  renderControls({
    licenses: licenses.licensed_institutions || [],
    kycAml: kycAml.kyc_aml_profiles || [],
    legalDocs: legalDocs.legal_documents || [],
    rights: rights.rights_mappings || [],
    wallets: wallets.wallets || [],
    oracle: oracle.oracle_attestations || [],
    signatures: signatures.signature_requests || [],
  });
}

async function queryAsset() {
  const assetId = currentAssetId();
  if (!assetId) return;
  const asset = await api(`/assets/${encodeURIComponent(assetId)}`);
  renderAsset(asset);
}

async function queryAudit() {
  const assetId = currentAssetId();
  if (!assetId) return;
  const audit = await api(`/audit/assets/${encodeURIComponent(assetId)}`);
  renderAudit(audit);
}

function currentAssetId() {
  state.assetId = state.assetId || $('fundShareAssetId').value || $('portfolioAssetId').value || $('computeAssetId').value;
  return state.assetId;
}

function renderAsset(asset) {
  $('assetState').classList.remove('empty');
  $('assetState').innerHTML = [
    ['Asset ID', asset.asset_id],
    ['Type', asset.asset_type],
    ...assetBusinessRows(asset),
    ['Issuer', asset.issuer],
    ['Owner', asset.owner],
    ['Amount', asset.amount],
    ['Status', asset.status],
    ['Chain Tx', shortHash(asset.chain_tx_hash)],
    ['Evidence Task', asset.updated_by_task_id],
  ].map(([key, value]) => `<div class="kv"><span>${key}</span><span>${escapeHtml(value)}</span></div>`).join('');
  $('metricOwner').textContent = asset.owner || '-';
}

function renderTasks() {
  $('metricTasks').textContent = state.tasks.length;
  if (!state.tasks.length) {
    $('taskList').className = 'task-list empty';
    $('taskList').textContent = '暂无任务';
    return;
  }
  $('taskList').className = 'task-list';
  $('taskList').innerHTML = state.tasks.map((task) => `
    <article class="task-item">
      <div class="task-row">
        <div class="task-title">${escapeHtml(intentLabel(task.intent))}</div>
        ${badge(task.execution_status)}
      </div>
      <div class="task-meta">task ${escapeHtml(task.task_id)}</div>
      <div class="task-meta">policy ${escapeHtml(task.policy_result || '-')} · tx ${escapeHtml(shortHash((task.related_tx_hashes || [])[0]))}</div>
      <div class="task-meta">KYC/AML · Legal rights · Custody sign · Chain audit</div>
    </article>
  `).join('');
}

function renderIdentity(institutions, users) {
  const node = $('identityList');
  node.className = 'identity-list';
  const institutionItems = institutions.map((item) => `
    <div class="identity-chip">
      <strong>${escapeHtml(item.institution_id)}</strong>
      <span>${escapeHtml(item.role)} · ${escapeHtml(item.status)}</span>
    </div>
  `).join('');
  const userItems = users.map((item) => `
    <div class="identity-chip">
      <strong>${escapeHtml(item.address)}</strong>
      <span>${escapeHtml(item.role)} · ${escapeHtml(item.kyc_status)}</span>
    </div>
  `).join('');
  node.innerHTML = `
    <div class="identity-group">
      <h3>Institutions</h3>
      ${institutionItems || '<div class="empty">暂无机构</div>'}
    </div>
    <div class="identity-group">
      <h3>Users</h3>
      ${userItems || '<div class="empty">暂无用户</div>'}
    </div>
  `;
}

function renderControls(data) {
  const node = $('controlsList');
  node.className = 'control-grid';
  const cards = [
    ['持牌机构', data.licenses.length, data.licenses.map((item) => `${item.institution_id}:${item.status}`).join(', ')],
    ['KYC / AML', data.kycAml.length, data.kycAml.map((item) => `${item.subject}:${item.aml_status}`).join(', ')],
    ['法律文件', data.legalDocs.length, data.legalDocs.map((item) => item.document_type).join(', ')],
    ['Token 权益映射', data.rights.length, data.rights.map((item) => item.asset_type).join(', ')],
    ['托管钱包', data.wallets.length, data.wallets.map((item) => item.owner).join(', ')],
    ['Oracle 证明', data.oracle.length, data.oracle.map((item) => item.status).join(', ')],
    ['签名请求', data.signatures.length, data.signatures.slice(-2).map((item) => item.signer).join(', ') || '等待 AgentTask'],
  ];
  node.innerHTML = cards.map(([title, count, detail]) => `
    <article class="control-card">
      <div class="section-kicker">${escapeHtml(title)}</div>
      <strong>${escapeHtml(count)}</strong>
      <span>${escapeHtml(detail || '-')}</span>
    </article>
  `).join('');
}

function renderAudit(audit) {
  renderTimeline('auditLogs', audit.audit_logs || [], (item) => ({
    title: item.action,
    meta: `${item.result} · ${shortHash(item.evidence_hash)} · ${item.created_at}`,
  }));
  renderTimeline('toolCalls', audit.tool_calls || [], (item) => ({
    title: toolLabel(item.tool_name),
    meta: `${item.agent_id} · ${item.result || '-'} · ${shortHash(item.output_hash)}`,
  }));
  renderTimeline('chainEvents', audit.chain_events || [], (item) => ({
    title: item.event_name,
    meta: `block ${item.block_height} · ${shortHash(item.tx_hash)}`,
  }));
  $('metricTools').textContent = String((audit.tool_calls || []).length);
  $('metricEvents').textContent = String((audit.chain_events || []).length);
}

function renderTimeline(id, items, mapper) {
  const node = $(id);
  if (!items.length) {
    node.className = 'timeline empty';
    node.textContent = '暂无记录';
    return;
  }
  node.className = 'timeline';
  node.innerHTML = items.map((item) => {
    const mapped = mapper(item);
    return `
      <article class="timeline-item">
        <div class="timeline-title">${escapeHtml(mapped.title)}</div>
        <div class="timeline-meta">${escapeHtml(mapped.meta)}</div>
      </article>
    `;
  }).join('');
}

function renderMetrics() {
  $('metricTasks').textContent = state.tasks.length;
}

async function resetDemo() {
  await api('/admin/reset', { method: 'POST', body: JSON.stringify({}) });
  state.tasks = [];
  $('assetState').className = 'state-view empty';
  $('assetState').textContent = '暂无资产状态';
  $('taskList').className = 'task-list empty';
  $('taskList').textContent = '暂无任务';
  $('auditLogs').className = 'timeline empty';
  $('auditLogs').textContent = '暂无审计日志';
  $('toolCalls').className = 'timeline empty';
  $('toolCalls').textContent = '暂无工具调用';
  $('chainEvents').className = 'timeline empty';
  $('chainEvents').textContent = '暂无链事件';
  $('metricOwner').textContent = '-';
  $('metricTasks').textContent = '0';
  $('metricTools').textContent = '0';
  $('metricEvents').textContent = '0';
  await loadControls();
  showToast('演示数据已重置');
}

function wire() {
  $('subscribeForm').addEventListener('submit', (event) => createFundSubscriptionTask(event).catch(showError));
  $('portfolioForm').addEventListener('submit', (event) => createPortfolioInvestmentTask(event).catch(showError));
  $('computeForm').addEventListener('submit', (event) => createComputeRevenueTask(event).catch(showError));
  ['fundShareAssetId', 'portfolioAssetId', 'computeAssetId'].forEach((id) => {
    $(id).addEventListener('input', (event) => {
      state.assetId = event.currentTarget.value;
    });
  });
  $('queryAssetBtn').addEventListener('click', () => queryAsset().catch(showError));
  $('queryAuditBtn').addEventListener('click', () => queryAudit().catch(showError));
  $('refreshIdentityBtn').addEventListener('click', () => loadIdentity().catch(showError));
  $('refreshControlsBtn').addEventListener('click', () => loadControls().catch(showError));
  $('refreshBtn').addEventListener('click', () => refreshAll().catch(showError));
  $('resetBtn').addEventListener('click', () => resetDemo().catch(showError));
}

function showError(error) {
  showToast(error.message || String(error));
  setRaw({ error: error.message || String(error) });
}

wire();
checkHealth();
loadIdentity().catch(showError);
loadControls().catch(showError);
