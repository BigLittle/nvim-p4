local Popup = require("nui.popup")
local event = require("nui.utils.autocmd").event
local Tree = require("nui.tree")
local Line = require("nui.line")
local Icons = require("mini.icons")
local client = require("nvim-p4.client")
local utils = require("nvim-p4.utils")
local p4 = require("nvim-p4.p4")

local M = {}
M.popup = nil
M.select_node = nil

-- Prepare nodes for the tree view
function M.prepare_nodes()
    M.select_node = nil
    local nodes = {}
    for _, changelist in ipairs(p4.changes()) do
        local cl_data = {}
        cl_data["id"] = changelist.number
        cl_data["text"] = changelist.number .. "   " .. changelist.description
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
                    line:append("󰔶 ", "MiniIconsCyan")
                else
                    line:append(node:is_expanded() and " " or " ", "SpecialChar")
                    line:append("󰔶 ", "ErrorMsg")
                end
                line:append(utils.rstrip(node.text), text_hl)
            else
                line:append("  ", "P4ChangesHead")
                local icon, hl, _ = Icons.get("file", node.depot_file)
                if not icon then
                    icon = "󰈙 " -- Default icon if not found
                    hl = "Normal"
                else
                  line:append(icon.." ", hl)
                end
                if node.work_rev == node.head_rev then
                    line:append("󰄲 ", "MiniIconsGreen")
                else
                    line:append(" ", "MiniIconsYellow")
                end
                line:append(node.depot_file.. " #" .. node.work_rev .. "/" .. node.head_rev .. " <" .. node.type .. ">", text_hl)
            end
            return line
        end,
    })

    tree:render()

    -- Hide the popup when leaving the buffer
    M.popup:on(event.BufLeave, function() M.popup:hide() end)

    -- Highlight the current node
    M.popup:on({ event.CursorMoved, event.CursorMovedI }, function()
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

    -- Toggle the expansion of the current node if it is a changelist
    vim.keymap.set("n", "o", function()
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
        end
        M.popup:hide()
    end, { buffer = M.popup.bufnr, nowait = true })

    -- Hide the popup with 'q' or 'Esc'
    vim.keymap.set("n", "q", function() M.popup:hide() end, { buffer = M.popup.bufnr, nowait = true })
    vim.keymap.set("n", "<Esc>", function() M.popup:hide() end, { buffer = M.popup.bufnr, nowait = true })

    -- Disable horizontal navigation keys
    vim.api.nvim_buf_set_keymap(M.popup.bufnr, "n", "h", "<Nop>", { noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(M.popup.bufnr, "n", "l", "<Nop>", { noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(M.popup.bufnr, "n", "<Left>", "<Nop>", { noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(M.popup.bufnr, "n", "<Right>", "<Nop>", { noremap = true, silent = true })

end
return M
