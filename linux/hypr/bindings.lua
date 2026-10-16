-- Keep only your personal keybinding overrides here. Add new bindings or
-- unbind defaults before replacing them.

-- See current bindings and descriptions:
--   omarchy menu keybindings --print

-- To disable every Omarchy default binding, set this in
-- ~/.config/hypr/hyprland.lua before require("default.hypr.omarchy"), then add
-- only the bindings you want below:
--   omarchy_default_bindings = false

-- To disable all preinstalled app/webapp bindings, set:
--   omarchy_preinstalled_bindings = false

-- Add a new binding.
-- o.bind("SUPER + SHIFT + R", "SSH", "alacritty -e ssh your-server")

-- Change an existing binding by unbinding it first, then binding the key again.
-- This example changes SUPER+SPACE from the launcher to the Omarchy root menu.
-- hl.unbind("SUPER + SPACE")
-- o.bind("SUPER + SPACE", "Omarchy menu", "omarchy-menu toggle root")

-- Disable a default binding without replacing it.
-- hl.unbind("SUPER + SHIFT + B")

-- Logitech MX Keys examples:
-- o.bind("SUPER + SHIFT + S", nil, "omarchy-capture-screenshot")
-- o.bind("SUPER + H", nil, "voxtype record toggle")
-- o.bind("SUPER + PERIOD", nil, "omarchy-shell shell toggle omarchy.emojis")

-- Command/Super + Shift + A replaces the default ChatGPT web app shortcut.
hl.unbind("SUPER + SHIFT + A")
o.bind("SUPER + SHIFT + A", "Screenshot and annotate with Satty", [[sh -c 'file=$(omarchy capture screenshot region save) && [ -n "$file" ] && exec satty --filename "$file" --output-filename "$file" --copy-command wl-copy']])

-- macOS-style save in Satty; preserve the scratchpad shortcut elsewhere.
local function command_shortcut(mods, key)
  hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "down" }))
  hl.timer(function()
    hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "up" }))
  end, { timeout = 50, type = "oneshot" })
end

hl.unbind("SUPER + S")
o.bind("SUPER + S", "Save in Satty / toggle scratchpad", function()
  local window = hl.get_active_window()
  if window and (window.class or ""):lower():find("satty", 1, true) then
    command_shortcut("CTRL", "S")
  else
    hl.dispatch(hl.dsp.workspace.toggle_special("scratchpad"))
  end
end)

-- Inspect clipboard MIME types outside Hyprland so Wayland stays responsive.
hl.unbind("SUPER + V")
o.bind("SUPER + V", "Paste text or image", "python3 ~/.config/hypr/command-paste.py")
