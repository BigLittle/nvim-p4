local Popup = require("nui.popup")
local event = require("nui.utils.autocmd").event
local Tree = require("nui.tree")
local Line = require("nui.line")
local Icons = require("mini.icons")
local client = require("nvim-p4.client")

local M = { select_node = nil }

local function split(input)
  local t = {}
  for word in input:gmatch("%S+") do
    t[#t+1] = word
  end
  return t
end

local function rstrip(str)
    return str:match("^%s*(.-)%s*$")
end

function M.open_local_file(depot_file)
    local out = split(vim.fn.system("p4 where " .. depot_file))
    local local_file = out[#out]
    if vim.fn.filereadable(local_file) == 0 then
        print("Local file for " .. depot_file .. " does not exist.")
        return
    else
        vim.cmd("keepalt keepjumps edit " .. local_file)
    end
end

function M.get_opened_files(changelist_number)
    local out = vim.fn.system("p4 opened -c " .. changelist_number .. " -C ".. client.name)
    local files = {}
    for line in out:gmatch("[^\n]+") do
        local file = {}
        local result = split(line)
        if #result < 6 then return {} end
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
  local out = vim.fn.system("p4 changes --me -c " .. client.name .. " -s pending")
  local changelist_numbers = { "default" }
  for line in out:gmatch("[^\n]+") do
    local num = line:match("Change (%d+)")
    if num then table.insert(changelist_numbers, num) end
  end
  return changelist_numbers
end

function M.open()
    M.select_node = nil
    print("Opening pending changelists for client: " .. client.name)
    local changelist_numbers = M.get_changelist_numbers()

    local popup = Popup({
        relative = "editor",
        enter = true,
        focusable = true,
        border = {
            style = "rounded",
            text = {
                top = "[ Pending Changelists ]",
                top_align = "center",
                bottom = "  "..client.name.." ",
                bottom_align = "center",
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
        local desc = vim.fn.system('p4 -Ztag -F "%desc%" describe -s ' .. num)
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
    vim.api.nvim_set_hl(popup.ns_id, "Cursor", { bg = "NONE", fg = "NONE" })
    vim.api.nvim_set_hl(popup.ns_id, "lCursor", { bg = "NONE", fg = "NONE" })

    local tree = Tree({
        bufnr = popup.bufnr,
        nodes = nodes,
        prepare_node = function(node)
            if M.select_node == nil then M.select_node = node end
            local text_hl = "Normal"
            if node == M.select_node then text_hl = "Visual" end

            local line = Line()
            line:append(string.rep("  ", node:get_depth() - 1))
            if node.changlist then
                line:append(" ")
                if node.empty then
                    line:append("  ", "EndOfBuffer")
                    line:append("󰔶 ", "MiniIconsCyan")
                else
                    line:append(node:is_expanded() and " " or " ", "SpecialChar")
                    line:append("󰔶 ", "ErrorMsg")
                end
                line:append(rstrip(node.text), text_hl)
            else
                line:append("   ", "EndOfBuffer")
                local icon, hl, is_default = Icons.get("file", node.depot_file)
                line:append(icon.." ", hl)
                line:append(node.depot_file.. " #" .. node.rev .. " " .. "<" .. node.type .. ">", text_hl)
            end
            return line
        end,
    })

    tree:render()

    vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
        buffer = popup.bufnr,
        callback = function()
            local node = tree:get_node()
            if not node then return end
            if M.select_node == node then return end
            M.select_node = node
            tree:render()
        end,
    })

    -- Refresh
    vim.keymap.set("n", "<F5>", function()
        popup:unmount()
        M.open()
    end, { buffer = popup.bufnr })

    -- Select a client
    vim.keymap.set("n", "c", function()
        popup:unmount()
        client.select_client(function()
            M.open()
        end)
    end, { buffer = popup.bufnr })

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
    end, { buffer = popup.bufnr, nowait = true })

    -- Open the selected file in the editor
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

    -- Close the popup with 'q' or 'Esc'
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
