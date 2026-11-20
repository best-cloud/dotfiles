-- Managed by chezmoi: dot_config/wezterm/wezterm.lua
--
-- Alternative terminal on Windows for WSL-only sessions. Windows Terminal is
-- the default client. This config only opens WSL2 Ubuntu; there is no
-- PowerShell/cmd launch menu on purpose. Tuned for an RTX 4090 and a 2K
-- (2560x1440) display at 100% scaling.
--
-- WezTerm searches $XDG_CONFIG_HOME/wezterm/wezterm.lua and then
-- ~/.config/wezterm/wezterm.lua before ~/.wezterm.lua, so this file wins.
-- The old unmanaged ~/.wezterm.lua can safely be deleted.

local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- ---------------------------------------------------------------------------
-- WSL2 Ubuntu only
-- ---------------------------------------------------------------------------
config.default_domain = 'WSL:Ubuntu'
config.wsl_domains = {
    {
        name = 'WSL:Ubuntu',
        -- Must match `wsl --list --quiet` (for example Ubuntu-24.04).
        distribution = 'Ubuntu',
        default_cwd = '~',
    },
}

-- ---------------------------------------------------------------------------
-- GPU acceleration (RTX 4090)
-- ---------------------------------------------------------------------------
config.front_end = 'WebGpu'
config.webgpu_power_preference = 'HighPerformance'
-- 2K high-refresh panel: render fast, keep UI animations calm.
config.max_fps = 120
config.animation_fps = 60
-- The GPU has VRAM to spare, so keep a deep history.
config.scrollback_lines = 100000
-- Windows 11 Acrylic backdrop. It costs a little GPU work; the 4090 does not
-- notice, and the opacity below is what makes the effect visible.
config.win32_system_backdrop = 'Acrylic'
config.window_background_opacity = 0.92

-- ---------------------------------------------------------------------------
-- 2K screen (100% scaling)
-- ---------------------------------------------------------------------------
config.initial_cols = 160
config.initial_rows = 44
config.font = wezterm.font('JetBrainsMono Nerd Font', { weight = 'Medium' })
config.font_size = 12.0
config.line_height = 1.1
config.adjust_window_size_when_changing_font_size = true
config.window_padding = {
    left = '1cell',
    right = '1cell',
    top = '0.5cell',
    bottom = '0.5cell',
}

-- ---------------------------------------------------------------------------
-- Appearance and behaviour
-- ---------------------------------------------------------------------------
config.color_scheme = 'Catppuccin Mocha'
config.window_decorations = 'INTEGRATED_BUTTONS|RESIZE'
config.hide_tab_bar_if_only_one_tab = true
-- Avoid IME conflicts with some Windows input methods.
config.use_dead_keys = false

return config
