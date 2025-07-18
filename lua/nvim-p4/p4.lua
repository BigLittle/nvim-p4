local client = require("nvim-p4.client")
local utils = require("nvim-p4.utils")

local M = {}


-- Get one line description of a changelist 
function M.describe(num)
    local desc = utils.get_output('p4 -Ztag -F "%desc%" describe -s ' .. num)
    return desc:gsub("%s+", " ")
end

function M.changes()
  local out = utils.get_output("p4 changes -c " .. client.name.. " -s pending --me")
  local changelists = {}
  table.insert(changelists, { number = "default", description = "Default Changelist" })
  for line in out:gmatch("[^\n]+") do
    local num = line:match("Change (%d+)")
    if num then table.insert(changelists, { number = num, description = M.describe(num) }) end
  end
  return changelists

  -- local changelist_numbers = { "default" }
  -- for line in out:gmatch("[^\n]+") do
  --   local num = line:match("Change (%d+)")
  --   if num then table.insert(changelist_numbers, num) end
  -- end
  -- return changelist_numbers
end






-- Dump file information for a depot file
function M.fstat(depot_file)
    local out = utils.get_output("p4 -c " .. client.name .. " fstat -Olhp " .. depot_file)
    local file = {}
    for line in out:gmatch("[^\n]+") do
        if line:match("^... depotFile ") then
            file.depot_file = line:match("^... depotFile (%S+)")
        elseif line:match("^... clientFile ") then
            file.client_file = line:match("^... clientFile (%S+)")
        elseif line:match("^... headAction ") then
            file.head_action = line:match("^... headAction (%S+)")
        elseif line:match("^... headType ") then
            file.head_type = line:match("^... headType (%S+)")
        elseif line:match("^... headRev ") then
            file.head_rev = tonumber(line:match("^... headRev (%d+)"))
        elseif line:match("^... headChange ") then
            file.head_change = tonumber(line:match("^... headChange (%d+)"))
        elseif line:match("^... haveRev ") then
            file.have_rev = tonumber(line:match("^... haveRev (%d+)"))
        elseif line:match("^... action ") then
            file.action = line:match("^... action (%S+)")
        elseif line:match("^... change ") then
            file.change = line:match("^... change (%S+)")
        elseif line:match("^... workRev ") then
            file.work_rev = tonumber(line:match("workRev (%d+)"))
        end
    end
    return file
end

-- Get all default / pending changelists for the current client
function M.opened(changelist_number)
    local out = utils.get_output("p4 -c " .. client.name .. " opened -c " .. changelist_number)
    local files = {}
    for line in out:gmatch("[^\n]+") do
        local depot_file = utils.split(line)[1]:match("(%S+)#")
        if depot_file == "" then return {} end
        local file = M.fstat(depot_file)
        -- file["depot_file"] = result[1]:match("(%S+)#")
        -- file["rev"] = result[1]:match("#(%d+)")
        -- file["action"] = result[3]
        -- file["chnum"] = changelist_number
        -- file["type"] = result[6]:match("%((.-)%)")
        table.insert(files, file)
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
