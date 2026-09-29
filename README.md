# tiktokenizer.nvim

Floating [Tiktokenizer](https://tiktokenizer.vercel.app) clone for Neovim, built on [nvzone/volt](https://github.com/nvzone/volt).

Left pane = editable input. Right pane = volt-rendered token count + colored tokens. Type `This is the text of the tokenization` and the right side lights up with 8 pastel tokens — same idea as the [dqbd/tiktokenizer](https://github.com/dqbd/tiktokenizer) web UI.

## Features

- Live token preview, debounced (150 ms by default)
- Real BPE via `tiktoken` — `cl100k_base` and `o200k_base`
- Clickable encoding tabs in the header (volt)
- Whitespace visualization toggle
- Graceful fallback to whitespace split when `uv`/network is unavailable

## Requirements

- Neovim 0.10+
- [nvzone/volt](https://github.com/nvzone/volt)
- [`uv`](https://docs.astral.sh/uv/) — `tiktoken` is auto-fetched via `uvx --with tiktoken`, no manual install needed

## Install (lazy.nvim)

```lua
{
  "xshubhamg/tiktokenizer.nvim",
  dependencies = { "nvzone/volt" },
  cmd = { "Tiktokenizer", "TiktokenizerToggle" },
  keys = {
    { "<leader>tt", "<cmd>TiktokenizerToggle<cr>", desc = "Tiktokenizer" },
  },
  opts = {},
}
```

## Usage

`:Tiktokenizer` or `:TiktokenizerToggle` (or `<leader>tt`) to open/close. Type on the **left**, tokens update on the **right**.

| Key | Action |
| --- | ------ |
| `e` | Switch encoding (`cl100k_base` ↔ `o200k_base`) |
| `w` | Toggle whitespace visualization |
| `q` / `<Esc>` | Close |

You can also click an encoding name in the header to switch.

## Setup

```lua
require("tiktokenizer").setup({
  width = 112, -- total width of both floats
  height = 26,
  left_width = 52, -- editable input pane width
  border = "rounded",
  encodings = { "cl100k_base", "o200k_base" },
  default_encoding = "cl100k_base",
  debounce_ms = 150,
  show_whitespace = false,
  -- how python+tiktoken is invoked:
  uv_cmd = { "uvx", "--with", "tiktoken" },
})
```

## How it works

- `python/tokenize.py` runs real BPE (`tiktoken.get_encoding(enc).encode(text)`) and prints `{count, segments: [{text, id}]}` as JSON.
- `lua/tiktokenizer/tokenizer.lua` pipes the input buffer to it asynchronously via `vim.system`, debounced — stale responses are dropped by sequence number.
- `lua/tiktokenizer/layout.lua` + `view.lua` render volt sections (`header`, `count`, `tokens`); each token cycles a pastel highlight (`Tiktok0..7`).
- Two adjacent floats (editable input + volt preview) act as one Tiktokenizer window.

## Roadmap

- Token ID panel (IDs are already returned by the backend, just not shown)
- More encodings / model presets
- Multi-message mode like the web UI
