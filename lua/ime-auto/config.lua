local M = {}

M.defaults = {
  escape_sequence = "ｋｊ",
  escape_timeout = 200,
  os = "auto",
  ime_method = "builtin",
  custom_commands = {
    on = nil,
    off = nil,
    status = nil,
  },
  debug = false,
}

M.options = {}

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})

  if M.options.os == "auto" then
    M.options.os = M.detect_os()
  end

  if M.options.debug then
    vim.notify("[ime-auto] Config loaded: " .. vim.inspect(M.options), vim.log.levels.DEBUG)
  end
end

function M.detect_os()
  local os_name = vim.loop.os_uname().sysname:lower()
  
  if os_name:match("darwin") then
    return "macos"
  elseif os_name:match("windows") or os_name:match("mingw") then
    return "windows"
  elseif os_name:match("linux") then
    return "linux"
  else
    return "unknown"
  end
end

function M.get()
  return M.options
end


return M