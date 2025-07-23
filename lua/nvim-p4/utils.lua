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

    -- -- Open file in an empty and unmodified buffer if possible
    -- for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    --     if M.is_empty_unmodified_buffer(buf) then
    --         vim.api.nvim_set_current_buf(buf)
    --         vim.cmd("keepalt keepjumps edit " .. abs_path)
    --         return
    --     end
    -- end
    -- vim.cmd("keepalt keepjumps edit " .. abs_path)
end








local ns = vim.api.nvim_create_namespace("async_popup_anim")
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

  vim.system(cmd, {}, function(obj)
    stop_animation()
    if on_exit then
      on_exit(obj)
    end
  end)
end

return M
