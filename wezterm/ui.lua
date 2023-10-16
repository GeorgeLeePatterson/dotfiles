local wezterm = require("wezterm")

local function font(opts)
	return wezterm.font_with_fallback({
		opts,
		"Symbols Nerd Font Mono"
	})
end

return {
    color_scheme = "Ayu Mirage",

    --
    -- Font settings
    font = font("JetBrainsMono Nerd Font"),
    -- font = font("VictorMono Nerd Font"),
    font_rules = {	
	    {
	      italic = true,
	      intensity = "Normal",
	      font = font({
	        family = "VictorMono Nerd Font",
	        style = "Italic",
	      }),
	    },
	    {
	      italic = true,
	      intensity = "Half",
	      font = font({
	        family = "VictorMono Nerd Font",
	        weight = "DemiBold",
	        style = "Italic",
	      }),
	    },
	    {
	      italic = true,
	      intensity = "Bold",
	      font = font({
	        family = "VictorMono Nerd Font",
	        weight = "Bold",
	        style = "Italic",
	      }),
	    },
    },
    window_background_gradient = {
        orientation = "Vertical",
        colors = {
            "#03070E",
            "#010608",
        },
    },
    window_frame = {
        font = wezterm.font({ family = "Noto Sans", weight = "Regular" }),
    },
    underline_thickness = "1.4pt",
    underline_position = "-2pt",
    -- background
    window_background_opacity = 0.95,
    macos_window_background_blur = 20,
    -- inactive
    inactive_pane_hsb = {
        saturation = 0.8,
        brightness = 0.7,
    },
    window_padding = {
        left = "8px",
        right = "8px",
        top = "8px",
        bottom = "2px",
    },
}
