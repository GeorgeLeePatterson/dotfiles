local wezterm = require("wezterm")
local config = {}
local act = wezterm.action

if wezterm.config_builder then
	config = wezterm.config_builder()
end

config.font = wezterm.font("JetBrainsMono Nerd Font")
-- config.font = wezterm.font("VictorMono Nerd Font")

config.window_frame = {
	font = wezterm.font({ family = "Noto Sans", weight = "Regular" }),
}

config.underline_thickness = "1.4pt"
config.underline_position = "-2pt"

config.window_padding = {
	left = 0,
	right = 0,
	top = 0,
	bottom = 0,
}

config.native_macos_fullscreen_mode = true

config.color_scheme = "Ayu Mirage"

config.window_background_gradient = {
	orientation = "Vertical",
	colors = {
		"#141E30",
		"#1f2430",
	},
}

config.inactive_pane_hsb = {
	saturation = 0.8,
	brightness = 0.7,
}

config.window_background_opacity = 0.95
config.macos_window_background_blur = 20

config.enable_scroll_bar = false
config.scrollback_lines = 100000

config.adjust_window_size_when_changing_font_size = false
config.hide_tab_bar_if_only_one_tab = true

-- Configure smart-splits

-- if you are *NOT* lazy-loading smart-splits.nvim (recommended)
local function is_vim(pane)
	-- this is set by the plugin, and unset on ExitPre in Neovim
	return pane:get_user_vars().IS_NVIM == "true"
end

local direction_keys = {
	Left = "h",
	Down = "j",
	Up = "k",
	Right = "l",
	-- reverse lookup
	h = "Left",
	j = "Down",
	k = "Up",
	l = "Right",
}

local function split_nav(resize_or_move, key)
	return {
		key = key,
		mods = resize_or_move == "resize" and "META" or "CTRL",
		action = wezterm.action_callback(function(win, pane)
			if is_vim(pane) then
				-- pass the keys through to vim/nvim
				win:perform_action({
					SendKey = { key = key, mods = resize_or_move == "resize" and "META" or "CTRL" },
				}, pane)
			else
				if resize_or_move == "resize" then
					win:perform_action({ AdjustPaneSize = { direction_keys[key], 3 } }, pane)
				else
					win:perform_action({ ActivatePaneDirection = direction_keys[key] }, pane)
				end
			end
		end),
	}
end

-- Key bindings

config.keys = {
	{ key = "RightArrow", mods = "ALT", action = act.SendString("\x1bf") },
	{ key = "LeftArrow",  mods = "ALT", action = act.SendString("\x1bb") },
	-- move between split panes
	split_nav("move", "h"),
	split_nav("move", "j"),
	split_nav("move", "k"),
	split_nav("move", "l"),
	-- resize panes
	split_nav("resize", "h"),
	split_nav("resize", "j"),
	split_nav("resize", "k"),
	split_nav("resize", "l"),
}

return config
