local wezterm = require("wezterm")
return {
    color_scheme = "Ayu Mirage",
    font = wezterm.font("JetBrainsMono Nerd Font"),
    -- font = wezterm.font("VictorMono Nerd Font"),
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
