local Popup = require("nui.popup")
local event = require("nui.utils.autocmd").event
local Tree = require("nui.tree")
local Line = require("nui.line")
-- local devicons = require("nvim-web-devicons")
-- local p4 = require("nvim-p4.p4")
local client = require("nvim-p4.client")

local M = {}

-- local function make_changelist_node(cl, status)
--   local icons = {
--     pending = { "", "DiagnosticWarn" },
--     submitted = { "", "DiagnosticOk" },
--     unknown = { "", "DiagnosticError" },
--   }
--   local icon, hl = unpack(icons[status] or icons.unknown)
--   return Tree.Node({ type = "changelist", cl = cl }, {
--     text = icon .. " CL " .. cl,
--     hl = hl,
--   })
-- end
--
-- local function make_file_node(name)
--   local icon, hl = devicons.get_icon(name, name:match("^.+(%..+)$"), { default = true })
--   return Tree.Node({ type = "file", name = name }, {
--     text = "  " .. (icon or "") .. " " .. name,
--     hl = hl or "Normal"
--   })
-- end

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
        border = { style = "rounded", text = { top = "[ Pending Changelists in  " .. client.name .. " ]", top_align = "center" } },
        position = "50%",
        size = { width = 80, height = 25 },
        buf_options = { modifiable = true, readonly = false },
        win_options = { wrap = false }
    })

    local nodes = {}
    for _, num in ipairs(changelist_numbers) do
        local desc = io.popen('p4 -Ztag -F "%desc%" describe -s ' .. num):read("*a")
        local cl_data = {}
        cl_data["id"] = num
        cl_data["text"] = "󰔶 " .. num .. "   " .. desc:gsub("%s+", " ")  

        local children = {}
        for _, file in ipairs(M.get_opened_files(num)) do
            local icon = " "--"󰈔""󰷈"" "
            local child_data = {}
            child_data["id"] = file.depot_file
            child_data["text"] = icon .. file.depot_file .. "#" .. file.rev.. " " .. "<" .. file.type .. ">"

            -- local ext = file.type
            -- if ext == "lua" then icon = ""   
            -- elseif ext == "png" or ext == "jpg" then icon = ""
            -- elseif ext == "svg" then icon = "󰜡"
            -- elseif ext == "json" then icon = ""
            -- elseif ext == "md" then icon = "󰍔"
            -- elseif ext == "ts" then icon = ""
            -- elseif ext == "vim" then icon = ""
            -- elseif  
            -- end

            -- local file_line = Line()
            -- file_line:append(icon .. " " .. file.depot_file .. "#" .. file.rev, "Normal")

            table.insert(children, Tree.Node(child_data))
        end
        table.insert(nodes, Tree.Node(cl_data, children))
    end

    popup:mount()

    local tree = Tree({
        bufnr = popup.bufnr,
        nodes = nodes,
        prepare_node = function(node)
            node:expand()
            local line = Line()
            line:append(string.rep("  ", node:get_depth() - 1))
            if node:has_children() then
                line:append(node:is_expanded() and " " or " ", "SpecialChar")
            else
                line:append("  ")
            end
            line:append(node.text)

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
    vim.keymap.set("n", "<CR>", function()
--        local row = vim.api.nvim_win_get_cursor(popup.winid)[1]
--        local node = tree:get_node(row)
        local node = tree:get_node()
        if not node then return end

        if node:is_expanded() then
            print("node is expanded, collapsing it")
            node:collapse()
        else
            print("node is collapsed, expanding it")
            node:expand()
        end
        tree:render()



        -- if node and node:has_children() then
        --     if node:is_expanded() then
        --         print("node is expanded, collapsing it")
        --         node:collapse()
        --     else
        --         print("node is collapsed, expanding it")
        --         node:expand()
        --     end
        --     tree:render()
        -- end
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
