local client = require("nvim-p4.client")
local utils = require("nvim-p4.utils")

local M = {}

-- Get all pending changelists for the current client
function M.changes()
    local cmd = { "p4", "changes", "-c", client.name, "-s", "pending", "--me" }
    local out = utils.get_output(cmd)
    local changelists = {}
    table.insert(changelists, { number = "default", description = "" })
    for line in out:gmatch("[^\n]+") do
        local num = line:match("Change (%d+)")
        if num then table.insert(changelists, { number = num, description = M.describe(num) }) end
    end
    return changelists
end

-- Get one line description of a changelist 
function M.describe(num)
    local cmd = { "p4", "-Ztag", "-F", '%desc%', "describe", "-s", num }
    return utils.get_output(cmd):gsub("%s+", " ")
end

-- Dump file information for a depot file
function M.fstat(depot_files)
    local fields = { "depotFile", "path", "headRev", "type", "workRev" }
    local cmd = { "p4", "-c", client.name, "fstat", "-T", '"'..table.concat(fields, ",")..'"', "-Olhp", table.concat(depot_files, " ") }
    local out = utils.get_output(cmd)
    local files = {}
    for section in out:gmatch("([^\n]+.-)\n\n") do
        local file = {}
        print(vim.inspect(section))
        -- Extract fields from the section
        for _, field in ipairs(fields) do
            local value = section:match(field .. ": (%S+)")
            if value then
                if field == "headRev" or field == "workRev" then
                    file[field] = tonumber(value)
                else
                    file[field] = value
                end
            end
        end
        table.insert(files, file)
    end
    return files

    -- local file = {}
    -- file.depot_file = depot_file
    -- -- file.client_file = out:match("... clientFile (%S+)")
    -- file.path = out:match("... path (%S+)")
    -- -- file.head_action = out:match("... headAction (%S+)")
    -- -- file.head_type = out:match("... headType (%S+)")
    -- file.head_rev = tonumber(out:match("... headRev (%d+)"))
    -- -- file.head_change = tonumber(out:match("... headChange (%d+)"))
    -- -- file.have_rev = tonumber(out:match("... haveRev (%d+)"))
    -- -- file.action = out:match("... action (%S+)")
    -- -- file.change = out:match("... change (%d+)")
    -- file.type = out:match("... type (%S+)")
    -- file.work_rev = tonumber(out:match("... workRev (%d+)"))
    -- return file
end

-- Display information about the current p4 server
function M.info()
    local cmd = { "p4", "-c", client.name, "info" }
    return utils.get_output(cmd)
end

-- Get all default / pending changelists for the current client
function M.opened(changelist_number)
    local cmd = { "p4", "-c", client.name, "opened", "-c" .. changelist_number }
    local out = utils.get_output(cmd)
    local depot_files = {}

    -- Check if the depot file is different from the head revision
    cmd = { "p4", "-c", client.name, "diff", "-sa",  }
    for word in out:gmatch("(%S+)#") do
        table.insert(depot_files, word)
        table.insert(cmd, word)
    end
    local diff_table = {}
    for i , paths in ipairs(utils.split(utils.get_output(cmd))) do
        diff_table[paths] = i
    end

    local files = M.fstat(depot_files)
    print(vim.inspect(files))
    for _, file in ipairs(files) do
        file.differ_from_head = diff_table[file.depotFile] ~= nil
    end

    -- local files = {}
    -- for _, depot_file in ipairs(depot_files) do
    --     local file = M.fstat(depot_file)
    --     file.differ_from_head = diff_table[file.path] ~= nil
    --     table.insert(files, file)
    -- end
    return files
end

-- Get file path from depot file
function M.where(depot_file)
    local cmd = { "p4", "-c", client.name, "where", depot_file }
    local out = utils.split(utils.get_output(cmd))
    return out[#out]
end

return M
