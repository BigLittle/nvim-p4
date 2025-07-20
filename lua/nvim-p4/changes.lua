local Popup = require("nui.popup")
local Input = require("nui.input")
local Tree = require("nui.tree")
local Line = require("nui.line")
local event = require("nui.utils.autocmd").event
local Icons = require("mini.icons")
local client = require("nvim-p4.client")
local utils = require("nvim-p4.utils")
local p4 = require("nvim-p4.p4")

local M = {}
M.popup = nil
M.select_node = nil
M.changlists = {}




function M.move_opened_file(callback)
    local input_popup = Input({
        position = "50%",
        size = { width = 25 },
        border = {
            style = "rounded",
            text = { top = "[ Move to ... ]", top_align = "center" },
        },
        win_options = { winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder" },
        }, {
        prompt = " Changelist: ",
        default_value = "",
        on_submit = callback,
    })
    input_popup:mount()

    vim.api.nvim_create_autocmd(event.BufLeave, {
        buffer = input_popup.bufnr,
        once = true,
        callback = function()
            input_popup:unmount()
        end,
    })
end

-- Prepare nodes for the tree view
function M.prepare_nodes()
    M.select_node = nil
    M.changlists = {}
    local nodes = {}
    for _, changelist in ipairs(p4.changes()) do
        M.changlists[changelist.number] = changelist.description
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

function M.open()
    if M.popup ~= nil then
        M.popup:show()
        return
    end
    local nodes = M.prepare_nodes()

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
    vim.api.nvim_set_hl(0, "P4ChangesEdit", { fg = "#c4e6ff" } )

    local tree = Tree({
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
                    line:append(" ", "P4ChangesEdit")
                else
                    line:append(" ", "Normal")
                end
                if node.workRev == node.headRev then
                    line:append(" ", "MiniIconsGreen")
                else
                    line:append(" ", "MiniIconsYellow")
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

    tree:render()

    -- Hide the popup when leaving the buffer
    M.popup:on(event.BufLeave, function()
        if vim.b.__taking_input then return end
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
        local node = tree:get_node()
        if not node then return end
        if M.select_node == node then return end
        M.select_node = node
        tree:render()
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
        tree:render()
    end)

    -- Refresh
    vim.keymap.set("n", "<F5>", function()
        tree:set_nodes(M.prepare_nodes())
        tree:render()
        M.popup.border:set_text("bottom", " Last updated: " .. os.date("%Y-%m-%d %H:%M:%S") .. " ", "center")
    end, { buffer = M.popup.bufnr })

    -- Select a client
    vim.keymap.set("n", "c", function()
        local current_client = client.name
        client.select_client(function()
            if client.name == current_client then return end
            M.popup:unmount()
            M.popup = nil
            M.open()
        end)
    end, { buffer = M.popup.bufnr })

    -- Move opened file between changelist
    vim.keymap.set("n", "m", function()
        vim.b.__taking_input = true
        local node = tree:get_node()
        if not node then
            vim.b__taking_input = false
            return
        end
        if node.changlist then
            vim.b__taking_input = false
            return
        end
        local current_changelist = node:get_parent_id()
        local depot_file = node.depotFile
        M.move_opened_file(function(value)
            vim.b__taking_input = false
            if value == current_changelist then return end
            if not M.changlists[value] then
                vim.api.nvim_err_writeln("Invalid changelist: " .. value .. ".")
                return
            end
            p4.reopen(depot_file, value)
            tree:set_nodes(M.prepare_nodes())
            tree:render()
            M.popup.border:set_text("bottom", " Last updated: " .. os.date("%Y-%m-%d %H:%M:%S") .. " ", "center")
        end)
    end, { buffer = M.popup.bufnr })

    -- Toggle the expansion of the current node if it is a changelist
    vim.keymap.set("n", "<Space>", function()
        local node = tree:get_node()
        if not node then return end
        if not node.changlist then return end
        if node.empty then return end
        if node:is_expanded() then
            node:collapse()
        else
            node:expand()
        end
        tree:render()
    end, { buffer = M.popup.bufnr, nowait = true })

    -- Open the selected file in the editor
    vim.keymap.set("n", "e", function()
        local node = tree:get_node()
        if not node then return end
        if node.changlist then
            if node.empty then return end
            local children = tree:get_nodes(node:get_id())
            for _, child in ipairs(children) do
                utils.edit_file(child.path)
            end
        else
            utils.edit_file(node.path)
            M.popup:show()
        end
    end, { buffer = M.popup.bufnr, nowait = true })

    -- Hide the popup with 'q' or 'Esc'
    vim.keymap.set("n", "q", function() M.popup:hide() end, { buffer = M.popup.bufnr, nowait = true })
    vim.keymap.set("n", "<Esc>", function() M.popup:hide() end, { buffer = M.popup.bufnr, nowait = true })

end
return M
