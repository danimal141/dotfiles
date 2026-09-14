#!/usr/bin/env python3
"""PostToolUse hook: .md 編集で「今回追加したテキスト」に textlint
(preset-ai-words-ja) を掛け、AI 文章に頻出する語句があれば exit 2 で弾く。

posttooluse-japanese-lint.py (natural-japanese の lint) が finding を「疑い」
として additionalContext で返すのに対し、こちらは検出 = ブロック。
指摘内容を stderr に出し、モデルに言い換えてから書き直させる。

設計:
  * 弾く対象はこの編集で追加された行のみ (Write: content / Edit: new_string /
    MultiEdit: edits[].new_string / Codex apply_patch: patch の `+` 行)。
    既存文書に残る未修正語で無関係な編集まで弾かない (外科的変更の原則と整合)
  * ただし lint 自体は編集後のファイル全体に掛け、結果を追加行に絞る。
    追加行だけを textlint に渡すと Markdown 構造 (開いたままのコードフェンス等)
    が失われ、コード例の中の語を散文として誤検出するため
  * ファイル単位の判定 (日本語を一定量含む .md、エージェント設定ファイル除外)
    は posttooluse-japanese-lint.py の is_target を共有する
  * textlint 本体と preset は dotfiles repo の package.json で pin し、
    repo 直下の node_modules/.bin/textlint を呼ぶ
    (install は nix/home/programs/node-deps.nix の activation hook)
  * 設定は tools/textlint/.textlintrc.json
  * Codex とは tools/codex/hooks/ の symlink で共有 (hooks.json の PostToolUse
    ^apply_patch$)。Codex も sync hook の exit 2 + stderr を Blocked として扱う
  * fail-open。node / textlint が無い、タイムアウト、textlint 自体の異常終了は
    黙って exit 0 (編集そのものを止めない)

無効化: 環境変数 TEXTLINT_AI_WORDS_HOOK=0
手動実行: cd <dotfiles> && npx textlint --config tools/textlint/.textlintrc.json <file>
"""

from __future__ import annotations

import importlib.util
import json
import os
import re
import subprocess
import sys
from pathlib import Path

MAX_FILES = 3
TEXTLINT_TIMEOUT_SEC = 30

HOOK_DIR = Path(__file__).resolve().parent
DOTFILES_DIR = HOOK_DIR.parents[2]  # hooks/ -> claude/ -> tools/ -> dotfiles
TEXTLINT_BIN = DOTFILES_DIR / "node_modules/.bin/textlint"
TEXTLINTRC = DOTFILES_DIR / "tools/textlint/.textlintrc.json"
EXTRA_PATH = (
    str(Path.home() / ".local/share/mise/shims"),
    "/run/current-system/sw/bin",
    "/opt/homebrew/bin",
    "/usr/local/bin",
)
JAPANESE_RE = re.compile(r"[぀-ヿ一-鿿]")
PATCH_HEADER_RE = re.compile(r"^\*\*\* (Add|Update|Delete) File: (.+?)\s*$")
PATCH_MOVE_RE = re.compile(r"^\*\*\* Move to: (.+?)\s*$")


def load_shared():
    """posttooluse-japanese-lint.py の is_target を借りる。"""
    spec = importlib.util.spec_from_file_location(
        "posttooluse_japanese_lint", HOOK_DIR / "posttooluse-japanese-lint.py"
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def resolve(raw: str, cwd: Path) -> Path:
    p = Path(os.path.expanduser(raw))
    if not p.is_absolute():
        p = cwd / p
    return p.resolve()


def added_text_from_patch(text: str) -> dict[str, str]:
    """Codex apply_patch の本文から、ファイルごとの追加行 (`+` 行) を集める。"""
    out: dict[str, list[str]] = {}
    current: str | None = None
    for line in text.splitlines():
        m = PATCH_HEADER_RE.match(line)
        if m:
            current = m.group(2) if m.group(1) != "Delete" else None
            if current is not None:
                out.setdefault(current, [])
            continue
        mv = PATCH_MOVE_RE.match(line)
        if mv and current is not None:
            # Update File + Move to: 追加行は移動先のファイルに属する
            moved = out.pop(current, [])
            current = mv.group(1)
            out.setdefault(current, []).extend(moved)
            continue
        if line.startswith("*** "):
            continue
        if current is not None and line.startswith("+"):
            out[current].append(line[1:])
    return {k: "\n".join(v) for k, v in out.items() if v}


def collect_added_text(payload: dict) -> dict[Path, str]:
    """{編集されたファイル: この編集で追加された本文}。"""
    cwd = Path(payload.get("cwd") or os.getcwd())
    tool_input = payload.get("tool_input")
    result: dict[Path, str] = {}

    if isinstance(tool_input, dict) and isinstance(tool_input.get("file_path"), str):
        chunks: list[str] = []
        for key in ("content", "new_string"):
            if isinstance(tool_input.get(key), str):
                chunks.append(tool_input[key])
        for edit in tool_input.get("edits") or []:
            if isinstance(edit, dict) and isinstance(edit.get("new_string"), str):
                chunks.append(edit["new_string"])
        if chunks:
            result[resolve(tool_input["file_path"], cwd)] = "\n".join(chunks)

    # Codex apply_patch: tool_input は patch 文字列、または patch を含む dict
    patch: str | None = None
    if isinstance(tool_input, str) and "*** Begin Patch" in tool_input:
        patch = tool_input
    elif isinstance(tool_input, dict) and payload.get("tool_name") == "apply_patch":
        patch = next(
            (v for v in tool_input.values() if isinstance(v, str) and "*** Begin Patch" in v),
            None,
        )
    if patch:
        for raw, text in added_text_from_patch(patch).items():
            p = resolve(raw, cwd)
            result[p] = (result[p] + "\n" + text) if p in result else text
    return result


def run_textlint(path: Path, added: str) -> list[str] | None:
    """編集後のファイル全体を lint し、追加行に当たる検出だけ返す。異常は None。"""
    try:
        proc = subprocess.run(
            [str(TEXTLINT_BIN), "--config", str(TEXTLINTRC), "--format", "json", str(path)],
            capture_output=True,
            text=True,
            timeout=TEXTLINT_TIMEOUT_SEC,
            cwd=str(DOTFILES_DIR),
            check=False,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    # lint error ありは 1、無しは 0。それ以外 (設定不備等) は fail-open
    if proc.returncode not in (0, 1):
        return None
    try:
        results = json.loads(proc.stdout or "[]")
        file_lines = path.read_text(encoding="utf-8", errors="ignore").splitlines()
    except (json.JSONDecodeError, OSError):
        return None
    added_lines = {ln.strip() for ln in added.splitlines() if ln.strip()}
    findings: list[str] = []
    for r in results if isinstance(results, list) else []:
        for m in r.get("messages") or []:
            line, msg = m.get("line"), m.get("message")
            if not isinstance(line, int) or not isinstance(msg, str):
                continue
            if not (1 <= line <= len(file_lines)) or file_lines[line - 1].strip() not in added_lines:
                continue
            entry = f"L{line}: {msg}"
            if entry not in findings:
                findings.append(entry)
    return findings


def main() -> int:
    if os.environ.get("TEXTLINT_AI_WORDS_HOOK", "1") == "0":
        return 0
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, OSError):
        return 0
    if not isinstance(payload, dict):
        return 0

    shared = load_shared()
    targets = [
        (p, text)
        for p, text in collect_added_text(payload).items()
        if JAPANESE_RE.search(text) and shared.is_target(p)
    ][:MAX_FILES]
    if not targets:
        return 0
    if not TEXTLINT_BIN.is_file() or not TEXTLINTRC.is_file():
        return 0
    os.environ["PATH"] = os.pathsep.join([*EXTRA_PATH, os.environ.get("PATH", "")])

    reports: list[str] = []
    for p, text in targets:
        findings = run_textlint(p, text)
        if findings:
            reports.append(f"{p}:\n" + "\n".join(f"  - {f}" for f in findings))
    if not reports:
        return 0

    sys.stderr.write(
        "[textlint preset-ai-words-ja] 今回追加した本文に AI 文章で多用される語句がある。"
        "該当箇所を文脈に合う具体的な表現に言い換えて書き直すこと "
        "(検出語を機械的に同義語へ置換しない)。\n" + "\n".join(reports) + "\n"
    )
    return 2


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception:  # fail-open: hook の不具合で編集を止めない
        sys.exit(0)
