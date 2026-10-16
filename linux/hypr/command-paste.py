#!/usr/bin/env python3
"""Forward Command+V without blocking Hyprland's Wayland event loop."""
import json
import subprocess

window = json.loads(subprocess.check_output(["hyprctl", "-j", "activewindow"], timeout=3))
terminal = any(tag.rstrip("*") == "terminal" for tag in window.get("tags", []))
mods, key = "CTRL", "V"
if terminal:
    types = subprocess.run(["wl-paste", "--list-types"], capture_output=True, text=True, timeout=3)
    if not any(mime.startswith("image/") for mime in types.stdout.splitlines()):
        mods, key = "SHIFT", "Insert"
# Explicit modifiers prevent the physically held Super key joining the chord.
subprocess.run(["hyprctl", "eval", f'hl.dispatch(hl.dsp.send_key_state({{mods="{mods}",key="{key}",state="down"}})); hl.timer(function() hl.dispatch(hl.dsp.send_key_state({{mods="{mods}",key="{key}",state="up"}})) end, {{timeout=50,type="oneshot"}})'], check=True, timeout=3)
