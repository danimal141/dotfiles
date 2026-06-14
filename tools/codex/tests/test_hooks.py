#!/usr/bin/env python3

import importlib.util
import json
import subprocess
import sys
import unittest
from pathlib import Path
from unittest import mock


HOOKS_DIR = Path(__file__).parent.parent / "hooks"


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

    @mock.patch("shutil.which", return_value="/opt/homebrew/bin/terminal-notifier")
    @mock.patch("subprocess.run")
    def test_notifies_on_agent_turn_complete(self, run, _which):
        result = self.notify.main([json.dumps({"type": "agent-turn-complete"})])

        self.assertEqual(result, 0)
        run.assert_called_once()
        self.assertIn("Codex", run.call_args.args[0])
        self.assertIn("タスク完了です", run.call_args.args[0])

    @mock.patch("subprocess.run")
    def test_ignores_unknown_event(self, run):
        result = self.notify.main([json.dumps({"type": "unknown"})])

        self.assertEqual(result, 0)
        run.assert_not_called()

    @mock.patch("shutil.which", return_value="/opt/homebrew/bin/terminal-notifier")
    @mock.patch("subprocess.run", side_effect=OSError)
    def test_ignores_notifier_launch_failure(self, _run, _which):
        result = self.notify.main([json.dumps({"type": "agent-turn-complete"})])

        self.assertEqual(result, 0)


if __name__ == "__main__":
    unittest.main()
