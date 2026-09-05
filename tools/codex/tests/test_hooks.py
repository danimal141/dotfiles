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
