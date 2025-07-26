local Popup = require("nui.popup")
local M = {}

function M.notify_error(msg)
    vim.notify(msg, vim.log.levels.ERROR)
end

function M.notify_warning(msg)
    vim.notify(msg, vim.log.levels.WARN)
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
        t[#t+1] = word
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
        vim.api.nvim_err_writeln("Error executing command: " .. table.concat(cmd, " "))
        return ""
    end
    return result.stdout
end

-- Check if buffer is empty and unmodified
function M.is_empty_unmodified_buffer(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    return vim.api.nvim_buf_is_loaded(bufnr)
        and vim.api.nvim_buf_get_name(bufnr) == ""
        and not vim.api.nvim_buf_get_option(bufnr, "modified")
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
    vim.cmd.edit(abs_path)
end

return M
