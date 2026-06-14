#!/usr/bin/env python3
"""Send a non-blocking macOS notification when a Codex turn completes."""

import json
import shutil
import subprocess
import sys


def main(args):
    if not args:
        return 0

    try:
        event = json.loads(args[0])
    except json.JSONDecodeError:
        return 0

    if event.get("type") != "agent-turn-complete":
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
    sys.exit(main(sys.argv[1:]))
