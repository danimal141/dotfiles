#!/usr/bin/env python3
"""Send a macOS notification for a Codex Stop hook event."""

import json
import shutil
import subprocess
import sys


def main():
    try:
        event = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return 0

    if not isinstance(event, dict):
        return 0

    if event.get("hook_event_name") != "Stop":
        return 0

    if not all(
        isinstance(event.get(field), str) and event[field]
        for field in ("session_id", "turn_id")
    ):
        return 0

    notifier = shutil.which("terminal-notifier")
    if not notifier:
        return 0

    try:
        subprocess.run(
            [
                notifier,
                "-sender",
                "com.apple.Terminal",
                "-title",
                "Codex",
                "-message",
                "タスク完了です",
            ],
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except OSError:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
