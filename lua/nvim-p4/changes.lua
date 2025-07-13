local Popup = require("nui.popup")
local Tree = require("nui.tree")
local Line = require("nui.line")
local devicons = require("nvim-web-devicons")
local p4 = require("nvim-p4.p4")
local client = require("nvim-p4.client")

local M = {}

local function make_changelist_node(cl, status)
  local icons = {
    pending = { "", "DiagnosticWarn" },
    submitted = { "", "DiagnosticOk" },
    unknown = { "", "DiagnosticError" },
  }
  local icon, hl = unpack(icons[status] or icons.unknown)
  return Tree.Node({ type = "changelist", cl = cl }, {
    text = icon .. " CL " .. cl,
    hl = hl,
  })
end

local function make_file_node(name)
  local icon, hl = devicons.get_icon(name, name:match("^.+(%..+)$"), { default = true })
  return Tree.Node({ type = "file", name = name }, {
    text = "  " .. (icon or "") .. " " .. name,
    hl = hl or "Normal"
  })
end




function M.get_opened_files(changelist_number)
  local out = io.popen("p4 opened -c " .. changelist_number):read("*a")
  local files = {}
  -- The parsing is different for the default changelist
  if changelist_number == "default" then
    for line in out:gmatch("[^\n]+") do
      local file = line:match("%s+(%S+)")
      if file then
        table.insert(files, file)
      end
    end
  else
    for line in out:gmatch("[^\n]+") do
      local file = line:match("%s+(%S+)")
      if file then
        table.insert(files, file)
      end
    end
  end
  return files
end


function M.get_default_changelist()
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
  local popup = Popup({
    enter = true,
    focusable = true,
    border = { style = "rounded", text = { top = "[ Changelists in " .. client.name .. " ]", top_align = "center" } },
    position = "50%",
    size = { width = 80, height = 25 },
    buf_options = { modifiable = false, readonly = true },
  })
  -- local changelists = vim.tbl_flatten({
  --   p4.get_changelists_by_status("pending"),
  --   p4.get_changelists_by_status("submitted"),
  -- })

  -- local nodes = {}
  -- for _, cl in ipairs(changelists) do
  --   local node = make_changelist_node(cl.id, cl.status)
  --   for _, file in ipairs(p4.get_opened_files(cl.id)) do
  --     node:append(make_file_node(file))
  --   end
  --   table.insert(nodes, node)
  -- end

  local tree = Tree(nodes, {
    prepare_node = function(node)
      local line = Line()
      line:append(node.text, node.hl)
      return line
    end,
  })

  popup:mount()
  tree:render(popup.bufnr)

  vim.keymap.set("n", "<CR>", function()
    local node = tree:get_node()
    if node and node.data.type == "file" then
      vim.cmd("edit " .. node.data.name)
    elseif node then
      tree:toggle(node:get_id())
      tree:render(popup.bufnr)
    end
  end, { buffer = popup.bufnr })

  vim.keymap.set("n", "r", function()
    popup:unmount()
    M.open()
  end, { buffer = popup.bufnr })

  vim.keymap.set("n", "c", function()
    popup:unmount()
    client.show_client_selector(function()
      M.open()
    end)
  end, { buffer = popup.bufnr })

  popup:on(event.BufLeave, function() popup:unmount() end)

end

return M
