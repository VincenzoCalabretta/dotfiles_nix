-- Fast file pinning and instant switching.
-- Usage:
--   <leader>ha        pin current file
--   <leader>hh        open pin menu (edit/reorder with normal Vim motions)
--   <leader>1-4       jump to pin 1-4
--   <leader>h] / h[   cycle through pins
return {
  {
    'ThePrimeagen/harpoon',
    branch       = 'harpoon2',
    dependencies = { 'nvim-lua/plenary.nvim' },
    config = function()
      local harpoon = require('harpoon')
      harpoon:setup()

      local function map(key, fn, desc)
        vim.keymap.set('n', key, fn, { desc = desc })
      end

      map('<leader>ha', function() harpoon:list():add() end,                              'Harpoon: pin file')
      map('<leader>hh', function() harpoon.ui:toggle_quick_menu(harpoon:list()) end,     'Harpoon: menu')

      map('<leader>1',  function() harpoon:list():select(1) end,                         'Harpoon: file 1')
      map('<leader>2',  function() harpoon:list():select(2) end,                         'Harpoon: file 2')
      map('<leader>3',  function() harpoon:list():select(3) end,                         'Harpoon: file 3')
      map('<leader>4',  function() harpoon:list():select(4) end,                         'Harpoon: file 4')

      map('<leader>h]', function() harpoon:list():next() end,                            'Harpoon: next pin')
      map('<leader>h[', function() harpoon:list():prev() end,                            'Harpoon: prev pin')
    end,
  },
}
-- vim: ts=2 sts=2 sw=2 et
