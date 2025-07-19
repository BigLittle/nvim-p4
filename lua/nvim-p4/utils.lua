local Popup = require("nui.popup")
local M = {}

function M.loading()
    local loading_popup = Popup({
        relative = "editor",
        enter = false,
        focusable = false,
        border = { style = "rounded" },
        position = "50%",
        size = { width = 20, height = 3 },
    })
    loading_popup:mount()
    print(vim.inspect(loading_popup.bufnr))

    -- animation setup
    local frames = { "⠋", "⠙", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
    local frame_index = 1
    local timer = vim.loop.new_timer()
    timer:start(0, 150, vim.schedule_wrap(function()
        if loading_popup.bufnr then
            vim.api.nvim_buf_set_lines(loading_popup.bufnr, 0, -1, false, {
                " " .. frames[frame_index] .. " Processing ... ",
            })
        end
        frame_index = (frame_index % #frames) + 1
    end))
    return { loading_popup, timer }
end

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
    local popup, timer = M.loading()
    local handle = vim.system(cmd, { text = true })
    local result = handle:wait()
    timer:stop()
    popup:unmount()
    if result.code ~= 0 then
        vim.api.nvim_err_writeln("Error executing command: " .. cmd)
        return ""
    end
    return result.stdout

    -- local handle = vim.system(cmd, { text = true })
    -- local result = handle:wait()
    -- if result.code ~= 0 then
    --     vim.api.nvim_err_writeln("Error executing command: " .. cmd)
    --     return ""
    -- end
    -- return result.stdout
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
    vim.cmd("keepalt keepjumps edit " .. abs_path)
end


return M
