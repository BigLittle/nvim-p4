local Popup = require("nui.popup")
local event = require("nui.utils.autocmd").event
local Tree = require("nui.tree")
local Line = require("nui.line")
local client = require("nvim-p4.client")

local M = { select_node_id = nil }

local function split(input)
  local t = {}
  for word in input:gmatch("%S+") do
    t[#t+1] = word
  end
  return t
end

function M.open_local_file(depot_file)
    local out = split(io.popen("p4 where " .. depot_file):read("*a"))
    local local_file = out[#out]
    if vim.fn.filereadable(local_file) == 0 then
        print("Local file for " .. depot_file .. " does not exist.")
        return
    else
        vim.cmd("edit " .. local_file)
    end
end

function M.get_opened_files(changelist_number)
    local out = io.popen("p4 opened -c " .. changelist_number .. " -C ".. client.name):read("*a")
    local files = {}
    for line in out:gmatch("[^\n]+") do
        local file = {}
        local result = split(line)
        if #result < 6 then return {} end
        file["id"] = result[1] -- use for tree node id
        file["depot_file"] = result[1]:match("(%S+)#")
        file["rev"] = result[1]:match("#(%d+)")
        file["action"] = result[3]
        file["chnum"] = changelist_number
        file["type"] = result[6]:match("%((.-)%)")
        table.insert(files, file)
    end
    return files
end

function M.get_changelist_numbers()
  local out = io.popen("p4 changes --me -c " .. client.name .. " -s pending"):read("*a")
  local changelist_numbers = { "default" }
  for line in out:gmatch("[^\n]+") do
    local num = line:match("Change (%d+)")
    if num then table.insert(changelist_numbers, num) end
  end
  return changelist_numbers
end

function M.update_select_node_id(tree, bufnr)
    local max_row = vim.api.nvim_buf_line_count(bufnr)
    local rc = vim.api.nvim_win_get_cursor(0)
    if rc[1] == max_row then return end
    vim.api.nvim_win_set_cursor(win, { rc[1] + 1, rc[2] })
    M.select_node_id = tree:get_node():get_id()
    tree:render()
end

function M.open()
    local changelist_numbers = M.get_changelist_numbers()
    local cursorline_hl = vim.api.nvim_get_hl_by_name("CursorLine", true)

    local popup = Popup({
        enter = true,
        focusable = true,
        border = {
            style = "rounded",
            text = { 
                top = "[ Pending Changelists ]",
                top_align = "center",
                bottom = "  "..client.name.." ",
                bottom_align = "left",
            },
            padding = { top = 0, bottom = 0, left = 0, right = 1 },
        },
        position = "50%",
        size = { width = 100, height = 25 },
        buf_options = { modifiable = true, readonly = false },
        win_options = { wrap = false },
        ns_id = "nvim_p4_changes",
    })

    local nodes = {}
    for _, num in ipairs(changelist_numbers) do
        local desc = io.popen('p4 -Ztag -F "%desc%" describe -s ' .. num):read("*a")
        local cl_data = {}
        cl_data["id"] = num
        cl_data["text"] = num .. "   " .. desc:gsub("%s+", " ")
        cl_data["changlist"] = true
        cl_data["empty"] = false
        local opened_files = M.get_opened_files(num)
        if not opened_files or #opened_files == 0 then cl_data["empty"] = true end
        local children = {}
        for _, file in ipairs(opened_files) do
            table.insert(children, Tree.Node(file))
        end
        local node = Tree.Node(cl_data, children)
        node:expand() -- Expand the node by default
        table.insert(nodes, node)
    end

    popup:mount()
    vim.api.nvim_set_hl(popup.ns_id, "CursorLine", { bg = "#365a98", fg = "None" })

    local tree = Tree({
        bufnr = popup.bufnr,
        nodes = nodes,
        prepare_node = function(node)
            local line = Line()
            line:append(string.rep("  ", node:get_depth() - 1))
            if node.changlist then
                line:append(" ")
                if node.empty then
                    line:append("  ")
                    line:append("󰔶 ", "MiniIconsCyan")
                else
                    line:append(node:is_expanded() and " " or " ", "SpecialChar")
                    line:append("󰔶 ", "ErrorMsg")
                end
                if node.id == M.select_node_id then
                    print("Selected node: " .. node.id)
                    line:append(node.text, "CursorLine")
                else
                    line:append(node.text, "Normal")
                end
            else
                line:append("   ")
                local ft = node.depot_file:match("^.+(%.[^%.]+)$")
                if ft == ".cpp" or ft == ".hpp" then
                    line:append(" ", "MiniIconsAzure")
                elseif ft == ".py" then
                    line:append(" ", "MiniIconsYellow")
                elseif ft == ".lua" then
                    line:append(" ", "MiniIconsAzure")
                else
                    line:append("󰷈 ")
                end
                if node.id == M.select_node_id then
                    print("Selected node: " .. node.id)
                    line:append(node.depot_file.. "#" .. node.rev .. " " .. "<" .. node.type .. ">", "CursorLine")
                else
                    line:append(node.depot_file.. "#" .. node.rev .. " " .. "<" .. node.type .. ">", "Normal")
                end
            end
            return line
        end,
    })

    tree:render()

    vim.keymap.set("n", "<F5>", function()
        popup:unmount()
        M.open()
    end, { buffer = popup.bufnr })

    vim.keymap.set("n", "c", function()
        popup:unmount()
        client.select_client(function()
            M.open()
        end)
    end, { buffer = popup.bufnr })

    -- Set up key mappings for the popup buffer
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
    end, { buffer = popup.bufnr, nowait = true })

    vim.keymap.set("n", "e", function()
        local node = tree:get_node()
        if not node then return end
        if node.changlist then
            if node.empty then return end
            local children = tree:get_nodes(node:get_id())
            for _, child in ipairs(children) do
                M.open_local_file(child.depot_file)
            end
        else
            M.open_local_file(node.depot_file)
        end
        popup:unmount()
    end, { buffer = popup.bufnr, nowait = true })

    vim.keymap.set("n", "j", function() M.update_select_node_id(tree, popup.bufnr) end, { buffer = popup.bufnr, nowait = true })

    vim.keymap.set("n", "q", function() popup:unmount() end, { buffer = popup.bufnr, nowait = true })
    vim.keymap.set("n", "<Esc>", function() popup:unmount() end, { buffer = popup.bufnr, nowait = true })

    -- Disable horizontal navigation keys
    vim.api.nvim_buf_set_keymap(popup.bufnr, "n", "h", "<Nop>", { noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(popup.bufnr, "n", "l", "<Nop>", { noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(popup.bufnr, "n", "<Left>", "<Nop>", { noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(popup.bufnr, "n", "<Right>", "<Nop>", { noremap = true, silent = true })

    -- Unmount the popup when leaving the buffer
    popup:on(event.BufLeave, function() popup:unmount() end)
end
return M
