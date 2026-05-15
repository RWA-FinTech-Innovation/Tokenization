#!/usr/bin/env python3
"""End-to-end demo for PE fund RWA + compute token audit flows."""

from __future__ import annotations

import http.client
import json
import os
import socket
import tempfile
import threading
import time
from typing import Any

from app import App, make_handler
from http.server import ThreadingHTTPServer


def free_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.bind(("127.0.0.1", 0))
        return int(sock.getsockname()[1])


def request(port: int, method: str, path: str, payload: dict[str, Any] | None = None) -> dict[str, Any]:
    conn = http.client.HTTPConnection("127.0.0.1", port, timeout=10)
    body = json.dumps(payload).encode("utf-8") if payload is not None else None
    headers = {"Content-Type": "application/json"}
    conn.request(method, path, body=body, headers=headers)
    resp = conn.getresponse()
    raw = resp.read().decode("utf-8")
    conn.close()
    try:
        data = json.loads(raw) if raw else {}
    except json.JSONDecodeError:
        data = {"raw": raw}
    if resp.status >= 400:
        raise RuntimeError(f"{method} {path} failed: {resp.status} {data}")
    return data


def compact_task(task: dict[str, Any]) -> dict[str, Any]:
    return {
        "task_id": task["task_id"],
        "intent": task["intent"],
        "status": task["execution_status"],
        "policy_result": task.get("policy_result"),
        "related_tx_hashes": task.get("related_tx_hashes", []),
        "evidence_hash": task.get("evidence_hash"),
    }


def wait_task(port: int, task_id: str, timeout_s: float = 5.0) -> dict[str, Any]:
    deadline = time.time() + timeout_s
    while time.time() < deadline:
        task = request(port, "GET", f"/agent/tasks/{task_id}")
        if task["execution_status"] in {"succeeded", "failed", "policy_rejected", "cancelled"}:
            return task
        time.sleep(0.1)
    raise TimeoutError(f"task did not reach terminal state: {task_id}")


def main() -> None:
    with tempfile.TemporaryDirectory() as tmpdir:
        db_path = os.path.join(tmpdir, "demo.db")
        port = free_port()
        app = App(db_path)
        server = ThreadingHTTPServer(("127.0.0.1", port), make_handler(app))
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        time.sleep(0.1)

        try:
            fund_subscription = request(
                port,
                "POST",
                "/agent/tasks",
                {
                    "requester": "alice",
                    "requester_type": "user",
                    "requester_signature": "sig-demo-alice",
                    "intent": "subscribe_fund_share",
                    "constraints": {
                        "asset_id": "fund-share-hkpe-alice-001",
                        "fund_id": "HK_PE_FUND_I",
                        "fund_manager": "issuer_A",
                        "lp": "alice",
                        "share_units": 1000,
                        "subscription_amount_hkd": 1000000,
                        "metadata_hash": "hash-fund-subscription-alice",
                    },
                    "authorization_scope": ["subscribe_fund_share"],
                    "risk_preference": "medium",
                    "idempotency_key": "demo-subscribe-fund-share-001",
                },
            )
            fund_subscription = wait_task(port, fund_subscription["task_id"])

            fund_share_asset = request(port, "GET", "/assets/fund-share-hkpe-alice-001")

            portfolio_investment = request(
                port,
                "POST",
                "/agent/tasks",
                {
                    "requester": "issuer_A",
                    "requester_type": "institution",
                    "requester_signature": "sig-demo-gp",
                    "intent": "invest_portfolio_equity",
                    "constraints": {
                        "asset_id": "portfolio-equity-aicomp-001",
                        "fund_id": "HK_PE_FUND_I",
                        "fund_manager": "issuer_A",
                        "portfolio_company": "AI Compute Infrastructure Ltd",
                        "equity_units": 2500,
                        "investment_amount_hkd": 3000000,
                        "metadata_hash": "hash-portfolio-aicomp",
                    },
                    "authorization_scope": ["invest_portfolio_equity"],
                    "risk_preference": "medium",
                    "idempotency_key": "demo-invest-portfolio-equity-001",
                },
            )
            portfolio_investment = wait_task(port, portfolio_investment["task_id"])

            portfolio_asset = request(port, "GET", "/assets/portfolio-equity-aicomp-001")

            compute_revenue = request(
                port,
                "POST",
                "/agent/tasks",
                {
                    "requester": "custodian_A",
                    "requester_type": "institution",
                    "requester_signature": "sig-demo-custodian",
                    "intent": "record_compute_revenue",
                    "constraints": {
                        "asset_id": "compute-token-aicomp-001",
                        "compute_project": "AI Compute Cluster A",
                        "operator": "custodian_A",
                        "beneficiary": "bob",
                        "compute_units": 500,
                        "revenue_amount_hkd": 25000,
                        "revenue_period": "2026-Q2",
                        "metadata_hash": "hash-compute-cluster-a",
                    },
                    "authorization_scope": ["record_compute_revenue"],
                    "risk_preference": "medium",
                    "idempotency_key": "demo-compute-revenue-001",
                },
            )
            compute_revenue = wait_task(port, compute_revenue["task_id"])

            compute_asset = request(port, "GET", "/assets/compute-token-aicomp-001")
            fund_share_audit = request(port, "GET", "/audit/assets/fund-share-hkpe-alice-001")
            portfolio_audit = request(port, "GET", "/audit/assets/portfolio-equity-aicomp-001")
            compute_audit = request(port, "GET", "/audit/assets/compute-token-aicomp-001")
            licenses = request(port, "GET", "/compliance/licenses")
            kyc_aml = request(port, "GET", "/compliance/kyc-aml")
            legal_rights = request(port, "GET", "/legal/rights")
            wallets = request(port, "GET", "/custody/wallets")
            signatures = request(port, "GET", "/custody/signatures")
            oracle = request(port, "GET", "/oracle/attestations")

            result = {
                "server": f"http://127.0.0.1:{port}",
                "fund_subscription_task": compact_task(fund_subscription),
                "fund_share_asset": fund_share_asset,
                "portfolio_investment_task": compact_task(portfolio_investment),
                "portfolio_equity_asset": portfolio_asset,
                "compute_revenue_task": compact_task(compute_revenue),
                "compute_power_asset": compute_asset,
                "audit_counts": {
                    "fund_share": {
                        "audit_logs": len(fund_share_audit["audit_logs"]),
                        "tool_calls": len(fund_share_audit["tool_calls"]),
                        "transactions": len(fund_share_audit["transactions"]),
                        "chain_events": len(fund_share_audit["chain_events"]),
                    },
                    "portfolio_equity": {
                        "audit_logs": len(portfolio_audit["audit_logs"]),
                        "tool_calls": len(portfolio_audit["tool_calls"]),
                        "transactions": len(portfolio_audit["transactions"]),
                        "chain_events": len(portfolio_audit["chain_events"]),
                    },
                    "compute_power": {
                        "audit_logs": len(compute_audit["audit_logs"]),
                        "tool_calls": len(compute_audit["tool_calls"]),
                        "transactions": len(compute_audit["transactions"]),
                        "chain_events": len(compute_audit["chain_events"]),
                    },
                },
                "institutional_controls": {
                    "licensed_institutions": len(licenses["licensed_institutions"]),
                    "kyc_aml_profiles": len(kyc_aml["kyc_aml_profiles"]),
                    "rights_mappings": len(legal_rights["rights_mappings"]),
                    "custody_wallets": len(wallets["wallets"]),
                    "signature_requests": len(signatures["signature_requests"]),
                    "oracle_attestations": len(oracle["oracle_attestations"]),
                },
            }
            print(json.dumps(result, indent=2, sort_keys=True))
        finally:
            server.shutdown()
            server.server_close()


if __name__ == "__main__":
    main()
