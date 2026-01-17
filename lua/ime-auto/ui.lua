local M = {}

local current_float = nil
local current_prompt_buf = nil

function M.close_float()
  if current_float and vim.api.nvim_win_is_valid(current_float) then
    vim.api.nvim_win_close(current_float, true)
  end
  if current_prompt_buf and vim.api.nvim_buf_is_valid(current_prompt_buf) then
    vim.api.nvim_buf_delete(current_prompt_buf, { force = true })
  end
  current_float = nil
  current_prompt_buf = nil
end

function M.create_centered_float(lines, width, height)
  local buf = vim.api.nvim_create_buf(false, true)

  local ui = vim.api.nvim_list_uis()[1]
  local win_width = ui.width
  local win_height = ui.height

  local row = math.floor((win_height - height) / 2)
  local col = math.floor((win_width - width) / 2)

  local opts = {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = 'rounded',
  }

  local win = vim.api.nvim_open_win(buf, false, opts)

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)
  vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')

  vim.api.nvim_win_set_option(win, 'winhl', 'Normal:Normal,FloatBorder:FloatBorder')

  return win, buf
end

function M.select_from_list(title, items, callback)
  M.close_float()

  local max_item_length = 0
  for i, item in ipairs(items) do
    local display = string.format("%d. %s", i, item.name)
    max_item_length = math.max(max_item_length, #display)
  end

  local width = math.max(50, math.min(80, max_item_length + 4))
  local height = math.min(20, #items + 4)

  local current_idx = 1

  local function render_list()
    local lines = {
      title,
      "",
      "j/k: Navigate | Enter: Select | ESC: Cancel",
      ""
    }

    for i, item in ipairs(items) do
      local prefix = i == current_idx and "► " or "  "
      table.insert(lines, string.format("%s%d. %s", prefix, i, item.name))
    end

    return lines
  end

  local lines = render_list()
  local win, buf = M.create_centered_float(lines, width, height)
  current_float = win
  current_prompt_buf = buf

  local ns_id = vim.api.nvim_create_namespace('ime_auto_select')

  local function update_display()
    local lines = render_list()
    vim.api.nvim_buf_set_option(buf, 'modifiable', true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(buf, 'modifiable', false)

    vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)

    local highlight_line = current_idx + 3
    vim.api.nvim_buf_add_highlight(buf, ns_id, 'Visual', highlight_line, 0, -1)
  end

  local function move_down()
    current_idx = math.min(current_idx + 1, #items)
    update_display()
  end

  local function move_up()
    current_idx = math.max(current_idx - 1, 1)
    update_display()
  end

  local function on_key(key)
    if key == "\27" then
      M.close_float()
      callback(nil)
      return true
    elseif key == "j" or key == "\14" then
      move_down()
      return true
    elseif key == "k" or key == "\16" then
      move_up()
      return true
    elseif key == "\r" then
      M.close_float()
      callback(current_idx)
      return true
    end
    return false
  end

  update_display()

  vim.schedule(function()
    if not vim.api.nvim_win_is_valid(win) then return end

    local function get_input()
      while current_float and vim.api.nvim_win_is_valid(current_float) do
        vim.cmd('redraw')
        local ok, char = pcall(vim.fn.getchar)
        if not ok then break end

        local key
        if type(char) == "number" then
          key = vim.fn.nr2char(char)
        else
          key = char
        end

        if not on_key(key) then
          break
        end

        if not current_float or not vim.api.nvim_win_is_valid(current_float) then
          break
        end
      end
    end

    local ok = pcall(get_input)
    if not ok then
      M.close_float()
    end
  end)
end

return M
