return {
  { -- Highlight, edit, and navigate code
    'nvim-treesitter/nvim-treesitter',
    branch = "main",
    build = ':TSUpdate',
    config = function()
      -- The 'main' branch dropped install.prefer_git/auto_install/
      -- ensure_installed -- setting them is now a silent no-op, so parsers
      -- must be installed explicitly via require('nvim-treesitter').install().
      local ts_config = require('nvim-treesitter.config')
      local ts = require('nvim-treesitter')

      -- Neovim's builtin filetype detection calls TLA+ files 'tla', but the
      -- treesitter parser (which also covers PlusCal -- it's always
      -- translated into a comment block inside a .tla file, there's no
      -- separate PlusCal parser) is named 'tlaplus'; register the mapping
      -- explicitly since vim.treesitter.start() otherwise assumes filetype
      -- and language name match.
      vim.treesitter.language.register('tlaplus', 'tla')

      -- Ensure parsers are installed. Blocks startup only on a fresh
      -- profile/machine where these aren't installed yet; a no-op after.
      local ensure_installed = {
        'bash', 'c', 'cpp', 'html', 'lua', 'luadoc', 'markdown', 'markdown_inline', 'vim', 'vimdoc',
        'mlir', 'tablegen', 'llvm', 'tlaplus'
      }
      local installed = ts_config.get_installed('parsers')
      local missing = vim.tbl_filter(function(lang)
        return not vim.tbl_contains(installed, lang)
      end, ensure_installed)
      if #missing > 0 then
        ts.install(missing):wait(300000)
      end

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
