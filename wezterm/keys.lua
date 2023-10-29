---@diagnostic disable: bad_string_escape
local wezterm = require("wezterm")
local split_nav = require("utils").split_nav
local act = wezterm.action

-- Key bindings
return {
    keys = {
        ---@diagnostic disable-next-line: bad_string_escape
        { key = "RightArrow", mods = "ALT",            action = act.SendString("\x1bf") },
        { key = "LeftArrow",  mods = "ALT",            action = act.SendString("\x1bb") },
        -- close pane
        { key = "q",          mods = "CTRL|SHIFT|ALT", action = act.CloseCurrentPane({ confirm = true }) },
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
    },

    -- modifiers
    -- send_composed_key_when_left_alt_is_pressed = true,
    -- send_composed_key_when_right_alt_is_pressed = true,
}
