-- Session management: saves buffers/windows/cursor on exit, restores on next open.
-- Sessions are stored per working directory, so each project gets its own session.
-- Usage:
--   <leader>Ss   restore session for the current directory
--   <leader>Sl   restore the most recently used session (any directory)
--   <leader>Sd   stop saving the session for this session (e.g. before a clean exit)
-- Note: <leader>ps is taken by snacks_profiler (profiler scratch buffer).
return {
  {
    'folke/persistence.nvim',
    event = 'BufReadPre',
    opts  = {},
    keys  = {
      { '<leader>Ss', function() require('persistence').load() end,               desc = 'Session: restore for cwd' },
      { '<leader>Sl', function() require('persistence').load { last = true } end, desc = 'Session: restore last' },
      { '<leader>Sd', function() require('persistence').stop() end,               desc = 'Session: stop saving' },
    },
  },
}
-- vim: ts=2 sts=2 sw=2 et
