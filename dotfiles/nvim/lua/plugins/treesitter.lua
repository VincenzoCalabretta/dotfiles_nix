return {
  { -- Highlight, edit, and navigate code
    'nvim-treesitter/nvim-treesitter',
    branch = "main",
    build = ':TSUpdate',
    config = function()
      local install = require('nvim-treesitter.install')

      -- Prefer git instead of curl
      install.prefer_git = true

      -- Auto-install languages that are not installed
      install.auto_install = true

      -- Ensure parsers are installed
      install.ensure_installed = {
        'bash', 'c', 'cpp', 'html', 'lua', 'luadoc', 'markdown', 'markdown_inline', 'vim', 'vimdoc'
      }

      -- Enable highlight for all buffers
      vim.api.nvim_create_autocmd('FileType', {
        callback = function()
          pcall(vim.treesitter.start)
        end,
      })

      -- Enable indentation except for ruby
      vim.api.nvim_create_autocmd('FileType', {
        pattern = '*',
        callback = function(args)
          if vim.bo[args.buf].filetype ~= 'ruby' then
            vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end,
      })
    end,
  },
}
-- vim: ts=2 sts=2 sw=2 et
