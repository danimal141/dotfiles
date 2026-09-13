#!/usr/bin/env python3

import importlib.util
import io
import json
import subprocess
import sys
import unittest
from pathlib import Path
from unittest import mock


HOOKS_DIR = Path(__file__).parent.parent / "hooks"
HOOKS_CONFIG = HOOKS_DIR.parent / "hooks.json"


def load_notify_module():
    spec = importlib.util.spec_from_file_location("codex_notify", HOOKS_DIR / "notify.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class BlockDestructiveCommandsTest(unittest.TestCase):
    def run_hook(self, command, tool_name="Bash", input_field="command"):
        return subprocess.run(
            [sys.executable, HOOKS_DIR / "block-destructive-commands.py"],
            input=json.dumps(
                {"tool_name": tool_name, "tool_input": {input_field: command}}
            ),
            text=True,
            capture_output=True,
            check=False,
        )

    def test_allows_safe_command(self):
        result = self.run_hook("git status --short")

        self.assertEqual(result.returncode, 0)

    def test_blocks_destructive_command(self):
        result = self.run_hook("git reset --hard")

        self.assertEqual(result.returncode, 2)
        self.assertIn("BLOCKED:", result.stderr)

    def test_accepts_internal_cmd_input(self):
        result = self.run_hook(
            "git reset --hard", tool_name="exec_command", input_field="cmd"
        )

        self.assertEqual(result.returncode, 2)


class NotifyTest(unittest.TestCase):
    def setUp(self):
        self.notify = load_notify_module()

    def run_notify(self, event):
        with mock.patch.object(
            self.notify.sys, "stdin", io.StringIO(json.dumps(event))
        ):
            return self.notify.main()

    @mock.patch("shutil.which", return_value="/opt/homebrew/bin/terminal-notifier")
    @mock.patch("subprocess.run")
    def test_notifies_on_stop(self, run, _which):
        result = self.run_notify(
            {"hook_event_name": "Stop", "session_id": "session-1", "turn_id": "turn-1"}
        )

        self.assertEqual(result, 0)
        run.assert_called_once()
        self.assertIn("Codex", run.call_args.args[0])
        self.assertIn("タスク完了です", run.call_args.args[0])

    @mock.patch("subprocess.run")
    def test_ignores_non_stop_event(self, run):
        result = self.run_notify({"hook_event_name": "SessionStart", "source": "startup"})

        self.assertEqual(result, 0)
        run.assert_not_called()

    @mock.patch("subprocess.run")
    def test_ignores_legacy_notify_event(self, run):
        result = self.run_notify(
            {
                "type": "agent-turn-complete",
                "thread-id": "thread-1",
                "turn-id": "turn-1",
            }
        )

        self.assertEqual(result, 0)
        run.assert_not_called()

    @mock.patch("subprocess.run")
    def test_ignores_stop_without_session_or_turn_id(self, run):
        for event in (
            {"hook_event_name": "Stop", "turn_id": "turn-1"},
            {"hook_event_name": "Stop", "session_id": "session-1"},
            {"hook_event_name": "Stop", "session_id": "", "turn_id": "turn-1"},
        ):
            with self.subTest(event=event):
                result = self.run_notify(event)

                self.assertEqual(result, 0)
        run.assert_not_called()

    @mock.patch("shutil.which", return_value="/opt/homebrew/bin/terminal-notifier")
    @mock.patch("subprocess.run", side_effect=OSError)
    def test_ignores_notifier_launch_failure(self, _run, _which):
        result = self.run_notify(
            {"hook_event_name": "Stop", "session_id": "session-1", "turn_id": "turn-1"}
        )

        self.assertEqual(result, 0)


class HookConfigTest(unittest.TestCase):
    def test_completion_notification_is_only_a_stop_hook(self):
        config = json.loads(HOOKS_CONFIG.read_text(encoding="utf-8"))
        hooks = config["hooks"]

        stop_handlers = [handler for group in hooks["Stop"] for handler in group["hooks"]]
        notify_handlers = [
            handler for handler in stop_handlers if handler["command"].endswith("notify.py")
        ]

        self.assertEqual(len(notify_handlers), 1)
        self.assertTrue(notify_handlers[0]["async"])
        self.assertFalse(
            any(
                handler["command"].endswith("notify.py")
                for event_name, groups in hooks.items()
                if event_name != "Stop"
                for group in groups
                for handler in group["hooks"]
            )
        )


if __name__ == "__main__":
    unittest.main()


class JapaneseLintHookTest(unittest.TestCase):
    """posttooluse-japanese-lint.py: 対象判定と Claude / Codex 両 payload の解釈。

    lint 本体 (uv + sudachipy) が無い環境では実行系のテストを skip する。
    """

    HOOK = HOOKS_DIR / "posttooluse-japanese-lint.py"
    LINT = Path.home() / ".claude/skills/natural-japanese/scripts/lint.py"
    PROSE = (
        "# 開発投資の考え方\n\n"
        "重要なのは、開発投資を多角的に捉えることである。この施策は非常に重要であり、"
        "単にコストを削減するだけでなく、本質的な価値を生み出す。さらに、開発者体験を"
        "向上させることができる。また、この問いは開かれている。\n\n"
        "まとめると、包括的なアプローチが鍵となる。要するに、掘り下げることが"
        "不可欠だと言えるだろう。\n"
    )

    def setUp(self):
        import tempfile

        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.prose = self.root / "prose.md"
        self.prose.write_text(self.PROSE, encoding="utf-8")

    def tearDown(self):
        self.tmp.cleanup()

    def run_hook(self, payload):
        return subprocess.run(
            [sys.executable, self.HOOK],
            input=json.dumps(payload, ensure_ascii=False),
            text=True,
            capture_output=True,
            check=False,
        )

    def lint_available(self):
        import shutil

        return self.LINT.is_file() and shutil.which("uv") is not None

    def test_claude_payload_returns_findings(self):
        if not self.lint_available():
            self.skipTest("natural-japanese lint.py or uv not available")
        result = self.run_hook(
            {"tool_name": "Write", "cwd": str(self.root),
             "tool_input": {"file_path": str(self.prose)}}
        )

        self.assertEqual(result.returncode, 0)
        out = json.loads(result.stdout)["hookSpecificOutput"]
        self.assertEqual(out["hookEventName"], "PostToolUse")
        self.assertIn("forbidden_phrase", out["additionalContext"])

    def test_codex_apply_patch_payload_resolves_relative_path(self):
        if not self.lint_available():
            self.skipTest("natural-japanese lint.py or uv not available")
        patch = "*** Begin Patch\n*** Update File: prose.md\n@@\n-a\n+b\n*** End Patch"
        result = self.run_hook(
            {"tool_name": "apply_patch", "cwd": str(self.root), "tool_input": patch}
        )

        self.assertEqual(result.returncode, 0)
        self.assertIn("forbidden_phrase", result.stdout)

    def test_skips_non_markdown_and_agent_config(self):
        code = self.root / "main.py"
        code.write_text(self.PROSE, encoding="utf-8")
        agent_dir = self.root / ".claude"
        agent_dir.mkdir()
        agent_md = agent_dir / "notes.md"
        agent_md.write_text(self.PROSE, encoding="utf-8")
        claude_md = self.root / "CLAUDE.md"
        claude_md.write_text(self.PROSE, encoding="utf-8")

        for path in (code, agent_md, claude_md):
            result = self.run_hook(
                {"tool_name": "Edit", "tool_input": {"file_path": str(path)}}
            )
            self.assertEqual(result.returncode, 0, path)
            self.assertEqual(result.stdout, "", path)

    def test_skips_file_without_japanese(self):
        en = self.root / "readme.md"
        en.write_text("# Title\n\nThis is a very important English document.\n", encoding="utf-8")

        result = self.run_hook({"tool_name": "Write", "tool_input": {"file_path": str(en)}})

        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "")

    def test_fail_open_on_broken_input(self):
        result = subprocess.run(
            [sys.executable, self.HOOK], input="not json", text=True,
            capture_output=True, check=False,
        )

        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "")

    def test_registered_in_hooks_json(self):
        config = json.loads(HOOKS_CONFIG.read_text())
        post = config["hooks"]["PostToolUse"]
        commands = [h["command"] for entry in post for h in entry["hooks"]]

        self.assertTrue(any("posttooluse-japanese-lint.py" in c for c in commands))
        self.assertTrue(any(entry.get("matcher") == "^apply_patch$" for entry in post))
