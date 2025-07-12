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
    local icon = " " -- Icon for the popup
    local display_names = {}
    local index_to_client = {}
    for i, name in ipairs(clients) do
        display_names[i] = icon .. name
        index_to_client[i] = name
    end

    local max_width = 0
    for _, name in ipairs(display_names) do
        local len = vim.fn.strdisplaywidth(name)
        if len > max_width then max_width = len end
    end
    max_width = math.min(max_width + 4, 80)
    local max_height = math.min(#clients, 9)

    local popup = Popup({
        position = "50%",
        size = { width = max_width, height = max_height },
        border = {
            style = "rounded",
            text = { top = " Select Perforce Client ", top_align = "center" },
        },
        buf_options = { modifiable = true, readonly = false },
        enter = true,
    })

    popup:mount()
    vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, false, display_names)

    vim.api.nvim_win_set_option(popup.bufnr, "cursorline", true)
    -- vim.cmd("highlight! link CursorLine Visual")
    vim.api.nvim_win_set_option(popup.bufnr, "scrolloff", math.floor(#clients / 2))
    vim.api.nvim_win_set_cursor(popup.bufnr, { 1, 2 })

    vim.keymap.set("n", "<CR>", function()
        local row = vim.api.nvim_win_get_cursor(0)[1]
        local selected = index_to_client[row]
        if selected then
            M.set_client(selected)
            popup:unmount()
            callback(selected)
        end
    end, { buffer = popup.bufnr })

    vim.keymap.set("n", "q", function()
        popup:unmount()
    end, { buffer = popup.bufnr, nowait = true })

    vim.keymap.set("n", "<Esc>", function()
        popup:unmount()
    end, { buffer = popup.bufnr, nowait = true })

    popup:on(event.BufLeave, function() popup:unmount() end)
end

return M
