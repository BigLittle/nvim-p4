local function get_output(cmd)
  local out = io.popen(cmd)
  if not out then return "" end
  local result = out:read("*a")
  out:close()
  return result
end

local M = {}

function M.get_changelists_by_status(status)
  local lines = {}
  local out = get_output("p4 changes -s " .. status)
  for line in out:gmatch("[^\r\n]+") do
    local cl = line:match("Change (%d+)")
    if cl then table.insert(lines, { id = cl, status = status }) end
  end
  return lines
end

function M.get_opened_files(cl)
  local out = get_output("p4 opened -c " .. cl)
  local files = {}
  for line in out:gmatch("[^\r\n]+") do
    local f = line:match("//[^#]+")
    if f then table.insert(files, f) end
  end
  return files
end



-- function M.run(cmd)
--     local handle = io.popen("p4 " .. cmd)
--     if handle == nil then
--         vim.api.nvim_err_writeln("Failed to execute p4 command")
--         return
--     end
--
--     local result = handle:read("*a")
--     handle:close()
--
--     vim.api.nvim_echo({ { result, "Normal" } }, false, {})
--
-- end

return M
