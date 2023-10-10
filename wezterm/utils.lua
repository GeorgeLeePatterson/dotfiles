local M = {}

local wezterm = require("wezterm")

local direction_keys = {
    -- move
    Left = "h",
    Down = "j",
    Up = "k",
    Right = "l",
    -- resize
    h = "Left",
    j = "Down",
    k = "Up",
    l = "Right",
}

-- Configure smart-splits
-- if you are *NOT* lazy-loading smart-splits.nvim (recommended)
local function is_vim(pane)
    -- this is set by the plugin, and unset on ExitPre in Neovim
    return pane:get_user_vars().IS_NVIM == "true"
end

function M.split_nav(resize_or_move, key)
    return {
        key = key,
        -- META = rexize, CRTL = move
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

M.find = function(table, predicate)
    for _, val in pairs(table) do
        if predicate(val) then
            return val
        end
    end
    return nil
end

M.create_config = function(config, tables)
    for _, table in pairs(tables) do
        for key, value in pairs(table) do
            config[key] = value
        end
    end
    return config
end

return M
