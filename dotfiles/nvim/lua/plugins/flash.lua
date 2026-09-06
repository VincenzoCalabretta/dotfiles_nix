-- Enhanced navigation: jump anywhere visible in 2-3 keystrokes.
-- Usage:
--   gs         jump mode — type 2 chars, pick label
--   gS         treesitter mode — visually highlight any syntax node to jump to
--   r          (operator-pending) remote — apply operator on a distant target
--   R          (operator/visual) treesitter search across visible code
--   <C-s>      (command mode) toggle flash search inside / pattern
--
-- Keep s available for mini.surround's sa/sd/sr mappings.
return {
  {
    'folke/flash.nvim',
    event = 'VeryLazy',
    opts  = {},
    keys  = {
      { 'gs',    function() require('flash').jump() end,              mode = { 'n', 'x', 'o' }, desc = 'Flash: jump' },
      { 'gS',    function() require('flash').treesitter() end,        mode = { 'n', 'x', 'o' }, desc = 'Flash: treesitter node' },
      { 'r',     function() require('flash').remote() end,            mode = 'o',               desc = 'Flash: remote' },
      { 'R',     function() require('flash').treesitter_search() end, mode = { 'o', 'x' },      desc = 'Flash: treesitter search' },
      { '<c-s>', function() require('flash').toggle() end,            mode = 'c',               desc = 'Flash: toggle' },
    },
  },
}
-- vim: ts=2 sts=2 sw=2 et
