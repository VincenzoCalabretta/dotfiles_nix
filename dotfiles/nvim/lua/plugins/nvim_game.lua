-- Keybinding learning game.
--   <leader>G        open category menu and start
--   <leader>Ga       jump straight into ALL categories
return {
  {
    -- Pure-Lua local plugin; no git remote needed.
    dir    = vim.fn.stdpath('config'),
    name   = 'nvim-keybind-game',
    lazy   = true,
    keys   = {
      {
        '<leader>G',
        function() require('nvim_game').start() end,
        desc = 'KeyGame: pick category and play',
      },
      {
        '<leader>Ga',
        function() require('nvim_game').start(nil) end,
        desc = 'KeyGame: play all categories',
      },
    },
  },
}
-- vim: ts=2 sts=2 sw=2 et
