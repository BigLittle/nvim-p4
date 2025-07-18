local M = {}

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
  local out = io.popen(cmd)
  -- local out = vim.fn.system(cmd)
  if not out then return "" end
  local result = out:read("*a")
  out:close()
  return result
end

return M
