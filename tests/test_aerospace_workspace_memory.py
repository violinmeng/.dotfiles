"""Run with: python3 -m unittest discover -s tests -p 'test_aerospace*.py'."""

import copy
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SCRIPT_DIR = ROOT / "macos/aerospace"
spec = importlib.util.spec_from_file_location("memory", SCRIPT_DIR / "workspace-memory.py")
memory = importlib.util.module_from_spec(spec)
spec.loader.exec_module(memory)


def window(workspace, bundle="com.example.Editor", pid=100):
    return {"bundle": bundle, "pid": pid, "workspace": workspace}


class WorkspaceMemoryTests(unittest.TestCase):
    def setUp(self):
        self.state = {"apps": {"com.example.Editor": "C"}, "windows": {"10": window("C")}}

    def test_focus_before_routing_does_not_overwrite_history(self):
        memory.update(self.state, {"20": window("V", pid=200)}, "refresh", focused_id="20")
        self.assertEqual(self.state["apps"]["com.example.Editor"], "C")
        self.assertEqual(self.state["windows"], {})

    def test_register_after_route(self):
        memory.update(self.state, {"20": window("C", pid=200)}, "remember", window_id="20")
        self.assertEqual(self.state["windows"], {"20": window("C", pid=200)})

    def test_manual_move_is_remembered_even_without_focus(self):
        memory.update(self.state, {"10": window("Project Work")}, "refresh")
        self.assertEqual(self.state["apps"]["com.example.Editor"], "Project Work")

    def test_silent_move_wins_over_focused_sibling(self):
        self.state["windows"]["11"] = window("C")
        memory.update(self.state, {"10": window("V"), "11": window("C")}, "refresh", focused_id="11")
        self.assertEqual(self.state["apps"]["com.example.Editor"], "V")

    def test_last_focused_window_wins_when_no_window_moved(self):
        self.state["windows"]["11"] = window("V")
        memory.update(self.state, copy.deepcopy(self.state["windows"]), "refresh", focused_id="11")
        self.assertEqual(self.state["apps"]["com.example.Editor"], "V")

    def test_close_preserves_application_history(self):
        memory.update(self.state, {}, "refresh")
        self.assertEqual(self.state["windows"], {})
        self.assertEqual(self.state["apps"]["com.example.Editor"], "C")

    def test_reused_window_id_from_new_process_is_not_registered(self):
        memory.update(self.state, {"10": window("V", pid=999)}, "refresh", focused_id="10")
        self.assertEqual(self.state["windows"], {})
        self.assertEqual(self.state["apps"]["com.example.Editor"], "C")

    def test_seed_existing_windows_without_overwriting_history(self):
        memory.update(self.state, {"20": window("V", pid=200), "30": window("Z", "dev.zed.Zed")}, "seed")
        self.assertEqual(self.state["apps"], {"com.example.Editor": "C", "dev.zed.Zed": "Z"})
        self.assertEqual(len(self.state["windows"]), 2)

    def test_window_query_excludes_ineligible_bundles(self):
        paths = ["/Applications/Editor.app", "/Applications/Editor.app/Contents/Helper.app", "/System/Applications/Finder.app"]
        rows = [{"window-id": i, "app-pid": 100, "app-bundle-id": "com.example.Editor", "app-bundle-path": path, "workspace": "C"} for i, path in enumerate(paths)]
        with patch.object(memory, "aerospace", return_value=json.dumps(rows)):
            self.assertEqual(memory.current_windows(), {"0": window("C")})

    def test_atomic_private_state_roundtrip(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "app-workspaces.json"
            memory.save_state(path, self.state)
            self.assertEqual(memory.load_state(path), self.state)
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)
            self.assertEqual(list(Path(directory).iterdir()), [path])

    def test_invalid_state_is_not_silently_overwritten(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "app-workspaces.json"
            path.write_text('{"apps": []}')
            with self.assertRaises(ValueError):
                memory.load_state(path)
            self.assertEqual(path.read_text(), '{"apps": []}')


class RoutingTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.env = dict(os.environ, AEROSPACE_WORKSPACE_STATE_DIR=self.directory.name)

    def route(self, name, bundle, path="/Applications/Example.app"):
        return subprocess.run(["bash", str(SCRIPT_DIR / "route-window.sh"), "--print-workspace", name, bundle, path], env=self.env, text=True, capture_output=True)

    def test_first_letter_without_history(self):
        result = self.route("Example", "com.example.Editor")
        self.assertEqual((result.returncode, result.stdout.strip()), (0, "E"))

    def test_special_mapping_without_history(self):
        self.assertEqual(self.route("Feishu", "com.electron.lark").stdout.strip(), "1")
        self.assertEqual(self.route("Cursor", "com.todesktop.230313mzl4w4u92").stdout.strip(), "U")

    def test_history_precedes_special_mapping(self):
        path = Path(self.directory.name) / "app-workspaces.json"
        memory.save_state(path, {"apps": {"com.electron.lark": "我的 workspace"}, "windows": {}})
        result = self.route("Feishu", "com.electron.lark")
        self.assertEqual((result.returncode, result.stdout.strip()), (0, "我的 workspace"))

    def test_corrupt_history_falls_back(self):
        (Path(self.directory.name) / "app-workspaces.json").write_text("broken json")
        result = self.route("Example", "com.example.Editor")
        self.assertEqual((result.returncode, result.stdout.strip()), (0, "E"))

    def test_non_applications_bundle_not_routed(self):
        self.assertEqual(self.route("Example", "com.example.Editor", "/tmp/Example.app").returncode, 1)

    def test_every_workspace_move_binding_records_afterwards(self):
        # Python 3.11+ supplies tomllib; production helper itself only needs 3.8+.
        try:
            import tomllib
        except ImportError:
            self.skipTest("tomllib requires Python 3.11")
        config = tomllib.loads((SCRIPT_DIR / "aerospace.toml").read_text())
        for mode in config["mode"].values():
            for commands in mode["binding"].values():
                if isinstance(commands, str):
                    commands = [commands]
                moves = [i for i, command in enumerate(commands) if command.startswith(("move-node-to-workspace ", "move-node-to-monitor ", "move-workspace-to-monitor "))]
                for i in moves:
                    self.assertTrue(any("--remember-workspaces" in cmd for cmd in commands[i + 1:]), commands)


if __name__ == "__main__":
    unittest.main()
