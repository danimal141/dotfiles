#!/usr/bin/env python3

import importlib.util
import json
import os
import tempfile
import unittest
from pathlib import Path

SCRIPTS_DIR = Path(__file__).parent.parent / "scripts"


def load_report_module():
    spec = importlib.util.spec_from_file_location(
        "codex_usage_report", SCRIPTS_DIR / "codex-usage-report.py"
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


report = load_report_module()


def write_rollout(path, lines):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(json.dumps(line) for line in lines) + "\n", encoding="utf-8")


def rollout_lines(source, model="gpt-5.6-luna", tokens=None):
    lines = [
        {"type": "session_meta", "payload": {"source": source}},
        {"type": "turn_context", "payload": {"model": model}},
    ]
    if tokens is not None:
        lines.append(
            {
                "type": "event_msg",
                "payload": {"type": "token_count", "info": {"total_token_usage": tokens}},
            }
        )
    return lines


class ClassifySourceTest(unittest.TestCase):
    def test_root_variants(self):
        self.assertEqual(report.classify_source("cli"), "root (cli)")
        self.assertEqual(report.classify_source("exec"), "root (exec)")

    def test_subagent_variants(self):
        self.assertEqual(report.classify_source({"subagent": "review"}), "subagent (review)")
        self.assertEqual(
            report.classify_source({"subagent": {"other": "guardian"}}),
            "subagent (guardian)",
        )
        self.assertEqual(
            report.classify_source({"subagent": {"thread_spawn": {"agent_role": "architect"}}}),
            "subagent (architect)",
        )

    def test_unknown_shapes(self):
        self.assertEqual(report.classify_source(None), "unknown")
        self.assertEqual(report.classify_source({"subagent": {"thread_spawn": {}}}), "subagent (unknown)")
        self.assertEqual(report.classify_source(42), "unknown")


class ParseRolloutTest(unittest.TestCase):
    def parse(self, lines, raw_lines=None):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "rollout-test.jsonl"
            if raw_lines is None:
                write_rollout(path, lines)
            else:
                path.write_text("\n".join(raw_lines) + "\n", encoding="utf-8")
            return report.parse_rollout(path)

    def test_parses_source_model_and_last_token_count(self):
        lines = rollout_lines("cli", tokens={"input_tokens": 10, "total_tokens": 10})
        lines.append(
            {
                "type": "event_msg",
                "payload": {
                    "type": "token_count",
                    "info": {"total_token_usage": {"input_tokens": 99, "total_tokens": 120}},
                },
            }
        )
        record = self.parse(lines)

        self.assertEqual(record["source"], "root (cli)")
        self.assertEqual(record["model"], "gpt-5.6-luna")
        self.assertEqual(record["tokens"]["total_tokens"], 120)

    def test_counts_file_changes_and_exec_calls(self):
        lines = rollout_lines("cli")
        lines.append(
            {
                "type": "event_msg",
                "payload": {"type": "item_completed", "item": {"details": {"type": "FileChange"}}},
            }
        )
        lines.append(
            {
                "type": "event_msg",
                "payload": {"type": "item_completed", "item": {"type": "FileChange"}},
            }
        )
        lines.append(
            {"type": "response_item", "payload": {"type": "custom_tool_call", "name": "exec"}}
        )
        record = self.parse(lines)

        self.assertEqual(record["file_changes"], 2)
        self.assertEqual(record["exec_calls"], 1)

    def test_skips_broken_lines(self):
        raw = [
            json.dumps({"type": "session_meta", "payload": {"source": "cli"}}),
            "{broken json",
            json.dumps({"type": "turn_context", "payload": {"model": "gpt-5.6-sol"}}),
        ]
        record = self.parse(None, raw_lines=raw)

        self.assertEqual(record["source"], "root (cli)")
        self.assertEqual(record["model"], "gpt-5.6-sol")


class CollectAggregateTest(unittest.TestCase):
    def test_collect_honors_cutoff_and_aggregate_splits_root(self):
        with tempfile.TemporaryDirectory() as tmp:
            sessions = Path(tmp)
            recent = sessions / "2026" / "08" / "17" / "rollout-recent.jsonl"
            lines = rollout_lines("cli", tokens={"input_tokens": 5, "total_tokens": 5})
            lines.append(
                {
                    "type": "event_msg",
                    "payload": {"type": "item_completed", "item": {"details": {"type": "FileChange"}}},
                }
            )
            write_rollout(recent, lines)

            sub = sessions / "2026" / "08" / "17" / "rollout-sub.jsonl"
            write_rollout(
                sub,
                rollout_lines(
                    {"subagent": {"thread_spawn": {"agent_role": "architect"}}},
                    model="gpt-5.6-sol",
                    tokens={"input_tokens": 7, "total_tokens": 7},
                ),
            )

            old = sessions / "2026" / "07" / "01" / "rollout-old.jsonl"
            write_rollout(old, rollout_lines("cli"))
            past = 100 * 86400
            os.utime(old, (old.stat().st_atime - past, old.stat().st_mtime - past))

            records = report.collect(sessions, days=30)
            summary = report.aggregate(records)

        self.assertEqual(summary["sessions_by_source"]["root (cli)"], 1)
        self.assertEqual(summary["sessions_by_source"]["subagent (architect)"], 1)
        self.assertNotIn("rollout-old", summary["sessions_by_source"])
        self.assertEqual(
            summary["tokens_by_model"]["gpt-5.6-sol / subagent (architect)"]["input_tokens"], 7
        )
        self.assertEqual(summary["root_file_changes"], 1)

    def test_format_report_smoke(self):
        summary = report.aggregate(
            [
                {
                    "source": "root (cli)",
                    "model": "gpt-5.6-luna",
                    "tokens": {"input_tokens": 5, "total_tokens": 5},
                    "file_changes": 2,
                    "exec_calls": 3,
                }
            ]
        )
        text = report.format_report(summary, days=30)

        self.assertIn("gpt-5.6-luna", text)
        self.assertIn("file changes: 2", text)


if __name__ == "__main__":
    unittest.main()
