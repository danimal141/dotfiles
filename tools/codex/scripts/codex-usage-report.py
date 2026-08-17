#!/usr/bin/env python3
"""Codex rollout jsonl からモデル別トークンと委譲状況を集計する.

~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl を期間指定で走査し、
  * source 別セッション数 (root cli / exec / subagent 種別)
  * モデル別トークン (input / cached / output / reasoning)
  * subagent 起動回数 (agent_role 別。architect 相談の頻度が見える)
  * root セッションの直接作業量 (FileChange / exec 回数)
を表示する。Luna root 反転後、Sol の消費が設計相談 (architect / sol profile) に
限定されているかの検証に使う。

依存する内部フォーマット (公式 API 無し):
  * 先頭行 session_meta の payload.source ("cli" / "exec" /
    {"subagent": "review" | {"other": ...} | {"thread_spawn": {"agent_role": ...}}})
  * event_msg / token_count の payload.info.total_token_usage (累積値。最終行を採用)
  * turn_context の payload.model (複数回出る場合は最後を採用)
  * event_msg / item_completed の payload.item.type または
    payload.item.details.type ("FileChange" 等。version により階層が違う)
  * response_item / custom_tool_call の payload.name ("exec")
パースできない行・ファイルは skip する (fail-open)。
"""

import argparse
import json
import time
from collections import defaultdict
from pathlib import Path

TOKEN_FIELDS = (
    "input_tokens",
    "cached_input_tokens",
    "output_tokens",
    "reasoning_output_tokens",
    "total_tokens",
)


def classify_source(source):
    """session_meta.payload.source を表示用ラベルに変換する。root は 2 種のみ"""
    if source in ("cli", "exec"):
        return f"root ({source})"
    if isinstance(source, dict):
        subagent = source.get("subagent")
        if isinstance(subagent, str):
            return f"subagent ({subagent})"
        if isinstance(subagent, dict):
            if "thread_spawn" in subagent:
                role = (subagent["thread_spawn"] or {}).get("agent_role") or "unknown"
                return f"subagent ({role})"
            if "other" in subagent:
                return f"subagent ({subagent['other']})"
    return "unknown"


def is_root(label):
    return label.startswith("root ")


def parse_rollout(path):
    """1 rollout を集計レコードに変換する。読めなければ None (fail-open)"""
    record = {
        "source": "unknown",
        "model": None,
        "tokens": None,
        "file_changes": 0,
        "exec_calls": 0,
    }
    try:
        with open(path, encoding="utf-8") as f:
            for i, line in enumerate(f):
                try:
                    entry = json.loads(line)
                except json.JSONDecodeError:
                    continue
                payload = entry.get("payload")
                if not isinstance(payload, dict):
                    continue
                if i == 0 and entry.get("type") == "session_meta":
                    record["source"] = classify_source(payload.get("source"))
                elif entry.get("type") == "turn_context":
                    record["model"] = payload.get("model") or record["model"]
                elif payload.get("type") == "token_count":
                    usage = (payload.get("info") or {}).get("total_token_usage")
                    if isinstance(usage, dict):
                        record["tokens"] = usage
                elif payload.get("type") == "item_completed":
                    # item.type 直下と item.details.type の両形がある (version 差)
                    item = payload.get("item") or {}
                    item_type = item.get("type") or ((item.get("details") or {}).get("type"))
                    if item_type == "FileChange":
                        record["file_changes"] += 1
                elif payload.get("type") == "custom_tool_call":
                    if payload.get("name") == "exec":
                        record["exec_calls"] += 1
    except OSError:
        return None
    return record


def collect(sessions_dir, days):
    cutoff = time.time() - days * 86400
    records = []
    for path in sorted(Path(sessions_dir).glob("*/*/*/rollout-*.jsonl")):
        try:
            if path.stat().st_mtime < cutoff:
                continue
        except OSError:
            continue
        record = parse_rollout(path)
        if record is not None:
            records.append(record)
    return records


def aggregate(records):
    summary = {
        "sessions_by_source": defaultdict(int),
        "tokens_by_model": defaultdict(lambda: defaultdict(int)),
        "sessions_by_model": defaultdict(int),
        "root_file_changes": 0,
        "root_exec_calls": 0,
    }
    for record in records:
        label = record["source"]
        summary["sessions_by_source"][label] += 1
        model = record["model"] or "unknown"
        if record["tokens"]:
            summary["sessions_by_model"][model] += 1
            for field in TOKEN_FIELDS:
                summary["tokens_by_model"][model][field] += record["tokens"].get(field, 0) or 0
        if is_root(label):
            summary["root_file_changes"] += record["file_changes"]
            summary["root_exec_calls"] += record["exec_calls"]
    return summary


def format_report(summary, days):
    lines = [f"# Codex usage report (last {days} days)", ""]

    lines.append("## Sessions by source")
    for label, count in sorted(summary["sessions_by_source"].items(), key=lambda x: -x[1]):
        lines.append(f"  {label:<28} {count:>5}")
    lines.append("")

    lines.append("## Tokens by model (sessions with usage)")
    header = f"  {'model':<24} {'sess':>5} {'input':>12} {'cached':>12} {'output':>10} {'reasoning':>10}"
    lines.append(header)
    ordered = sorted(
        summary["tokens_by_model"].items(),
        key=lambda x: -x[1]["total_tokens"],
    )
    for model, tokens in ordered:
        lines.append(
            f"  {model:<24} {summary['sessions_by_model'][model]:>5}"
            f" {tokens['input_tokens']:>12,} {tokens['cached_input_tokens']:>12,}"
            f" {tokens['output_tokens']:>10,} {tokens['reasoning_output_tokens']:>10,}"
        )
    lines.append("")

    lines.append("## Root direct work")
    lines.append(f"  file changes: {summary['root_file_changes']}")
    lines.append(f"  exec calls:   {summary['root_exec_calls']}")
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description="Codex のモデル別トークンと委譲状況を集計する")
    parser.add_argument("--days", type=int, default=30, help="集計対象の日数 (default: 30)")
    parser.add_argument(
        "--sessions-dir",
        default=str(Path.home() / ".codex" / "sessions"),
        help="rollout jsonl のルート (default: ~/.codex/sessions)",
    )
    args = parser.parse_args()

    records = collect(args.sessions_dir, args.days)
    print(format_report(aggregate(records), args.days))


if __name__ == "__main__":
    main()
