local Popup = require("nui.popup")
local Menu = require("nui.menu")
local Tree = require("nui.tree")
local Line = require("nui.line")
local event = require("nui.utils.autocmd").event
local Icons = require("mini.icons")
local Opts = require("nvim-p4.config").opts.changes
local client = require("nvim-p4.client")
local utils = require("nvim-p4.utils")
local p4 = require("nvim-p4.p4")

local M = {}
M.popup = nil
M.tree = nil
M.select_node = nil
M.changlists = {}

-- Prepare nodes for the tree view
local function prepare_nodes()
    M.select_node = nil
    M.changlists = {}
    local nodes = {}
    for _, changelist in ipairs(p4.changes()) do
        table.insert(M.changlists, changelist.number)
        local cl_data = {}
        cl_data["id"] = changelist.number
        cl_data["text"] = changelist.number .. "   " .. changelist.description:gsub("%s+", " ")
        cl_data["changlist"] = true
        cl_data["empty"] = false
        local opened_files = p4.opened(changelist.number)
        if not opened_files or #opened_files == 0 then cl_data["empty"] = true end
        local children = {}
        for _, file in ipairs(opened_files) do
            table.insert(children, Tree.Node(file))
        end
        local node = Tree.Node(cl_data, children)
        node:expand() -- Expand the node by default
        table.insert(nodes, node)
    end
    return nodes
end

-- Update tree contents and render it
local function refresh_tree()
    M.tree:set_nodes(prepare_nodes())
    M.tree:render()
    M.popup.border:set_text("top", "[  "..client.name.." ]", "center")
    M.popup.border:set_text("bottom", " Last updated: " .. os.date("%Y-%m-%d %H:%M:%S") .. " ", "center")
end

function M.revert_opened_file(callback)
    local items = {}
    table.insert(items, Menu.item("  Revert If Unchanged ", { value = "Revert If Unchanged", index = 0 }))
    table.insert(items, Menu.item("  Revert ", { value = "Revert", index = 1 }))
    local menu = Menu({
        relative = "editor",
        position = "50%",
        size = { width = 23, height = #items },
        border = {
            style = "double",
            padding = { top = 0, bottom = 0, left = 0, right = 0 },
        },
        win_options = { winhighlight = "Normal:Normal,FloatBorder:MiniIconsOrange" },
    }, {
        lines = items,
        keymap = { submit = { "<CR>" }, close = { "q", "<Esc>" }, },

        -- Highlight the selected item
        on_change = function(item, menu)
            vim.api.nvim_buf_clear_namespace(menu.bufnr, -1, 0, -1)
            vim.api.nvim_buf_add_highlight(menu.bufnr, -1, "P4ChangesHead", item.index, 0, 1)
            vim.api.nvim_buf_add_highlight(menu.bufnr, -1, "Visual", item.index, 1, -1)
        end,

        -- Set the selected client
        on_submit = function(item)
            callback(item.value)
        end,
    })

    menu:mount()

    -- Unmount the menu when leaving the buffer
    menu:on(event.BufLeave, function()
        callback("")
        menu:unmount()
    end)
end

function M.move_opened_file(callback)
    local items = {}
    local max_width = 0
    for _, changelist in ipairs(M.changlists) do
        table.insert(items, Menu.item("  "..changelist.." ", { value = changelist, index = _ - 1}))
        local len = vim.fn.strdisplaywidth(changelist)
        if len > max_width then max_width = len end
    end

    local menu = Menu({
        relative = "editor",
        position = "50%",
        size = { width = max_width + 4, height = #items },
        border = {
            style = "double",
            padding = { top = 0, bottom = 0, left = 0, right = 0 },
        },
        win_options = { winhighlight = "Normal:Normal,FloatBorder:MiniIconsOrange" },
    }, {
        lines = items,
        keymap = { submit = { "<CR>" }, close = { "q", "<Esc>" }, },

        -- Highlight the selected item
        on_change = function(item, menu)
            vim.api.nvim_buf_clear_namespace(menu.bufnr, -1, 0, -1)
            vim.api.nvim_buf_add_highlight(menu.bufnr, -1, "P4ChangesHead", item.index, 0, 1)
            vim.api.nvim_buf_add_highlight(menu.bufnr, -1, "Visual", item.index, 1, -1)
        end,

        -- Set the selected client
        on_submit = function(item)
            callback(item.value)
        end,
    })

    menu:mount()

    -- Unmount the menu when leaving the buffer
    menu:on(event.BufLeave, function()
        callback("")
        menu:unmount()
    end)
end

function M.open()
    if M.popup ~= nil then
        if vim.fn.bufwinid(M.popup.bufnr) == -1 then
            M.popup:show()
        else
            M.popup:hide()
        end
        return
    end
    local nodes = prepare_nodes()

    M.popup = Popup({
        relative = "editor",
        enter = true,
        focusable = true,
        border = {
            style = "rounded",
            text = {
                top = "[  "..client.name.." ]",
                top_align = "center",
                bottom = " Last updated: " .. os.date("%Y-%m-%d %H:%M:%S") .. " ",
                bottom_align = "center",
            },
            padding = { top = 0, bottom = 0, left = 0, right = 1 },
        },
        position = "50%",
        size = {
            width = math.min(120, math.floor(vim.o.columns * 0.8)),
            height = math.min(20, math.floor(vim.o.lines * 0.5)),
        },
        buf_options = { modifiable = true, readonly = false },
        win_options = { wrap = false },
        ns_id = "nvim_p4_changes",
    })
    M.popup:mount()

    local normal_hl = vim.api.nvim_get_hl(0, { name = "Normal" })
    vim.api.nvim_set_hl(0, "P4ChangesHead", { fg = normal_hl.bg } )
    vim.api.nvim_set_hl(0, "P4ChangesEdit", { fg = "#74c1fc" } )

    M.tree = Tree({
        bufnr = M.popup.bufnr,
        nodes = nodes,
        prepare_node = function(node)
            if M.select_node == nil then M.select_node = node end
            local text_hl = "Normal"
            if node == M.select_node then text_hl = "Visual" end

            local line = Line()
            line:append(" ", "P4ChangesHead")

            line:append(string.rep("  ", node:get_depth() - 1))
            if node.changlist then
                if node.empty then
                    line:append("  ", "P4ChangesHead")
                    line:append("󰔶 ", "MiniIconsBlue")
                else
                    line:append(node:is_expanded() and " " or " ", "SpecialChar")
                    line:append("󰔶 ", "ErrorMsg")
                end
                line:append(utils.rstrip(node.text), text_hl)
            else
                line:append("  ", "P4ChangesHead")
                if node.differ_from_head then
                    line:append("", "P4ChangesEdit")
                else
                    line:append("", "Normal")
                end
                if node.headRev == nil then
                    line:append(" ", "MiniIconsRed")
                else
                    if node.workRev == node.headRev then
                        line:append("󱍸 ", "MiniIconsGreen")
                    else
                        line:append(" ", "MiniIconsYellow")
                    end
                end
                local icon, hl, is_fallback = Icons.get("file", node.depotFile)
                if is_fallback then
                    icon = " " -- Default icon if not found
                    hl = "MiniIconsCyan"
                end
                line:append(icon.." ", hl)
                line:append(node.depotFile.. " #" .. node.workRev .. "/" .. node.headRev .. " <" .. node.type .. ">", text_hl)
            end
            return line
        end,
    })

    M.tree:render()

    -- Hide the popup when leaving the buffer
    M.popup:on(event.BufLeave, function()
        if vim.g.__focused then return end
        M.popup:hide()
    end)

    -- Highlight the current node
    M.popup:on({ event.CursorMoved, event.CursorMovedI }, function()
        if vim.b.__moving_cursor then return end
        vim.b.__moving_cursor = true
        vim.schedule(function()
            local cursor = vim.api.nvim_win_get_cursor(M.popup.winid)
            vim.api.nvim_win_set_cursor(M.popup.winid, { cursor[1], 0 })
            vim.b.__moving_cursor = false
        end)
        local node = M.tree:get_node()
        if not node then return end
        if M.select_node == node then return end
        M.select_node = node
        M.tree:render()
    end)

    --Auto-resize the popup when the window is resized
    M.popup:on(event.VimResized, function()
        if M.popup == nil then return end
        local config = {
            relative = "editor",
            size = {
                width = math.min(120, math.floor(vim.o.columns * 0.8)),
                height = math.min(20, math.floor(vim.o.lines * 0.5)),
            },
            position = "50%",
        }
        M.popup:update_layout(config)
        M.tree:render()
    end)

    -- Refresh
    vim.keymap.set("n", Opts.keymaps.refresh, function() refresh_tree() end, { buffer = M.popup.bufnr })

    -- Select a client
    vim.keymap.set("n", Opts.keymaps.switch_client, function()
        local current_client = client.name
        client.select_client(function()
            if client.name == current_client then return end
            refresh_tree()
        end)
    end, { buffer = M.popup.bufnr })

    -- Move opened file between changelist
    vim.keymap.set("n", Opts.keymaps.move, function()
        local node = M.tree:get_node()
        if not node then return end
        if node.changlist then return end
        local current_changelist = node:get_parent_id()
        local depot_file = node.depotFile
        vim.g.__focused = true
        M.move_opened_file(function(value)
            vim.g.__focused = false
            if value == current_changelist or value == "" then return end
            p4.reopen(depot_file, value)
            refresh_tree()
        end)
    end, { buffer = M.popup.bufnr })

    -- Toggle the expansion of the current node if it is a changelist
    vim.keymap.set("n", Opts.keymaps.toggle_changelist, function()
        local node = M.tree:get_node()
        if not node then return end
        if not node.changlist then return end
        if node.empty then return end
        if node:is_expanded() then
            node:collapse()
        else
            node:expand()
        end
        M.tree:render()
    end, { buffer = M.popup.bufnr, nowait = true })

    -- Open the selected file in the editor
    vim.keymap.set("n", Opts.keymaps.edit, function()
        local node = M.tree:get_node()
        if not node then return end
        if node.changlist then
            if node.empty then return end
            local children = M.tree:get_nodes(node:get_id())
            M.popup:hide()
            for _, child in ipairs(children) do
                utils.edit_file(child.path, utils.find_valid_buffer(M.popup.bufnr))
            end
        else
            M.popup:hide()
            utils.edit_file(node.path, utils.find_valid_buffer(M.popup.bufnr))
        end
    end, { buffer = M.popup.bufnr, nowait = true })

    -- Revert the selected file
    vim.keymap.set("n", Opts.keymaps.revert, function()
        local node = M.tree:get_node()
        if not node then return end
        if node.changlist then return end
        local depot_file = node.depotFile
        vim.g.__focused = true
        M.revert_opened_file(function(value)
            vim.g.__focused = false
            if value == "" then return end
            p4.revert(depot_file, value == "Revert If Unchanged")
            refresh_tree()
        end)
    end, { buffer = M.popup.bufnr, nowait = true })

    -- Hide the popup with 'q' or 'Esc'
    vim.keymap.set("n", "q", function() M.popup:hide() end, { buffer = M.popup.bufnr, nowait = true })
    vim.keymap.set("n", "<Esc>", function() M.popup:hide() end, { buffer = M.popup.bufnr, nowait = true })

end
return M
