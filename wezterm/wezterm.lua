local wezterm = require("wezterm")
local utils = require("utils")

local keys = require("keys")
local ssh = require("ssh")
local ui = require("ui")

local config = {}

if wezterm.config_builder then
	config = wezterm.config_builder()
end

config.native_macos_fullscreen_mode = true

-- other chars
config.use_dead_keys = false

-- scrolling
config.enable_scroll_bar = false
config.scrollback_lines = 100000

config.adjust_window_size_when_changing_font_size = false
config.hide_tab_bar_if_only_one_tab = true

local final = utils.create_config(config, { ui, keys, ssh })
wezterm.log_info(final)
return final
