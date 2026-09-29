-- Pastel token highlights, cycled per token index.
-- Same palette idea as tiktokenizer web (light blue / yellow / green / peach ...).
-- Dark fg on pastel bg reads well on both dark and light colorschemes.
local M = {}

M.names = {
  "Tiktok0",
  "Tiktok1",
  "Tiktok2",
  "Tiktok3",
  "Tiktok4",
  "Tiktok5",
  "Tiktok6",
  "Tiktok7",
}

M.palette = {
  { bg = "#BAE6FD" }, -- light blue
  { bg = "#FDE68A" }, -- yellow
  { bg = "#BBF7D0" }, -- green
  { bg = "#FED7AA" }, -- peach
  { bg = "#A5F3FC" }, -- cyan
  { bg = "#E5E7EB" }, -- grey
  { bg = "#F5D0FE" }, -- pink
  { bg = "#DDD6FE" }, -- lavender
}

local FG = "#1C1917"

function M.setup()
  for i, name in ipairs(M.names) do
    vim.api.nvim_set_hl(0, name, { fg = FG, bg = M.palette[i].bg })
  end
  -- helper groups used by layout
  vim.api.nvim_set_hl(0, "TiktokTitle", { bold = true })
  vim.api.nvim_set_hl(0, "TiktokDim", { link = "Comment", default = true })
  vim.api.nvim_set_hl(0, "TiktokActive", { link = "PmenuSel", default = true })
end

function M.for_index(i)
  return M.names[(i % #M.names) + 1]
end

return M
