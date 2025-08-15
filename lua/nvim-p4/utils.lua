local Popup = require("nui.popup")
local M = {}

function M.notify_error(msg)
    vim.notify(msg, vim.log.levels.ERROR)
end

function M.notify_info(msg)
    vim.notify(msg, vim.log.levels.INFO)
end

function M.notify_warning(msg)
    vim.notify(msg, vim.log.levels.WARN)
end

function M.build_revert_map(orig_len, curr_len, diffs)
    local map = {}
    local i1, i2 = 1, 1
    local d = 1
    local current_diff = diffs[d]
    local unpack = table.unpack or unpack
    while i1 <= orig_len and i2 <= curr_len do
        if current_diff and (
                (i1 >= current_diff[1] and i1 < current_diff[1] + current_diff[2]) or
                (i2 >= current_diff[3] and i2 < current_diff[3] + current_diff[4])
            ) then
            local start1, len1, start2, len2 = unpack(current_diff)

            if len1 == 0 and len2 > 0 and i2 >= start2 and i2 < start2 + len2 then
                map[i2] = nil
                i2 = i2 + 1
            elseif len1 > 0 and len2 == 0 and i1 >= start1 and i1 < start1 + len1 then
                i1 = i1 + 1
            elseif len1 > 0 and len2 > 0 and
                i1 >= start1 and i1 < start1 + len1 and
                i2 >= start2 and i2 < start2 + len2 then
                map[i2] = nil
                i1 = i1 + 1
                i2 = i2 + 1
            else
                i1 = i1 + 1
                i2 = i2 + 1
            end
            if i1 >= start1 + len1 and i2 >= start2 + len2 then
                d = d + 1
                current_diff = diffs[d]
            end
        else
            map[i2] = i1
            i1 = i1 + 1
            i2 = i2 + 1
        end
    end
    return map
end

function M.loading()
    local loading_popup = Popup({
        relative = "editor",
        enter = true,
        focusable = false,
        border = { style = "rounded" },
        position = "50%",
        size = { width = 14, height = 1 },
    })
    loading_popup:mount()
    vim.api.nvim_buf_set_lines(loading_popup.bufnr, 0, -1, false, {
        "  Processing ",
    })
    loading_popup:hide()
    return loading_popup
end

M.loading_popup = M.loading()

-- Split a string into a table of words
function M.split(input)
    local t = {}
    for word in input:gmatch("%S+") do
        t[#t + 1] = word
    end
    return t
end

-- Strip trailing whitespace from a string
function M.rstrip(str)
    return str:match("^(.-)%s*$")
end

-- Get the output of a shell command
function M.get_output(cmd)
    local result = vim.system(cmd, { text = true }):wait()
    if result.code ~= 0 then
        M.notify_error("Error executing command: " .. table.concat(cmd, " "))
        return ""
    end
    return result.stdout
end

-- Check if buffer is empty and unmodified
function M.is_empty_unmodified_buffer(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    return vim.api.nvim_buf_is_loaded(bufnr)
        and vim.api.nvim_buf_get_name(bufnr) == ""
        and vim.api.nvim_get_option_value("modifiable", { buf = bufnr })
        and not vim.api.nvim_get_option_value("modified", { buf = bufnr })
        and vim.api.nvim_buf_line_count(bufnr) == 1
        and vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)[1] == ""
end

function M.find_valid_buffer(skip_bufnr)
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if buf ~= skip_bufnr and M.is_empty_unmodified_buffer(buf) then return buf end
    end
    return nil
end

-- Edit a file with the given path
function M.edit_file(path, bufnr)
    if not path or path == "" then
        M.notify_error("No file path provided")
        return
    end
    local abs_path = vim.fn.fnamemodify(path, ":p")
    if not vim.fn.filereadable(abs_path) then
        M.notify_error("File does not exist: " .. abs_path)
        return
    end
    if bufnr ~= nil then vim.api.nvim_set_current_buf(bufnr) end
    vim.cmd("keepalt keepjumps edit " .. abs_path)
end

-- Diff a file with the given depot_file and path
function M.diff_file(depot_file_contents, path)
    vim.cmd("tabnew")
    vim.cmd("vsplit " .. path)
    local filetype = vim.bo.filetype
    vim.cmd("wincmd h")
    local diff_buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_lines(diff_buf, 0, -1, false, depot_file_contents)
    vim.api.nvim_set_option_value("buftype", "nofile", { buf = diff_buf })
    vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = diff_buf })
    vim.api.nvim_set_option_value("swapfile", false, { buf = diff_buf })
    vim.api.nvim_set_option_value("filetype", filetype, { buf = diff_buf })
    vim.api.nvim_set_option_value("modifiable", false, { buf = diff_buf })
    vim.cmd("windo diffthis")
end

return M
