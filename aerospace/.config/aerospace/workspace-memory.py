#!/usr/bin/env python3
"""Persist application workspaces without recording new windows before routing."""

import argparse
import fcntl
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile


FIELDS = "%{window-id} %{app-bundle-id} %{app-bundle-path} %{app-pid} %{workspace}"


def aerospace(*args):
    return subprocess.check_output(["aerospace", *args], text=True, timeout=10).strip()


def current_windows():
    rows = json.loads(aerospace("list-windows", "--monitor", "all", "--format", FIELDS, "--json"))
    windows = {}
    for row in rows:
        path = row["app-bundle-path"]
        if not (path.startswith("/Applications/") and path.endswith(".app")):
            continue
        if ".app/" in path[len("/Applications/"):]:
            continue
        if not row["app-bundle-id"] or not row["workspace"]:
            continue
        windows[str(row["window-id"])] = {
            "bundle": row["app-bundle-id"],
            "pid": row["app-pid"],
            "workspace": row["workspace"],
        }
    return windows


def update(state, windows, action, window_id=None, focused_id=None):
    """Only observe registered window identities; creation must finish routing first."""
    previous = state["windows"]
    apps = state["apps"]
    tracked = {}
    moved_apps = set()
    for key, window in windows.items():
        old = previous.get(key)
        known = old and (old["bundle"], old["pid"]) == (window["bundle"], window["pid"])
        if known:
            tracked[key] = window
            if old["workspace"] != window["workspace"]:
                apps[window["bundle"]] = window["workspace"]
                moved_apps.add(window["bundle"])
        elif action == "seed":
            tracked[key] = window
            # An existing record takes precedence over a startup window's location.
            apps.setdefault(window["bundle"], window["workspace"])

    if action == "remember" and window_id in windows:
        window = windows[window_id]
        tracked[window_id] = window
        apps[window["bundle"]] = window["workspace"]
    elif action == "refresh" and focused_id in tracked:
        window = tracked[focused_id]
        # A silent move wins over the sibling left focused in the old workspace.
        if window["bundle"] not in moved_apps:
            apps[window["bundle"]] = window["workspace"]

    # Drop closed windows, but retain their application workspace for next launch.
    state["windows"] = tracked


def load_state(path):
    if not path.exists():
        return {"apps": {}, "windows": {}}
    state = json.loads(path.read_text())
    if not isinstance(state, dict) or not isinstance(state.get("apps"), dict) or not isinstance(state.get("windows"), dict):
        raise ValueError("invalid workspace memory")
    if not all(isinstance(k, str) and isinstance(v, str) and v for k, v in state["apps"].items()):
        raise ValueError("invalid application workspace records")
    for window in state["windows"].values():
        if not isinstance(window, dict) or not all(key in window for key in ("bundle", "pid", "workspace")):
            raise ValueError("invalid window records")
    return state


def save_state(path, state):
    fd, temporary = tempfile.mkstemp(dir=path.parent, prefix=".workspaces-")
    try:
        with os.fdopen(fd, "w") as output:
            json.dump(state, output, ensure_ascii=False, indent=2, sort_keys=True)
            output.write("\n")
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("get", "remember", "refresh", "seed"))
    parser.add_argument("value", nargs="?")
    args = parser.parse_args()
    if args.action in ("get", "remember") and not args.value:
        parser.error("get/remember requires a bundle ID/window ID")

    directory = Path(os.environ.get("AEROSPACE_WORKSPACE_STATE_DIR", str(Path.home() / "Library/Application Support/AeroSpace")))
    try:
        directory.mkdir(parents=True, exist_ok=True, mode=0o700)
        path = directory / "app-workspaces.json"
        # Serialize callback processes; never publish partially written JSON.
        with (directory / "app-workspaces.lock").open("a") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            state = load_state(path)
            if args.action == "get":
                workspace = state["apps"].get(args.value)
                if workspace is None:
                    return 1
                print(workspace)
                return 0
            windows = current_windows()
            focused = None
            if args.action == "refresh":
                try:
                    focused = aerospace("list-windows", "--focused", "--format", "%{window-id}")
                except subprocess.CalledProcessError:
                    pass  # An empty focused workspace has no focused window.
            before = json.dumps(state, sort_keys=True)
            update(state, windows, args.action, args.value, focused)
            if json.dumps(state, sort_keys=True) != before:
                save_state(path, state)
        return 0
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(f"AeroSpace workspace memory: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
