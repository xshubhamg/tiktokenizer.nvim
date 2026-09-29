-- tiktokenizer.nvim default configuration
local M = {}

M.defaults = {
  -- total UI size (two floats side by side)
  width = 112,
  height = 26,
  left_width = 52, -- editable input pane
  border = "rounded",
  -- encodings (tabs in header). Must match tiktoken names.
  encodings = { "cl100k_base", "o200k_base" },
  default_encoding = "cl100k_base",
  debounce_ms = 150,
  show_whitespace = false,
  -- how to invoke python+tiktoken. { "uvx", "--with", "tiktoken" }
  -- override if you use `uv run` or a venv python.
  uv_cmd = { "uvx", "--with", "tiktoken" },
  placeholder = "This is the text of the tokenization",
}

M.options = vim.deepcopy(M.defaults)

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
  return M.options
end

return M
