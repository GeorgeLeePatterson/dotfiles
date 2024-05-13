local wezterm = require("wezterm")
local function font(opts)
    return wezterm.font_with_fallback({
        opts,
        "Symbols Nerd Font Mono",
    })
end

local gruvbox_material_override = wezterm.color.get_builtin_schemes()["Gruvbox Material (Gogh)"]
gruvbox_material_override.ansi[1] = "#804204"
gruvbox_material_override.brights[1] = "#804204"

return {
    -- [[ Colorscheme ]]

    -- color_scheme = "Ayu Mirage",
    color_scheme = "nightfox",
    -- color_scheme = "Gruvbox dark, hard (base16)",

    -- Or you can override a scheme
    color_schemes = {
        ["Gruvbox Material Override"] = gruvbox_material_override,
    },
    -- color_scheme = "Gruvbox Material Override",

    -- [[ Font settings ]]

    -- font = font("FiraCode Nerd Font"),
    -- font = font("Mononoki Nerd Font"),
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

    -- [[ Window ]]

    -- An example of how to give the background a gradient
    -- window_background_gradient = {
    --     orientation = "Vertical",
    --     colors = {
    --         "#03070E",
    --         "#010608",
    --     },
    -- },
    window_decorations = "RESIZE",
    window_frame = {
        font = wezterm.font({ family = "VictorMono Nerd Font", weight = "Regular" }),
    },
    enable_scroll_bar = true,
    -- scrollbar_thumb = '#222222',

    -- [[ Ligatures]]

    -- underline
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
        left = 0, -- "8px",
        right = 0, -- "8px",
        top = 0, -- "8px",
        bottom = 0, -- "2px",
    },
}
