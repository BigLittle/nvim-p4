local Popup = require("nui.popup")
local Menu = require("nui.menu")
local NuiText = require("nui.text")
local event = require("nui.utils.autocmd").event
local M = { current_client = nil }

function M.bootstrap()
    local out = io.popen("p4 set"):read("*a")
    local client_name = out:match("P4CLIENT=(%S+)")
    if client_name then
        M.current_client = client_name
    end
end

function M.get_all_clients()
    local out = io.popen("p4 clients --me"):read("*a")
    local clients = {}
    for line in out:gmatch("[^\n]+") do
        local client_name = string.match(line, "Client%s+(%S+)")
        if client_name then table.insert(clients, client_name) end
    end
    return clients
end

function M.get_current_client()
    return M.current_client
end

function M.set_client(client_name)
    M.current_client = client_name
    os.execute("p4 set P4CLIENT=" .. client_name)
end

function M.select_client(callback)
    local clients = M.get_all_clients()
    if #clients == 0 then
        print("No Perforce clients found.")
        return
    end
    local icon = " "
    vim.cmd("highlight! P4ClientIcon guifg=#ffaa00 gui=bold")
    vim.cmd("highlight! NuiMenuCursor guifg=NONE guibg=NONE gui=bold")

    local items = {}
    for _, name in ipairs(clients) do
        table.insert(items, Menu.item(icon .. name, { value = name, index = _ }))
    end

    local max_width = 0
    local max_height = math.min(#clients, 20)
    for _, name in ipairs(clients) do
        local len = vim.fn.strdisplaywidth(name)
        if len > max_width then max_width = len end
    end
    max_width = math.max(max_width + 4, 50)
    
    local menu = Menu({
        position = "50%",
        size = { width = max_width, height = max_height },
        border = { 
            style = "rounded",
            padding = { top = 1, bottom = 1, left = 2, right = 2 },
            text = { 
                top = " Select a Perforce Client ",
                top_align = "center",
                bottom = " Press [Enter] to select, [Esc] to close ",
                bottom_align = "center",
            }
        },
        -- win_options = {
        --     -- winhighlight = "Normal:Normal,P4ClientIcon:Normal",
        --     winhighlight = "Error:Error,Error:Error",
        },
    }, {
        lines = items,
        keymap = { 
            submit = { "<CR>" },
            close = { "q", "<Esc>" },
        },
        on_submit = function(item)
            M.set_client(item.value)
            callback(item.value)
        end,
        on_change = function(item, menu)
            -- Highlight the selected item
            vim.api.nvim_buf_clear_namespace(menu.bufnr, -1, 0, -1)
            vim.api.nvim_buf_add_highlight(menu.bufnr, -1, "P4ClientIcon", item.index, 0, 2)
            vim.api.nvim_buf_add_highlight(menu.bufnr, -1, "NuiMenuCursor", item.index, 0, -1)
        end,
    })

    menu:mount()
    menu:on(event.BufLeave, function() menu:unmount() end)  -- Unmount the menu when leaving the buffer.






    -- local display_names = {}
    -- local index_to_client = {}
    -- for i, name in ipairs(clients) do
    --     display_names[i] = icon .. name
    --     index_to_client[i] = name
    -- end
    --
    -- local max_width = 0
    -- for _, name in ipairs(display_names) do
    --     local len = vim.fn.strdisplaywidth(name)
    --     if len > max_width then max_width = len end
    -- end
    -- max_width = math.min(max_width + 4, 80)
    -- local max_height = math.min(#clients, 9)
    --
    -- local popup = Popup({
    --     position = "50%",
    --     size = { width = max_width, height = max_height },
    --     border = {
    --         style = "rounded",
    --         text = { top = " Select Perforce Client ", top_align = "center" },
    --     },
    --     buf_options = { modifiable = true, readonly = false },
    --     enter = true,
    -- })
    --
    -- popup:mount()
    -- vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, false, display_names)
    --
    -- vim.cmd("highlight! P4ClientIcon guifg=#ffaa00 gui=bold")
    -- for i = 0, #clients - 1 do
    --     vim.api.nvim_buf_add_highlight(popup.bufnr, -1, "P4ClientIcon", i, 0, 2)
    -- end
    --
    -- vim.api.nvim_win_set_option(popup.winid, "scrolloff", math.floor (#clients / 2))
    -- vim.api.nvim_win_set_cursor(popup.winid, { 1, 2 })
    --
    -- -- vim.api.nvim_buf_set_option(popup.bufnr, "cursorline", true)
    -- -- vim.api.nvim_buf_set_commands(popup.bufnr, {"highlight", "CursorLine", { link = "Visual" } })
    --
    -- vim.keymap.set("n", "<CR>", function()
    --     local row = vim.api.nvim_win_get_cursor(0)[1]
    --     local selected = index_to_client[row]
    --     if selected then
    --         M.set_client(selected)
    --         popup:unmount()
    --         callback(selected)
    --     end
    -- end, { buffer = popup.bufnr })
    --
    -- vim.keymap.set("n", "q", function()
    --     popup:unmount()
    -- end, { buffer = popup.bufnr, nowait = true })
    --
    -- vim.keymap.set("n", "<Esc>", function()
    --     popup:unmount()
    -- end, { buffer = popup.bufnr, nowait = true })
    --
    -- popup:on(event.BufLeave, function() popup:unmount() end)
end

return M
