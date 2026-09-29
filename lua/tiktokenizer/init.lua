-- tiktokenizer.nvim — floating Tiktokenizer clone built on volt.
local config = require("tiktokenizer.config")
local state = require("tiktokenizer.state")

local M = {}

function M.setup(opts)
  config.setup(opts)
  state.encoding = config.options.default_encoding
end

local function has_volt()
  local ok, _ = pcall(require, "volt")
  if not ok then
    vim.notify("[tiktokenizer] missing dependency: nvzone/volt", vim.log.levels.ERROR)
    return false
  end
  return true
end

function M.is_open()
  return state.open
    and state.view_win
    and vim.api.nvim_win_is_valid(state.view_win)
end

function M.close()
  if not state.open then
    return
  end
  local vols_ok, volt_utils = pcall(require, "volt.utils")
  if vols_ok then
    local bufs = {}
    if state.view_buf then
      table.insert(bufs, state.view_buf)
    end
    if state.input_buf then
      table.insert(bufs, state.input_buf)
    end
    -- volt.utils.close deletes buffers + runs after_close; guard each step
    pcall(volt_utils.close, {
      bufs = bufs,
      after_close = function() end,
    })
  else
    for _, b in ipairs({ state.view_buf, state.input_buf }) do
      if b and vim.api.nvim_buf_is_valid(b) then
        pcall(vim.api.nvim_buf_delete, b, { force = true })
      end
    end
  end
  if state.augroup then
    pcall(vim.api.nvim_del_augroup_by_id, state.augroup)
    state.augroup = nil
  end
  local old = state.oldwin
  state.reset()
  if old and vim.api.nvim_win_is_valid(old) then
    pcall(vim.api.nvim_set_current_win, old)
  end
end

function M.toggle_encoding()
  local encs = config.options.encodings
  if #encs < 2 then
    return
  end
  local idx = 1
  for i, e in ipairs(encs) do
    if e == state.encoding then
      idx = i
      break
    end
  end
  state.encoding = encs[(idx % #encs) + 1]
  local ok, volt = pcall(require, "volt")
  if ok and state.view_buf then
    pcall(volt.redraw, state.view_buf, { "header", "count" })
  end
  require("tiktokenizer.tokenizer").request_now()
end

function M.toggle_whitespace()
  config.options.show_whitespace = not config.options.show_whitespace
  local ok, volt = pcall(require, "volt")
  if ok and state.view_buf then
    pcall(volt.redraw, state.view_buf, { "tokens" })
  end
  vim.notify("[tiktokenizer] show_whitespace=" .. tostring(config.options.show_whitespace))
end

function M.open()
  if M.is_open() then
    M.close()
    return
  end
  if not has_volt() then
    return
  end
  if state.open then
    M.close()
  end

  local volt = require("volt")
  require("tiktokenizer.highlights").setup()

  state.oldwin = vim.api.nvim_get_current_win()
  state.encoding = state.encoding or config.options.default_encoding

  local total_w = config.options.width
  local total_h = config.options.height
  local left_w = config.options.left_width
  local right_w = total_w - left_w - 1
  state.view_w = right_w - 4 -- padding + border

  local row = math.max(0, math.floor((vim.o.lines - total_h) / 2 - 1))
  local col = math.max(0, math.floor((vim.o.columns - total_w) / 2))
  local border = config.options.border

  -- buffers
  state.input_buf = vim.api.nvim_create_buf(false, true)
  state.view_buf = vim.api.nvim_create_buf(false, true)
  state.ns = vim.api.nvim_create_namespace("Tiktokenizer")

  vim.bo[state.input_buf].buftype = "nofile"
  vim.bo[state.input_buf].bufhidden = "wipe"
  vim.bo[state.input_buf].swapfile = false
  vim.bo[state.input_buf].filetype = "markdown"
  vim.bo[state.view_buf].bufhidden = "wipe"

  -- placeholder text like the web UI
  vim.api.nvim_buf_set_lines(state.input_buf, 0, -1, false, vim.split(config.options.placeholder, "\n"))

  -- volt data for the right pane
  volt.gen_data({
    { buf = state.view_buf, layout = require("tiktokenizer.layout").layout(), xpad = 2, ns = state.ns },
  })
  local h = require("volt.state")[state.view_buf].h
  local view_h = math.max(total_h, h + 2)

  -- left: editable input
  state.input_win = vim.api.nvim_open_win(state.input_buf, true, {
    relative = "editor",
    row = row,
    col = col,
    width = left_w,
    height = view_h,
    style = "minimal",
    border = border,
    title = { { " Input ", "TiktokActive" } },
    title_pos = "center",
  })
  -- right: volt preview
  state.view_win = vim.api.nvim_open_win(state.view_buf, true, {
    relative = "editor",
    row = row,
    col = col + left_w + 1,
    width = right_w,
    height = view_h,
    style = "minimal",
    border = border,
    title = { { " Tiktokenizer ", "TiktokActive" } },
    title_pos = "center",
  })

  vim.wo[state.input_win].wrap = true
  vim.wo[state.input_win].linebreak = true
  vim.wo[state.input_win].cursorline = true
  vim.wo[state.view_win].wrap = false

  volt.run(state.view_buf, { h = view_h, w = right_w })
  require("volt.events").add(state.view_buf)

  volt.mappings({
    bufs = { state.input_buf, state.view_buf },
    after_close = function()
      local old = state.oldwin
      state.reset()
      if old and vim.api.nvim_win_is_valid(old) then
        pcall(vim.api.nvim_set_current_win, old)
      end
    end,
  })

  -- per-window keys
  for _, b in ipairs({ state.input_buf, state.view_buf }) do
    vim.keymap.set("n", "e", function()
      M.toggle_encoding()
    end, { buffer = b, desc = "Tiktokenizer: switch encoding" })
    vim.keymap.set("n", "w", function()
      M.toggle_whitespace()
    end, { buffer = b, desc = "Tiktokenizer: toggle whitespace" })
  end

  -- live re-tokenize on edit
  state.augroup = vim.api.nvim_create_augroup("Tiktokenizer", { clear = true })
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "TextChangedP", "InsertLeave" }, {
    group = state.augroup,
    buffer = state.input_buf,
    callback = function()
      require("tiktokenizer.tokenizer").request()
    end,
  })

  state.open = true

  -- focus input for typing, kick off first tokenize
  vim.api.nvim_set_current_win(state.input_win)
  require("tiktokenizer.tokenizer").request_now()
end

function M.toggle()
  if M.is_open() then
    M.close()
  else
    M.open()
  end
end

return M
