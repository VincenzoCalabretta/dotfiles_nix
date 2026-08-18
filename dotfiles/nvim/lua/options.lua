-- [[ Setting options ]]
-- See `:help vim.opt`
-- vim.opt is a table that contains options for neovim

-- vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.signcolumn = 'yes'

vim.opt.shiftwidth = 2

vim.opt.showmode = false

vim.opt.clipboard = 'unnamedplus'

vim.opt.breakindent = true

vim.opt.undofile = true

vim.opt.ignorecase = true
vim.opt.smartcase = true

vim.opt.updatetime = 100
-- Time to wait for the rest of a mapped sequence.
vim.opt.timeoutlen = 500

--  See `:help 'list'`
--  and `:help 'listchars'`
vim.opt.list = true
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }

-- Preview substitutions live, as you type!
vim.opt.inccommand = 'split'

-- Show which line your cursor is on
vim.opt.cursorline = true

-- Minimal number of screen lines to keep above and below the cursor.
vim.opt.scrolloff = 10

-- Shows vertical line.
vim.opt.colorcolumn = '80'

-- Keymaps to reload configuration
vim.keymap.set("n", "<leader><leader>x", "<cmd>source %<CR>",
  { desc = "Execute the current lua file" })
-- Keymaps to execute code
vim.keymap.set("n", "<leader>x", ":.lua %<CR>")
vim.keymap.set("v", "<leader>x", ":lua %<CR>")

-- change lua indentation
vim.api.nvim_create_autocmd("FileType", {
  pattern = "lua",
  callback = function()
    vim.opt_local.shiftwidth = 2
    vim.opt_local.tabstop = 2
    vim.opt_local.expandtab = true
  end,
})

-- change python indentation
vim.api.nvim_create_autocmd("FileType", {
  pattern = "python",
  callback = function()
    vim.opt_local.shiftwidth = 4
    vim.opt_local.tabstop = 4
    vim.opt_local.expandtab = true
  end,
})

-- Set textwidth = 120 for C++ files
vim.api.nvim_create_autocmd("FileType", {
  pattern = "cpp",
  callback = function()
    vim.opt_local.textwidth = 120
  end,
})
-- vim: ts=2 sts=2 sw=2 et
