local client = require("nvim-p4.client")
local utils = require("nvim-p4.utils")

local M = {}

-- Get all pending changelists for the current client
function M.changes()
    local cmd = { "p4", "changes", "-c", client.name, "-s", "pending", "--me" }
    utils.get_output(cmd, function(out)
        local changelists = {}
        table.insert(changelists, { number = "default", description = "" })
        for line in out:gmatch("[^\n]+") do
            local num = line:match("Change (%d+)")
            if num then table.insert(changelists, { number = num, description = M.describe(num) }) end
        end
        return changelists
    end)
end

-- Get one line description of a changelist 
function M.describe(num)
    -- local desc = utils.get_output('p4 -Ztag -F "%desc%" describe -s ' .. num)
    local desc = utils.get_output( {"p4", "-Ztag", "-F", '%desc%', "describe", "-s", num })
    return desc:gsub("%s+", " ")
end

-- Dump file information for a depot file
function M.fstat(depot_file)
    -- local out = utils.get_output("p4 -c " .. client.name .. " fstat -Olhp " .. depot_file)
    local out = utils.get_output( { "p4", "-c", client.name, "fstat" , "-Olhp", depot_file })
    local file = {}
    file.depot_file = depot_file
    -- file.client_file = out:match("... clientFile (%S+)")
    file.path = out:match("... path (%S+)")
    -- file.head_action = out:match("... headAction (%S+)")
    -- file.head_type = out:match("... headType (%S+)")
    file.head_rev = tonumber(out:match("... headRev (%d+)"))
    -- file.head_change = tonumber(out:match("... headChange (%d+)"))
    -- file.have_rev = tonumber(out:match("... haveRev (%d+)"))
    -- file.action = out:match("... action (%S+)")
    -- file.change = out:match("... change (%d+)")
    file.type = out:match("... type (%S+)")
    file.work_rev = tonumber(out:match("... workRev (%d+)"))
    return file
end

-- Display information about the current p4 server
function M.info()
    local cmd = { "p4", "-c", client.name, "info" }
    utils.get_output(cmd, function(out) return out end)
end

-- Get all default / pending changelists for the current client
function M.opened(changelist_number)
    -- local out = utils.get_output("p4 -c " .. client.name .. " opened -c " .. changelist_number)
    local out = utils.get_output({ "p4", "-c", client.name, "opened", "-c" .. changelist_number })
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

-- Get file path from depot file
function M.where(depot_file)
    -- local out = utils.split(utils.get_output("p4 -c " .. client.name .. " where " .. depot_file))
    local out = utils.split(utils.get_output({"p4", "-c", client.name, "where", depot_file } ))
    local path = out[#out]
    return path
end

return M
