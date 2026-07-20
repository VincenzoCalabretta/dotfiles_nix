-- Provides:
--   - ]m / [m  next/prev function start        (normal, visual, operator)
--   - ]M / [M  next/prev function end
--   - Textobject queries consumed by mini.ai:
--       aF/iF = around/inside function declaration
--       aC/iC = around/inside class / struct / impl
return {
  {
    'nvim-treesitter/nvim-treesitter-textobjects',
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
    config = function()
      -- New API (post-2024 rewrite): module lives under the hyphenated namespace.
      require('nvim-treesitter-textobjects').setup {
        move = { set_jumps = true },
      }

      local move = require('nvim-treesitter-textobjects.move')

      local function map(key, fn, desc)
        vim.keymap.set({ 'n', 'x', 'o' }, key, fn, { desc = desc })
      end

      map(']m', function() move.goto_next_start('@function.outer',     'textobjects') end, 'Next function start')
      map('[m', function() move.goto_previous_start('@function.outer', 'textobjects') end, 'Prev function start')
      map(']M', function() move.goto_next_end('@function.outer',       'textobjects') end, 'Next function end')
      map('[M', function() move.goto_previous_end('@function.outer',   'textobjects') end, 'Prev function end')
    end,
  },
}
-- vim: ts=2 sts=2 sw=2 et
