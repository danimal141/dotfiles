#!/usr/bin/env python3
"""PostToolUse hook: .md 編集後に natural-japanese の lint.py を走らせ、
finding を additionalContext としてモデルへ返す。

Claude Code (Write / Edit / MultiEdit: tool_input.file_path) と
Codex (apply_patch: patch 本文の `*** Add|Update File:` 行) の両方の
payload を受け付ける。hooks.json / settings.json から同じスクリプトを呼ぶ。

設計:
  * 検出は機械、判断はモデル。finding を「直せ」ではなく「疑い」として渡す
  * fail-open。uv / lint.py / 依存が無い、タイムアウト、JSON 破損はすべて
    黙って exit 0 (編集そのものを止めない)
  * 対象は日本語を一定量含む .md のみ。エージェント設定ファイル
    (CLAUDE.md / AGENTS.md / SKILL.md、.claude/ .agents/ .codex/ 配下) は除外
  * additionalContext は Codex の既定上限 (約 2,500 token) に収まるよう
    件数と文字数を絞る

無効化: 環境変数 JAPANESE_LINT_HOOK=0
"""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

MAX_FILES = 3
MAX_FINDINGS_PER_FILE = 12
MAX_CONTEXT_CHARS = 3500
MIN_JAPANESE_CHARS = 80
LINT_TIMEOUT_SEC = 25

EXCLUDED_DIR_PARTS = {".claude", ".agents", ".codex", ".git", "node_modules", "apm_modules"}
EXCLUDED_BASENAMES = {"CLAUDE.md", "AGENTS.md", "SKILL.md"}
JAPANESE_RE = re.compile(r"[぀-ヿ一-鿿]")
PATCH_FILE_RE = re.compile(r"^\*\*\* (?:Add|Update) File: (.+?)\s*$", re.MULTILINE)

LINT_CANDIDATES = (
    Path.home() / ".claude/skills/natural-japanese/scripts/lint.py",
    Path.home() / ".agents/skills/natural-japanese/scripts/lint.py",
)
EXTRA_PATH = (
    "/run/current-system/sw/bin",
    str(Path.home() / ".local/bin"),
    "/opt/homebrew/bin",
    "/usr/local/bin",
)


def collect_paths(payload: dict) -> list[Path]:
    cwd = Path(payload.get("cwd") or os.getcwd())
    tool_input = payload.get("tool_input")
    raw: list[str] = []

    if isinstance(tool_input, dict):
        fp = tool_input.get("file_path")
        if isinstance(fp, str):
            raw.append(fp)

    # Codex apply_patch: tool_input は patch 文字列、または patch を含む dict
    if payload.get("tool_name") == "apply_patch" or (
        isinstance(tool_input, str) and "*** Begin Patch" in tool_input
    ):
        text = tool_input if isinstance(tool_input, str) else json.dumps(tool_input, ensure_ascii=False)
        # json.dumps で改行が \n にエスケープされるので戻す
        text = text.replace("\\n", "\n")
        raw.extend(PATCH_FILE_RE.findall(text))

    paths: list[Path] = []
    for r in raw:
        p = Path(os.path.expanduser(r))
        if not p.is_absolute():
            p = cwd / p
        p = p.resolve()
        if p not in paths:
            paths.append(p)
    return paths


def is_target(path: Path) -> bool:
    if path.suffix.lower() != ".md" or not path.is_file():
        return False
    if path.name in EXCLUDED_BASENAMES:
        return False
    if EXCLUDED_DIR_PARTS.intersection(path.parts):
        return False
    try:
        text = path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return False
    return len(JAPANESE_RE.findall(text)) >= MIN_JAPANESE_CHARS


def find_lint() -> Path | None:
    override = os.environ.get("JAPANESE_LINT_SCRIPT")
    if override and Path(override).is_file():
        return Path(override)
    for c in LINT_CANDIDATES:
        if c.is_file():
            return c
    return None


def run_lint(uv: str, lint: Path, target: Path) -> dict | None:
    try:
        proc = subprocess.run(
            [uv, "run", "--quiet", str(lint), "--json", str(target)],
            capture_output=True,
            text=True,
            timeout=LINT_TIMEOUT_SEC,
            cwd=str(lint.parent),
            check=False,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    if proc.returncode != 0 or not proc.stdout.strip():
        return None
    try:
        return json.loads(proc.stdout)
    except json.JSONDecodeError:
        return None


SEVERITY_ORDER = {"error": 0, "warn": 1, "info": 2}


def format_report(target: Path, result: dict) -> str | None:
    findings = result.get("findings") or []
    if not findings:
        return None
    stats = result.get("stats") or {}
    by_cat = stats.get("by_category") or {}
    cat_summary = ", ".join(f"{k} {v}" for k, v in sorted(by_cat.items(), key=lambda kv: -kv[1]))

    findings = sorted(
        findings,
        key=lambda f: (SEVERITY_ORDER.get(f.get("severity"), 9), f.get("line") or 0),
    )
    lines = [f"[natural-japanese lint] {target}: {len(findings)} findings ({cat_summary})"]
    for f in findings[:MAX_FINDINGS_PER_FILE]:
        excerpt = (f.get("excerpt") or "").replace("\n", " ")
        if len(excerpt) > 40:
            excerpt = excerpt[:40] + "…"
        lines.append(f"- L{f.get('line')} {f.get('category')}: {f.get('detail')} 「{excerpt}」")
    if len(findings) > MAX_FINDINGS_PER_FILE:
        lines.append(f"- … 他 {len(findings) - MAX_FINDINGS_PER_FILE} 件 (全件は uv run <lint.py> --json で確認)")
    return "\n".join(lines)


def main() -> int:
    if os.environ.get("JAPANESE_LINT_HOOK", "1") == "0":
        return 0
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, OSError):
        return 0
    if not isinstance(payload, dict):
        return 0

    targets = [p for p in collect_paths(payload) if is_target(p)][:MAX_FILES]
    if not targets:
        return 0

    lint = find_lint()
    if lint is None:
        return 0
    os.environ["PATH"] = os.pathsep.join([*EXTRA_PATH, os.environ.get("PATH", "")])
    uv = shutil.which("uv")
    if uv is None:
        return 0

    reports = []
    for t in targets:
        result = run_lint(uv, lint, t)
        if result is None:
            continue
        report = format_report(t, result)
        if report:
            reports.append(report)
    if not reports:
        return 0

    footer = (
        "finding は疑いの提示であり修正命令ではない。一件ずつ文脈で「直す / 残す (理由)」を判断し、"
        "黙って無視しない。直した後に新しい finding が出ていないか確認する。"
    )
    context = "\n\n".join(reports)
    if len(context) > MAX_CONTEXT_CHARS:
        context = context[:MAX_CONTEXT_CHARS] + "\n… (省略)"
    context = context + "\n\n" + footer

    json.dump(
        {"hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": context}},
        sys.stdout,
        ensure_ascii=False,
    )
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception:  # fail-open: hook の不具合で編集を止めない
        sys.exit(0)
