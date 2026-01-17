local M = {}

M.defaults = {
  escape_sequence = "ｋｊ",
  escape_timeout = 200,
  os = "auto",
  ime_method = "builtin",
  macos_ime_tool = nil, -- nil (default: osascript), "macime", "macism", or "im-select"
  macos_input_source_en = "com.apple.keylayout.ABC", -- English input source ID (used when IME off)
  macos_input_source_ja = nil, -- Japanese input source ID (required for macism/im-select, optional for macime)
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

  -- Auto-load saved input source configuration
  local ok, msg = M.load_input_sources()
  if ok and M.options.debug then
    vim.notify("[ime-auto] " .. msg, vim.log.levels.DEBUG)
  end

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

function M.set_input_source_en(source_id)
  M.options.macos_input_source_en = source_id
end

function M.set_input_source_ja(source_id)
  M.options.macos_input_source_ja = source_id
end

-- Get config file path
local function get_config_file_path()
  return vim.fn.stdpath('data') .. '/ime-auto.json'
end

-- Save input source configuration to file
function M.save_input_sources()
  local config_file = get_config_file_path()
  local data = {
    macos_input_source_en = M.options.macos_input_source_en,
    macos_input_source_ja = M.options.macos_input_source_ja,
  }

  local json_str = vim.fn.json_encode(data)
  local file = io.open(config_file, 'w')
  if file then
    file:write(json_str)
    file:close()
    return true, config_file
  else
    return false, "Failed to open file for writing"
  end
end

-- Load input source configuration from file
function M.load_input_sources()
  local config_file = get_config_file_path()
  local file = io.open(config_file, 'r')
  if not file then
    return false, "Config file not found"
  end

  local content = file:read('*a')
  file:close()

  local ok, data = pcall(vim.fn.json_decode, content)
  if not ok or type(data) ~= 'table' then
    return false, "Invalid JSON in config file"
  end

  if data.macos_input_source_en then
    M.options.macos_input_source_en = data.macos_input_source_en
  end
  if data.macos_input_source_ja then
    M.options.macos_input_source_ja = data.macos_input_source_ja
  end

  return true, "Loaded from " .. config_file
end

return M