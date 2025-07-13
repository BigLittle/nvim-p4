local Popup = require("nui.popup")
local event = require("nui.utils.autocmd").event
local Tree = require("nui.tree")
local TreeNode = Tree.Node
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
    print(vim.inspect(changelist_numbers))

    local popup = Popup({
        enter = true,
        focusable = true,
        border = { style = "rounded", text = { top = "[ Pending Changelists ]", top_align = "center" } },
        position = "50%",
        size = { width = 80, height = 25 },
        buf_options = { modifiable = true, readonly = false },
    })
    -- local changelists = vim.tbl_flatten({
    --   p4.get_changelists_by_status("pending"),
    --   p4.get_changelists_by_status("submitted"),
    -- })

    local nodes = {}
    for _, num in ipairs(changelist_numbers) do
        local title = Line()
        local desc = io.popen('p4 -Ztag -F "%desc%" describe -s ' .. num):read("*a")
        title:append("󰄬 " .. num .. " - " .. desc:gsub("%s+", " "), "Identifier")

        -- local node = make_changelist_node(cl.id, cl.status)
        -- for _, file in ipairs(get_opened_files(changelist_numbers)) do


        local children = {}
        for _, file in ipairs(M.get_opened_files(num)) do
            local icon = "󰈔"
            -- local ext = file.type
            -- if ext == "lua" then icon = ""
            -- elseif ext == "png" or ext == "jpg" then icon = ""
            -- elseif ext == "svg" then icon = "󰜡"
            -- elseif ext == "json" then icon = ""
            -- elseif ext == "md" then icon = "󰍔"
            -- elseif ext == "ts" then icon = ""
            -- elseif ext == "vim" then icon = ""
            -- end

            local file_line = Line()
            file_line:append(" " .. icon .. " " .. file.depot_file .. "#" .. file.rev, "Normal")
            table.insert(children, TreeNode(file_line))
        end
        table.insert(nodes, TreeNode(title, children))


--            node:append(make_file_node(file))
--        end
        -- table.insert(nodes, node)
    end

  -- local tree = Tree(nodes, {
  --   prepare_node = function(node)
  --     local line = Line()
  --     line:append(node.text, node.hl)
  --     return line
  --   end,
  -- })

    popup:mount()
    local icon = "  "
    vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, false, { icon .. client.name, string.rep("─", 78) })
  -- tree:render(popup.bufnr)

  -- vim.keymap.set("n", "<CR>", function()
  --   local node = tree:get_node()
  --   if node and node.data.type == "file" then
  --     vim.cmd("edit " .. node.data.name)
  --   elseif node then
  --     tree:toggle(node:get_id())
  --     tree:render(popup.bufnr)
  --   end
  -- end, { buffer = popup.bufnr })


  -- vim.keymap.set("n", "r", function()
  --   popup:unmount()
  --   M.open()
  -- end, { buffer = popup.bufnr })
  --
  -- vim.keymap.set("n", "c", function()
  --   popup:unmount()
  --   client.show_client_selector(function()
  --     M.open()
  --   end)
  -- end, { buffer = popup.bufnr })

    -- Set up key mappings for the popup buffer
    vim.api.nvim_buf_set_keymap(popup.bufnr, "n", "<Esc>", popup:unmount(), { noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(popup.bufnr, "n", "q", popup:unmount(), { noremap = true, silent = true })

    -- Disable horizontal navigation keys
    vim.api.nvim_buf_set_keymap(popup.bufnr, "n", "h", "<Nop>", { noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(popup.bufnr, "n", "l", "<Nop>", { noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(popup.bufnr, "n", "<Left>", "<Nop>", { noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(popup.bufnr, "n", "<Right>", "<Nop>", { noremap = true, silent = true })

    -- Unmount the popup when leaving the buffer
    popup:on(event.BufLeave, function() popup:unmount() end)
end
return M
