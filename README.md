# tiktokenizer.nvim

Floating Tiktokenizer clone for Neovim, built on [nvzone/volt](https://github.com/nvzone/volt).

Left pane = editable input. Right pane = volt-rendered token count + colored tokens (like [tiktokenizer.vercel.app](https://tiktokenizer.vercel.app)).

![screenshot concept](https://github.com/dqbd/tiktokenizer) — same idea: `This is the text of the tokenization` → 8 colored tokens.

## Requirements

- Neovim 0.10+
- [nvzone/volt](https://github.com/nvzone/volt)
- [`uv`](https://docs.astral.sh/uv/) + `tiktoken` (auto-fetched via `uvx --with tiktoken`, no manual install needed)

Without `uv`/network the plugin still opens and falls back to a whitespace split (with a warning).

## Install (lazy.nvim)

```lua
{
  "yourname/tiktokenizer.nvim",
  dependencies = { "nvzone/volt" },
  cmd = { "Tiktokenizer", "TiktokenizerToggle" },
  opts = {},
  keys = {
    { "<leader>tt", "<cmd>TiktokenizerToggle<cr>", desc = "Tokenizer" },
  },
}
```

## Usage

- `:Tiktokenizer` / `:TiktokenizerToggle` — open / close
- Type on the **left**. Right side updates live (debounced).
- `e` — switch encoding (`cl100k_base` ↔ `o200k_base`)
- `w` — toggle whitespace dots
- `q` / `<Esc>` — close
- Click an encoding name in the header to switch (volt clickable).

## Setup

```lua
require("tiktokenizer").setup({
  width = 112,
  height = 26,
  left_width = 52,
  border = "rounded",
  encodings = { "cl100k_base", "o200k_base" },
  default_encoding = "cl100k_base",
  debounce_ms = 150,
  show_whitespace = false,
  uv_cmd = { "uvx", "--with", "tiktoken" }, -- or { "uv", "run", "--with", "tiktoken" }
})
```

## How it works

- `python/tokenize.py` does real BPE via `tiktoken.get_encoding(enc).encode(text)` and returns `{count, segments:[{text,id}]}` as JSON.
- `lua/tiktokenizer/tokenizer.lua` pipes input text to `uvx --with tiktoken python tokenize.py` asynchronously (`vim.system`), debounced.
- `lua/tiktokenizer/layout.lua` + `view.lua` render volt sections (`header`, `count`, `tokens`); each token gets a cycled pastel highlight (`Tiktok0..7`).
- Two adjacent floats (input + volt preview) act as one Tiktokenizer window.

Token IDs are currently hidden (per scope) — only colored segments + count are shown. The python script already returns IDs if you want to add an ID panel later.
