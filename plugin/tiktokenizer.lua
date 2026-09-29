if vim.g.loaded_tiktokenizer then
  return
end
vim.g.loaded_tiktokenizer = 1

vim.api.nvim_create_user_command("Tiktokenizer", function()
  require("tiktokenizer").toggle()
end, { desc = "Toggle tiktokenizer.nvim floating tokenizer" })

vim.api.nvim_create_user_command("TiktokenizerToggle", function()
  require("tiktokenizer").toggle()
end, { desc = "Toggle tiktokenizer.nvim floating tokenizer" })
