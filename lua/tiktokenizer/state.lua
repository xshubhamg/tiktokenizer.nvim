-- tiktokenizer.nvim runtime state (single instance)
local M = {
  open = false,
  input_buf = nil,
  view_buf = nil,
  input_win = nil,
  view_win = nil,
  oldwin = nil,
  ns = nil,
  encoding = "cl100k_base",
  view_w = 50,
  tokens = { count = 0, segments = {} }, -- segments: { {text=..., id=...}, ... }
  timer = nil,
  job = nil,
  seq = 0, -- request sequence, drop stale responses
  augroup = nil,
}

function M.reset()
  M.open = false
  M.input_buf = nil
  M.view_buf = nil
  M.input_win = nil
  M.view_win = nil
  M.oldwin = nil
  M.ns = nil
  M.tokens = { count = 0, segments = {} }
  if M.timer then
    pcall(vim.uv.close, M.timer)
    M.timer = nil
  end
  M.job = nil
  M.seq = 0
end

return M
