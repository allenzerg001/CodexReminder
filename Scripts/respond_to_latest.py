#!/usr/bin/env python3
"""Write a CodexReminder choice response for the newest pending hook request."""

import argparse
import json
import time
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("choice", choices=["allow", "deny", "approve", "reject"])
    parser.add_argument("--tool", default=None)
    parser.add_argument("--timeout", type=float, default=30)
    args = parser.parse_args()

    base_dir = Path.home() / ".codexreminder"
    notify_dir = base_dir / "notifications"
    deadline = time.monotonic() + args.timeout

    while time.monotonic() < deadline:
        request = latest_request(notify_dir, args.tool)
        if request is not None:
            response_path = Path(request["responsePath"])
            response_path.parent.mkdir(parents=True, exist_ok=True)
            response_path.write_text(
                json.dumps(
                    {
                        "toolId": request.get("id", ""),
                        "tool": request.get("tool", ""),
                        "choiceId": args.choice,
                        "value": args.choice,
                        "timestamp": time.time(),
                    },
                    separators=(",", ":"),
                ),
                encoding="utf-8",
            )
            print(response_path)
            return 0
        time.sleep(0.2)

    print("No pending CodexReminder request found", flush=True)
    return 1


def latest_request(notify_dir: Path, tool_filter: str | None) -> dict | None:
    if not notify_dir.exists():
        return None

    candidates = sorted(notify_dir.glob("*.json"), key=lambda path: path.stat().st_mtime, reverse=True)
    for path in candidates:
        try:
            request = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            continue

        if "responsePath" not in request:
            continue

        if tool_filter and tool_filter.lower() not in str(request.get("tool", "")).lower():
            continue

        return request

    return None


if __name__ == "__main__":
    raise SystemExit(main())
