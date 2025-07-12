local Popup = require("nui.popup")
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
        local client_name = line:match("Client (.+)")
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
    local popup = Popup({
        position = "50%",
        size = { width = 40, height = #clients + 2 },
        border = {
            style = "rounded",
            text = { top = " Select Perforce Client ", top_align = "center" },
        },
        buf_options = { modifiable = true, readonly = false },
        enter = true,
    })
    popup:mount()
    vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, false, clients)

    vim.keymap.set("n", "<CR>", function()
        local row = vim.api.nvim_win_get_cursor(0)[1]
        local selected = clients[row]
        if selected then
            M.set_client(selected)
            popup:unmount()
            callback(selected)
        end
    end, { buffer = popup.bufnr })

    popup:on(event.BufLeave, function() popup:unmount() end)
end

return M
