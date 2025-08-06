local client = require("nvim-p4.client")
local utils = require("nvim-p4.utils")

local function ensure_path(path)
    if not path:match("^("..client.root..")") then
        utils.notify_error("Current file: "..path.." does not in the client.")
        return false
    end
    return true
end

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
    return utils.get_output(cmd)
end

-- Open file in a client for edit
function M.edit(changelist, path)
    if not ensure_path(path) then return end
    local cmd = { "p4", "-c", client.name, "edit", "-c", changelist, path }
    if changelist == nil or changelist == "default" then
        cmd = { "p4", "-c", client.name, "edit", path }
    end
    return utils.get_output(cmd)
end

-- Print detailed information about the revisions of files
function M.filelog(path)
    if not ensure_path(path) then return end
    local cmd = { "p4", "filelog", "-t", "-l", path }
    return utils.get_output(cmd)
end

-- Dump file information for a depot file
function M.fstat(depot_files)
    local fields = { "depotFile", "path", "headRev", "type", "workRev", "haveRev" }
    local cmd = { "p4", "-c", client.name, "fstat", "-T", '"'..table.concat(fields, ",")..'"', "-Olhp" }
    for _, depot_file in ipairs(depot_files) do table.insert(cmd, depot_file) end
    local out = utils.get_output(cmd)
    local files = {}
    for section in out:gmatch("([^\n]+.-)\n\n") do
        local file = {}
        if section:match("... unresolved") then file["unresolved"] = true end
        -- Extract fields from the section
        for _, field in ipairs(fields) do
            local value = section:match("... " .. field .. " (%S+)")
            if value then
                if field == "headRev" or field == "workRev" or field == "haveRev" then
                    file[field] = tonumber(value)
                else
                    file[field] = value
                end
            end
        end
        table.insert(files, file)
    end
    return files
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
    cmd = { "p4", "-c", client.name, "diff", "-sa" }
    for word in out:gmatch("(%S+)#") do
        table.insert(depot_files, word)
        table.insert(cmd, word)
    end
    if #depot_files == 0 then return {} end

    local diff_table = {}
    for i , paths in ipairs(utils.split(utils.get_output(cmd))) do
        diff_table[paths] = i
    end

    local files = M.fstat(depot_files)
    for _, file in ipairs(files) do
        file.differ_from_head = diff_table[file.path] ~= nil
    end
    return files
end

-- Print depot file in a client
function M.print(depot_file)
    local cmd = { "p4", "print", "-q", depot_file }
    return utils.get_output(cmd)
end

-- Move opened files between changelists
function M.reopen(depot_file, changelist_number)
    local cmd = { "p4", "-c", client.name, "reopen", "-c", changelist_number, depot_file }
    return utils.get_output(cmd)
end

-- Revert opened file
function M.revert(depot_file, unchanged_only)
    local cmd = { "p4", "-c", client.name, "revert", depot_file}
    if unchanged_only then
        cmd = { "p4", "-c", client.name, "revert", "-a", depot_file}
    end
    return utils.get_output(cmd)
end

-- Get file path from depot file
function M.where(file, return_syntax)
    local cmd = { "p4", "-c", client.name, "where", file }
    local out = utils.split(utils.get_output(cmd))
    if return_syntax == "depot" then
        return out[1] or ""
    elseif return_syntax == "client" then
        return out[2] or ""
    elseif return_syntax == "local" then
        return out[3] or ""
    else
        utils.notify_error("Invalid return syntax: " .. return_syntax)
    end
end

return M
