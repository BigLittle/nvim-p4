local Popup = require("nui.popup")
local event = require("nui.utils.autocmd").event
local Tree = require("nui.tree")
local Line = require("nui.line")
local client = require("nvim-p4.client")

local M = {}

local function split(input)
  local t = {}
  for word in input:gmatch("%S+") do
    t[#t+1] = word
  end
  return t
end

function M.get_opened_files(changelist_number)
    local out = io.popen("p4 opened -c " .. changelist_number):read("*a")
    local files = {}
    for line in out:gmatch("[^\n]+") do
        local file = {}
        local result = split(line)
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

function M.open()
    local changelist_numbers = M.get_changelist_numbers()

    local popup = Popup({
        enter = true,
        focusable = true,
        border = {
            style = "rounded",
            text = { top = "[ Pending Changelists in  " .. client.name .. " ]", top_align = "center" },
            padding = { top = 0, bottom = 0, left = 0, right = 1 },
        },
        position = "50%",
        size = { width = 100, height = 25 },
        buf_options = { modifiable = true, readonly = false },
        win_options = { wrap = false }
    })

    local nodes = {}
    for _, num in ipairs(changelist_numbers) do
        local desc = io.popen('p4 -Ztag -F "%desc%" describe -s ' .. num):read("*a")
        local cl_data = {}
        cl_data["id"] = num
        cl_data["text"] = num .. "   " .. desc:gsub("%s+", " ")
        local children = {}
        for _, file in ipairs(M.get_opened_files(num)) do
            table.insert(children, Tree.Node(file))
        end
        local node = Tree.Node(cl_data, children)
        -- node:expand() -- Expand the node by default
        table.insert(nodes, node)
    end

    popup:mount()

    local tree = Tree({
        bufnr = popup.bufnr,
        nodes = nodes,
        prepare_node = function(node)
            local line = Line()
            line:append(string.rep("  ", node:get_depth() - 1))
            if node:has_children() then
                line:append(" ")
                line:append(node:is_expanded() and " " or " ", "SpecialChar")
                line:append("󰔶 ", "ErrorMsg")
                line:append(node.text)
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
                line:append(node.depot_file.. "#" .. node.rev .. " " .. "<" .. node.type .. ">", "Normal")
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
        if node:has_children() then
            if node:is_expanded() then
                node:collapse()
            else
                node:expand()
            end
            tree:render()
        else
            -- Open the file in a new buffer
            local out = split(io.popen("p4 where "..node.depot_file):read("*a"))
            print(vim.inspect(out))
            local local_file = out[#out]
            vim.cmd("edit " .. local_file)
            popup:unmount()
        end
    end, { buffer = popup.bufnr, nowait = true })

    vim.keymap.set("n", "O", function()
        local node = tree:get_node()
        if not node then return end
        if not node:has_children() then return end
        local children = tree:get_nodes(node:get_id())
        local cmd = "edit "
        for _, child in ipairs(children) do
            local out = split(io.popen("p4 where " .. child.depot_file):read("*a"))
            if out and #out > 0 then
                local local_file = out[#out]
                cmd = cmd .. local_file .. " "
            else
                print("Local file of " .. child.depot_file .. " not found.")
            end
        end
        print("Executing command: " .. cmd)
        vim.cmd(cmd)
        popup:unmount()
    end, { buffer = popup.bufnr, nowait = true })

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
