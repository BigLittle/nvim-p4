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

function M.open()
  local popup = Popup({ ... })
  local changelists = vim.tbl_flatten({
    p4.get_changelists_by_status("pending"),
    p4.get_changelists_by_status("submitted"),
  })

  local nodes = {}
  for _, cl in ipairs(changelists) do
    local node = make_changelist_node(cl.id, cl.status)
    for _, file in ipairs(p4.get_opened_files(cl.id)) do
      node:append(make_file_node(file))
    end
    table.insert(nodes, node)
  end

  local tree = Tree(nodes, {
    prepare_node = function(node)
      local line = Line()
      line:append(node.text, node.hl)
      return line
    end,
  })

  popup:mount()
  tree:render(popup.bufnr)

  -- 快捷鍵：開啟檔案 / 展開 changelist / 換 client / refresh
end

return M
