#!/usr/bin/env python3
"""posttooluse-textlint-ai-words.py の振る舞いテスト (Claude payload)。

実行: python3 -m unittest discover tools/claude/tests
textlint 本体は repo 直下の node_modules に依存する (setup.sh の npm ci)。
無い環境では検出系のテストを skip する。
"""

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
HOOK = REPO / "tools/claude/hooks/posttooluse-textlint-ai-words.py"
TEXTLINT_BIN = REPO / "node_modules/.bin/textlint"

FILLER = "この文書は検証用の日本語文章で、ある程度の長さを持たせるために同じ説明を繰り返している。" * 3
NG_TEXT = "# 検証\n\n" + FILLER + "\n\nこの設計は核心が弱い。注入経路を焼き直して検証したい。\n"
OK_TEXT = "# 検証\n\n" + FILLER + "\n\nこの設計は基礎が弱い。対策の効果を詳しく検証したい。\n"


def run_hook(payload, env=None):
    return subprocess.run(
        [sys.executable, str(HOOK)],
        input=json.dumps(payload, ensure_ascii=False),
        text=True,
        capture_output=True,
        check=False,
        env=env,
    )


@unittest.skipUnless(TEXTLINT_BIN.is_file(), "textlint が node_modules に無い (npm ci 未実行)")
class TextlintAiWordsHookTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def write(self, name, text):
        p = self.dir / name
        p.write_text(text, encoding="utf-8")
        return p

    def payload(self, path):
        # Write は content (= 今回追加した本文) を検査する
        return {
            "tool_name": "Write",
            "tool_input": {"file_path": str(path), "content": path.read_text(encoding="utf-8")},
            "cwd": str(self.dir),
        }

    def test_blocks_when_ai_words_found(self):
        result = run_hook(self.payload(self.write("doc.md", NG_TEXT)))

        self.assertEqual(result.returncode, 2)
        self.assertIn("核心", result.stderr)
        self.assertIn("経路", result.stderr)

    def test_passes_clean_document(self):
        result = run_hook(self.payload(self.write("doc.md", OK_TEXT)))

        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stderr, "")

    def test_edit_checks_only_added_text(self):
        # 既存文書に未修正の検出語が残っていても、今回追加した本文が綺麗なら通す
        doc = self.write("doc.md", NG_TEXT)
        payload = {
            "tool_name": "Edit",
            "tool_input": {"file_path": str(doc), "old_string": "x", "new_string": "基礎を固める。"},
            "cwd": str(self.dir),
        }

        self.assertEqual(run_hook(payload).returncode, 0)

    def test_edit_blocks_added_ai_word(self):
        doc = self.write("doc.md", OK_TEXT + "\n核心を固める。\n")
        payload = {
            "tool_name": "Edit",
            "tool_input": {"file_path": str(doc), "old_string": "x", "new_string": "核心を固める。"},
            "cwd": str(self.dir),
        }
        result = run_hook(payload)

        self.assertEqual(result.returncode, 2)
        self.assertIn("核心", result.stderr)

    def test_added_line_inside_code_fence_is_not_prose(self):
        # 開いたままのコードフェンスに追加した行は、全文で見ればコードなので弾かない
        doc = self.write("doc.md", OK_TEXT + "\n```sh\n# 核心を作る\n```\n")
        payload = {
            "tool_name": "Edit",
            "tool_input": {"file_path": str(doc), "old_string": "x", "new_string": "# 核心を作る"},
            "cwd": str(self.dir),
        }

        self.assertEqual(run_hook(payload).returncode, 0)

    def test_report_points_at_real_line_numbers(self):
        doc = self.write("doc.md", OK_TEXT + "\n核心を固める。\n")
        payload = {
            "tool_name": "Edit",
            "tool_input": {"file_path": str(doc), "old_string": "x", "new_string": "核心を固める。"},
            "cwd": str(self.dir),
        }
        result = run_hook(payload)

        self.assertEqual(result.returncode, 2)
        self.assertIn(f"L{len(doc.read_text().splitlines())}:", result.stderr)

    def test_multiedit_blocks_added_ai_word(self):
        doc = self.write("doc.md", OK_TEXT + "\n問題ない。\n核心に触れる。\n")
        payload = {
            "tool_name": "MultiEdit",
            "tool_input": {
                "file_path": str(doc),
                "edits": [
                    {"old_string": "a", "new_string": "問題ない。"},
                    {"old_string": "b", "new_string": "核心に触れる。"},
                ],
            },
            "cwd": str(self.dir),
        }

        self.assertEqual(run_hook(payload).returncode, 2)

    def test_ignores_non_markdown(self):
        result = run_hook(self.payload(self.write("doc.txt", NG_TEXT)))

        self.assertEqual(result.returncode, 0)

    def test_ignores_agent_config_file(self):
        result = run_hook(self.payload(self.write("CLAUDE.md", NG_TEXT)))

        self.assertEqual(result.returncode, 0)

    def test_disabled_by_env(self):
        env = {**os.environ, "TEXTLINT_AI_WORDS_HOOK": "0"}
        result = run_hook(self.payload(self.write("doc.md", NG_TEXT)), env=env)

        self.assertEqual(result.returncode, 0)


class FailOpenTest(unittest.TestCase):
    def test_broken_payload_exits_zero(self):
        result = subprocess.run(
            [sys.executable, str(HOOK)], input="not json", text=True, capture_output=True, check=False
        )

        self.assertEqual(result.returncode, 0)


if __name__ == "__main__":
    unittest.main()
