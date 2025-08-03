local client = require("nvim-p4.client")
local utils = require("nvim-p4.utils")

local M = {}

-- Animation Popup
local popup_buf = nil
local popup_win = nil
local animation_timer = nil
local frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }

local function start_animation(text)
  popup_buf = vim.api.nvim_create_buf(false, true)
  popup_win = vim.api.nvim_open_win(popup_buf, true, {
    relative = "editor",
    width = 20,
    height = 1,
    row = vim.o.lines / 2,
    col = (vim.o.columns - 20) / 2,
    style = "minimal",
    border = "rounded",
  })

  local frame_index = 1
  animation_timer = vim.loop.new_timer()
  animation_timer:start(0, 150, vim.schedule_wrap(function()
    local frame = frames[frame_index]
    frame_index = (frame_index % #frames) + 1
    vim.api.nvim_buf_set_lines(popup_buf, 0, -1, false, { frame .. " " .. text })
  end))
end

local function stop_animation()
  if animation_timer then
    animation_timer:stop()
    animation_timer:close()
    animation_timer = nil
  end

  if popup_win and vim.api.nvim_win_is_valid(popup_win) then
    vim.api.nvim_win_close(popup_win, true)
  end

  if popup_buf and vim.api.nvim_buf_is_valid(popup_buf) then
    vim.api.nvim_buf_delete(popup_buf, { force = true })
  end
end

function M.run_system(cmd, on_exit)
  start_animation(" Processing...")
  vim.system(cmd, { text = true }, function(obj)
    stop_animation()
    if on_exit then
      on_exit(obj)
    end
  end)
end

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
    if not path:match("^("..client.root..")") then
        utils.notify_error("Current file: "..path.." does not in the client.")
        return
    end
    local cmd = { "p4", "-c", client.name, "edit", "-c", changelist, path }
    if changelist == nil or changelist == "default" then
        cmd = { "p4", "-c", client.name, "edit", path }
    end
    return utils.get_output(cmd)
end

-- Dump file information for a depot file
function M.fstat(depot_files)
    local fields = { "depotFile", "path", "headRev", "type", "workRev" }
    local cmd = { "p4", "-c", client.name, "fstat", "-T", '"'..table.concat(fields, ",")..'"', "-Olhp" }
    for _, depot_file in ipairs(depot_files) do table.insert(cmd, depot_file) end
    local out = utils.get_output(cmd)
    local files = {}
    for section in out:gmatch("([^\n]+.-)\n\n") do
        local file = {}
        -- Extract fields from the section
        for _, field in ipairs(fields) do
            local value = section:match(field .. " (%S+)")
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
        return out[0] or ""
    elseif return_syntax == "client" then
        return out[1] or ""
    elseif return_syntax == "local" then
        return out[2] or ""
    else
        utils.notify_error("Invalid return syntax: " .. return_syntax)
    end
end

return M
