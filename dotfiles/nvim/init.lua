
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Set to true if you have a Nerd Font installed and selected in the terminal
vim.g.have_nerd_font = true

vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0

require 'options'

require 'keymaps'

vim.lsp.log.set_level("warn")

require("lazy.lazy")

require("numconv").setup()
require("gtags_db").setup()
require("lsp_fallback").setup()


-- TODO:
-- Set keybinding to jump around luasnip fields

-- treesitter add more treesitter functions
-- Add shortcuts to quiz for telescope
-- Build multigrep advanced telescope tutorial
-- Make own telescope tool
-- Explore and setup HARPOON


-- Quickfix list seems to be juicy
