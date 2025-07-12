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
    vim.cmd("highlight! P4ClientIcon guifg=#ffaa00 guibg=#365a98 gui=bold")
    vim.cmd("highlight! P4ClientName guibg=#365a98 gui=bold")
    local cursor_hl = vim.api.nvim_get_hl(0, { name = "Cursor", link = false })
    local lcursor_hl = vim.api.nvim_get_hl(0, { name = "lCursor", link = false })
    vim.api.nvim_set_hl(0, "Cursor", { fg = 'None', bg = 'None', reverse = true, blend = 100 })
    vim.api.nvim_set_hl(0, "lCursor", { fg = 'None', bg = 'None', reverse = true, blend = 100 })

    local items = {}
    for _, name in ipairs(clients) do
        table.insert(items, Menu.item(icon .. name, { value = name, index = _ - 1}))
    end

    local max_width = 0
    local max_height = math.min(#clients, 20)
    for _, name in ipairs(clients) do
        local len = vim.fn.strdisplaywidth(name)
        if len > max_width then max_width = len end
    end
    max_width = math.max(max_width + 4, 24)
    
    local menu = Menu({
        position = "50%",
        size = { width = max_width, height = max_height },
        border = { 
            style = "rounded",
            text = { top = "[ Perforce Clients ]", top_align = "center", }
        },
    }, {
        lines = items,
        keymap = { submit = { "<CR>" }, close = { "q", "<Esc>" }, },
        
        -- Highlight the selected item
        on_change = function(item, menu)
            vim.api.nvim_buf_clear_namespace(menu.bufnr, -1, 0, -1)
            vim.api.nvim_buf_add_highlight(menu.bufnr, -1, "P4ClientIcon", item.index, 0, 2)
            vim.api.nvim_buf_add_highlight(menu.bufnr, -1, "P4ClientName", item.index, 2, -1)
        end,

        -- Set the selected client
        on_submit = function(item)
            M.set_client(item.value)
            callback(item.value)
            vim.api.nvim_set_hl(0, "Cursor", cursor_hl)
            vim.api.nvim_set_hl(0, "lCursor", lcursor_hl)
        end,
    })

    menu:mount()
    
    -- Unmount the menu when leaving the buffer.
    menu:on(event.BufLeave, function()
        vim.api.nvim_set_hl(0, "Cursor", cursor_hl)
        vim.api.nvim_set_hl(0, "lCursor", lcursor_hl)
        menu:unmount()
    end)
end
return M
