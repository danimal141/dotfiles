#!/usr/bin/env python3

import importlib.util
import json
import tempfile
import unittest
from pathlib import Path
from unittest import mock


HOOKS_DIR = Path(__file__).parent.parent / "hooks"
CLAUDE_HOOKS_DIR = Path(__file__).parent.parent.parent / "claude" / "hooks"
CODEX_SCRIPTS_DIR = Path(__file__).parent.parent / "scripts"


def load_module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def load_codex_namer():
    return load_module("codex_session_namer", HOOKS_DIR / "session-namer.py")


def load_claude_namer():
    return load_module("claude_session_namer", CLAUDE_HOOKS_DIR / "session-namer.py")


def load_codex_renamer():
    return load_module("codex_session_renamer", CODEX_SCRIPTS_DIR / "session-renamer.py")


def claude_user(text, sidechain=False):
    return json.dumps(
        {
            "type": "user",
            "isSidechain": sidechain,
            "message": {"role": "user", "content": text},
        },
        ensure_ascii=False,
    )


def claude_assistant(text):
    return json.dumps(
        {
            "type": "assistant",
            "isSidechain": False,
            "message": {
                "role": "assistant",
                "content": [{"type": "text", "text": text}],
            },
        },
        ensure_ascii=False,
    )


def codex_event(kind, text):
    return json.dumps(
        {"type": "event_msg", "payload": {"type": kind, "message": text}},
        ensure_ascii=False,
    )


class SanitizeTitleTest(unittest.TestCase):
    def setUp(self):
        self.modules = [load_claude_namer(), load_codex_namer()]

    def test_strips_quotes_and_newlines(self):
        for m in self.modules:
            self.assertEqual(
                m.sanitize_title('「herdr 設定の調査」\n補足説明'),
                "herdr 設定の調査",
            )

    def test_truncates_long_title(self):
        for m in self.modules:
            self.assertEqual(len(m.sanitize_title("あ" * 100)), m.MAX_TITLE_LEN)

    def test_empty_input_returns_empty(self):
        for m in self.modules:
            self.assertEqual(m.sanitize_title("  \n "), "")

    def test_collapses_inner_whitespace(self):
        for m in self.modules:
            self.assertEqual(m.sanitize_title("a \t b"), "a b")


class GenerateTitleTest(unittest.TestCase):
    def setUp(self):
        self.modules = [load_claude_namer(), load_codex_namer()]

    def test_returns_sanitized_output(self):
        for m in self.modules:
            completed = mock.Mock(returncode=0, stdout="「テストタイトル」\n")
            with mock.patch.object(m.subprocess, "run", return_value=completed) as run:
                self.assertEqual(m.generate_title("context"), "テストタイトル")
            env = run.call_args.kwargs["env"]
            self.assertEqual(env["CLAUDE_SESSION_NAMER"], "1")
            self.assertEqual(env["CODEX_SESSION_NAMER"], "1")

    def test_returns_empty_on_failure(self):
        for m in self.modules:
            completed = mock.Mock(returncode=1, stdout="x")
            with mock.patch.object(m.subprocess, "run", return_value=completed):
                self.assertEqual(m.generate_title("context"), "")
            with mock.patch.object(m.subprocess, "run", side_effect=OSError):
                self.assertEqual(m.generate_title("context"), "")


class ClaudeTranscriptTest(unittest.TestCase):
    def setUp(self):
        self.namer = load_claude_namer()

    def test_context_requires_two_user_messages(self):
        lines = [claude_user("最初の依頼だけ")]
        self.assertIsNone(self.namer.build_context(lines))

    def test_context_includes_first_prompt(self):
        lines = [
            claude_user("herdr の設定を調査して"),
            claude_assistant("調査しました"),
            claude_user("では修正して"),
        ]
        context = self.namer.build_context(lines)
        self.assertIn("herdr の設定を調査して", context)
        self.assertIn("では修正して", context)

    def test_context_ignores_sidechain_and_tool_results(self):
        tool_result = json.dumps(
            {
                "type": "user",
                "isSidechain": False,
                "message": {
                    "role": "user",
                    "content": [{"type": "tool_result", "content": "ok"}],
                },
            }
        )
        lines = [
            claude_user("本編1"),
            claude_user("サブ", sidechain=True),
            tool_result,
        ]
        self.assertIsNone(self.namer.build_context(lines))

    def test_title_records_contain_agent_name_and_ai_title(self):
        block = self.namer.title_records("sid", "タイトル")
        lines = block.strip().split("\n")
        self.assertEqual(len(lines), 2)
        self.assertEqual(
            json.loads(lines[0]),
            {"type": "agent-name", "agentName": "タイトル", "sessionId": "sid"},
        )
        self.assertEqual(
            json.loads(lines[1]),
            {"type": "ai-title", "aiTitle": "タイトル", "sessionId": "sid"},
        )

    def test_has_agent_name(self):
        named = [claude_user("x"), '{"type":"agent-name","agentName":"n","sessionId":"s"}']
        self.assertTrue(self.namer.has_agent_name(named))
        self.assertFalse(self.namer.has_agent_name([claude_user("x")]))

    def test_context_is_truncated(self):
        lines = [claude_user("あ" * 10000), claude_user("い" * 10000)]
        context = self.namer.build_context(lines)
        self.assertLessEqual(len(context), self.namer.MAX_CONTEXT_CHARS + 100)


class CodexRolloutTest(unittest.TestCase):
    def setUp(self):
        self.namer = load_codex_namer()

    def test_context_requires_two_user_messages(self):
        lines = [
            codex_event("user_message", "最初の依頼"),
            codex_event("agent_message", "回答"),
        ]
        self.assertIsNone(self.namer.build_context(lines))

    def test_context_includes_messages(self):
        lines = [
            codex_event("user_message", "codex の設定を見て"),
            codex_event("agent_message", "確認しました"),
            codex_event("user_message", "では直して"),
        ]
        context = self.namer.build_context(lines)
        self.assertIn("codex の設定を見て", context)
        self.assertIn("では直して", context)

    def test_find_state_db_picks_highest_version(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            (home / "state_5.sqlite").touch()
            (home / "state_12.sqlite").touch()
            self.assertEqual(
                self.namer.find_state_db(home), home / "state_12.sqlite"
            )

    def test_find_state_db_none_when_missing(self):
        with tempfile.TemporaryDirectory() as tmp:
            self.assertIsNone(self.namer.find_state_db(Path(tmp)))


class CodexRenamerTest(unittest.TestCase):
    def setUp(self):
        self.renamer = load_codex_renamer()

    def test_japanese_first_message_is_rename_target(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            rollout = root / "rollout.jsonl"
            rollout.write_text(
                "\n".join(
                    [
                        codex_event("user_message", "未コミット差分をレビューして"),
                        codex_event("agent_message", "確認します"),
                        codex_event("user_message", "変更対応して"),
                    ]
                ),
                encoding="utf-8",
            )
            db_path = root / "state_1.sqlite"
            conn = self.renamer.sqlite3.connect(db_path)
            conn.execute(
                "CREATE TABLE threads (id TEXT, rollout_path TEXT, title TEXT, "
                "first_user_message TEXT, archived INTEGER, source TEXT)"
            )
            first_message = "未コミット差分をレビューして"
            conn.execute(
                "INSERT INTO threads VALUES (?, ?, ?, ?, 0, 'cli')",
                ("thread-id", str(rollout), first_message, first_message),
            )
            conn.commit()
            conn.close()

            targets = self.renamer.fetch_targets(db_path)

        self.assertEqual(len(targets), 1)
        self.assertEqual(targets[0][0], "thread-id")


class ValidSessionIdTest(unittest.TestCase):
    def test_rejects_path_like_ids(self):
        for m in (load_claude_namer(), load_codex_namer()):
            self.assertTrue(m.valid_session_id("2af2d84f-ad06-45f8-8809-73a42b5f6123"))
            for bad in ("", "../x", "a/b", "x" * 200):
                self.assertFalse(m.valid_session_id(bad))


if __name__ == "__main__":
    unittest.main()
