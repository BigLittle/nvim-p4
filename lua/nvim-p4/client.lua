local Menu = require("nui.menu")
local event = require("nui.utils.autocmd").event
local M = { name = nil, root = nil }

function M.bootstrap()
    local out = vim.fn.system("p4 set")
    local client_name = out:match("P4CLIENT=(%S+)")
    if client_name then M.set_client(client_name) end
end

function M.ensure_client(callback)
    if M.name == nil then M.select_client() end
    if M.name == nil then return end
    callback()
end

-- List all clients currently available on the server
function M.get_clients()
    local out = vim.fn.system("p4 clients --me")
    local clients = {}
    for line in out:gmatch("[^\n]+") do
        local client_name = line:match("Client%s+(%S+)")
        if client_name then table.insert(clients, client_name) end
    end
    return clients
end

function M.set_client(client_name)
    M.name = client_name
    -- os.execute("p4 set P4CLIENT=" .. client_name)
    local out = vim.fn.system("p4 -c " .. client_name .. " info")
    local client_root = out:match("Client root: (%S+)")
    if client_root then M.root = client_root end
end

function M.select_client(callback)
    local clients = M.get_clients()
    if #clients == 0 then
        utils.notify_warning("No Perforce clients found.")
        return
    end
    local icon = "  "
    vim.cmd("highlight! P4ClientHead guifg=#365a98 guibg=#365a98 gui=bold")
    vim.cmd("highlight! P4ClientIcon guifg=#ffaa00 guibg=#365a98 gui=bold")
    vim.cmd("highlight! P4ClientName guibg=#365a98 gui=bold")

    local items = {}
    for _, name in ipairs(clients) do
        table.insert(items, Menu.item(icon .. name .. " ", { value = name, index = _ - 1}))
    end

    local max_width = 0
    local max_height = math.min(#clients, 20)
    for _, name in ipairs(clients) do
        local len = vim.fn.strdisplaywidth(name)
        if len > max_width then max_width = len end
    end
    max_width = math.max(max_width + 4, 24)

    local menu = Menu({
        relative = "editor",
        position = "50%",
        size = { width = max_width, height = max_height },
        border = {
            style = "rounded",
            text = { top = "[ Perforce Clients ]", top_align = "center", },
            padding = { top = 0, bottom = 0, left = 0, right = 0 },
        },
    }, {
        lines = items,
        keymap = { submit = { "<CR>" }, close = { "q", "<Esc>" }, },

        -- Highlight the selected item
        on_change = function(item, menu)
            vim.api.nvim_buf_clear_namespace(menu.bufnr, -1, 0, -1)
            vim.api.nvim_buf_add_highlight(menu.bufnr, -1, "P4ClientHead", item.index, 0, 1)
            vim.api.nvim_buf_add_highlight(menu.bufnr, -1, "P4ClientIcon", item.index, 1, 3)
            vim.api.nvim_buf_add_highlight(menu.bufnr, -1, "P4ClientName", item.index, 3, -1)
        end,

        -- Set the selected client
        on_submit = function(item)
            M.set_client(item.value)
            callback()
        end,
    })

    menu:mount()

    -- Disable horizontal navigation keys
    vim.api.nvim_buf_set_keymap(menu.bufnr, "n", "h", "<Nop>", { noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(menu.bufnr, "n", "l", "<Nop>", { noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(menu.bufnr, "n", "<Left>", "<Nop>", { noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(menu.bufnr, "n", "<Right>", "<Nop>", { noremap = true, silent = true })

    -- Unmount the menu when leaving the buffer
    menu:on(event.BufLeave, function() menu:unmount() end)
end
return M
