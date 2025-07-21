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
        enter = false,
        focusable = false,
        border = { style = "rounded" },
        position = "50%",
        size = { width = 18, height = 1 },
    })
    loading_popup:mount()
    vim.api.nvim_buf_set_lines(loading_popup.bufnr, 0, -1, false, {
        "  Processing ... ",
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
    -- M.loading_popup:show()
    local result = vim.system(cmd, { text = true }):wait()
    -- M.loading_popup:hide()
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

-- Edit a file with the given path
function M.edit_file(path)
    if not path or path == "" then
        vim.api.nvim_err_writeln("No file path provided")
        return
    end
    local abs_path = vim.fn.fnamemodify(path, ":p")
    if not vim.fn.filereadable(abs_path) then
        vim.api.nvim_err_writeln("File does not exist: " .. abs_path)
        return
    end

    -- Open file in an empty and unmodified buffer if possible
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if M.is_empty_unmodified_buffer(buf) then
            vim.api.nvim_set_current_buf(buf)
            vim.cmd("keepalt keepjumps edit " .. abs_path)
            return
        end
    end
    vim.cmd("keepalt keepjumps edit " .. abs_path)
end


return M
