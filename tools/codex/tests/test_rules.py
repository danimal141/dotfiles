#!/usr/bin/env python3

import json
import shutil
import subprocess
import unittest
from pathlib import Path


RULES_FILE = Path(__file__).parent.parent / "rules" / "destructive.rules"


@unittest.skipUnless(shutil.which("codex"), "codex CLI is required")
class DestructiveRulesTest(unittest.TestCase):
    def check(self, *command):
        result = subprocess.run(
            ["codex", "execpolicy", "check", "--rules", RULES_FILE, "--", *command],
            text=True,
            capture_output=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout)

    def test_forbids_git_reset_hard(self):
        result = self.check("git", "reset", "--hard")

        self.assertEqual(result["decision"], "forbidden")

    def test_forbids_recursive_force_remove(self):
        result = self.check("rm", "-rf", "build")

        self.assertEqual(result["decision"], "forbidden")

    def test_prompts_for_recursive_remove_without_force(self):
        result = self.check("rm", "-r", "build")

        self.assertEqual(result["decision"], "prompt")

    def test_prompts_when_force_flag_is_after_push_arguments(self):
        result = self.check("git", "push", "origin", "main", "--force")

        self.assertEqual(result["decision"], "prompt")

    def test_does_not_match_read_only_git_command(self):
        result = self.check("git", "status", "--short")

        self.assertEqual(result["matchedRules"], [])
        self.assertNotIn("decision", result)


if __name__ == "__main__":
    unittest.main()
