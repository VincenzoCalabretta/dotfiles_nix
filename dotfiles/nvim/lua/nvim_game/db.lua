-- Complete keybinding database for nvim_game.
-- Each entry: { key, desc, category, hint (optional) }
-- 'key' uses the exact notation the user would type/see in config.

return {
  -- ── LSP ────────────────────────────────────────────────────────────────────
  { key = 'gd',           desc = 'Go to definition of symbol under cursor',         category = 'LSP' },
  { key = 'gr',           desc = 'List all references to symbol',                   category = 'LSP' },
  { key = 'gI',           desc = 'Go to implementation of symbol',                  category = 'LSP' },
  { key = 'gD',           desc = 'Go to declaration (not definition)',              category = 'LSP' },
  { key = 'K',            desc = 'Show hover documentation popup',                  category = 'LSP' },
  { key = '<leader>D',    desc = 'Jump to type definition',                         category = 'LSP' },
  { key = '<leader>rn',   desc = 'Rename symbol under cursor',                      category = 'LSP' },
  { key = '<leader>ca',   desc = 'Open code actions menu',                          category = 'LSP' },
  { key = '<leader>f',    desc = 'Format entire buffer via LSP',                    category = 'LSP' },
  { key = 'gq',           desc = 'Format buffer (normal) or selection (visual) via LSP', category = 'LSP' },
  { key = '<leader>ds',   desc = 'Search document symbols (Telescope)',             category = 'LSP' },
  { key = '<leader>ws',   desc = 'Search workspace symbols (Telescope)',            category = 'LSP' },
  { key = '<leader>th',   desc = 'Toggle inlay hints on/off',                       category = 'LSP' },
  { key = '<leader>cl',   desc = 'Run code lens action under cursor',               category = 'LSP' },

  -- ── Diagnostics ────────────────────────────────────────────────────────────
  { key = '[d',           desc = 'Jump to previous diagnostic',                     category = 'Diagnostics' },
  { key = ']d',           desc = 'Jump to next diagnostic',                         category = 'Diagnostics' },
  { key = '<leader>e',    desc = 'Show diagnostic under cursor in float',           category = 'Diagnostics' },
  { key = '<leader>q',    desc = 'Send all diagnostics to location list',           category = 'Diagnostics' },
  { key = '<leader>sd',   desc = 'Search diagnostics with Telescope',              category = 'Diagnostics' },

  -- ── Git — gitsigns ─────────────────────────────────────────────────────────
  { key = ']c',           desc = 'Jump to next git hunk',                           category = 'Git' },
  { key = '[c',           desc = 'Jump to previous git hunk',                       category = 'Git' },
  { key = '<leader>hs',   desc = 'Stage hunk under cursor',                         category = 'Git' },
  { key = '<leader>hr',   desc = 'Reset hunk under cursor',                         category = 'Git' },
  { key = '<leader>hS',   desc = 'Stage entire buffer',                             category = 'Git' },
  { key = '<leader>hu',   desc = 'Undo the last staged hunk',                       category = 'Git' },
  { key = '<leader>hR',   desc = 'Reset entire buffer to index state',              category = 'Git' },
  { key = '<leader>hp',   desc = 'Preview hunk diff in float',                      category = 'Git' },
  { key = '<leader>hb',   desc = 'Show git blame for current line',                 category = 'Git' },
  { key = '<leader>hd',   desc = 'Diff buffer against git index',                   category = 'Git' },
  { key = '<leader>hD',   desc = 'Diff buffer against last commit',                 category = 'Git' },
  { key = '<leader>tb',   desc = 'Toggle persistent inline git blame',              category = 'Git' },
  { key = '<leader>tD',   desc = 'Toggle display of deleted git lines',             category = 'Git' },

  -- ── Git — diffview / git_branch_inspect ────────────────────────────────────
  { key = '<leader>gv',   desc = 'Open diffview full diff panel',                   category = 'Git' },
  { key = '<leader>gc',   desc = 'Close diffview panel',                            category = 'Git' },
  { key = '<leader>gh',   desc = 'Open diffview file history for current file',     category = 'Git' },
  { key = '<leader>gH',   desc = 'Open diffview repo-wide file history',            category = 'Git' },
  { key = '<leader>gb',   desc = 'Browse files from a specific git branch',         category = 'Git' },
  { key = '<leader>gd',   desc = 'Quick diff current file against a branch',        category = 'Git' },

  -- ── Telescope ──────────────────────────────────────────────────────────────
  { key = '<leader>sf',   desc = 'Find files in project root',                      category = 'Telescope' },
  { key = '<leader>sg',   desc = 'Live grep across project',                        category = 'Telescope' },
  { key = '<leader>sw',   desc = 'Grep for word under cursor',                      category = 'Telescope' },
  { key = '<leader>sh',   desc = 'Search Neovim help tags',                         category = 'Telescope' },
  { key = '<leader>sk',   desc = 'Browse all defined keymaps',                      category = 'Telescope' },
  { key = '<leader>ss',   desc = 'Pick a Telescope built-in picker',                category = 'Telescope' },
  { key = '<leader>sr',   desc = 'Resume the last Telescope search',                category = 'Telescope' },
  { key = '<leader>s.',   desc = 'Browse recently opened files',                    category = 'Telescope' },
  { key = '<leader><leader>', desc = 'Switch between open buffers',                 category = 'Telescope' },
  { key = '<leader>/',    desc = 'Fuzzy search inside current buffer',              category = 'Telescope' },
  { key = '<leader>s/',   desc = 'Live grep in open files only',                    category = 'Telescope' },
  { key = '<leader>sn',   desc = 'Find files inside Neovim config directory',       category = 'Telescope' },

  -- ── Harpoon ────────────────────────────────────────────────────────────────
  { key = '<leader>ha',   desc = 'Pin current file to Harpoon list',               category = 'Harpoon' },
  { key = '<leader>hh',   desc = 'Open Harpoon quick menu',                        category = 'Harpoon' },
  { key = '<leader>1',    desc = 'Jump to Harpoon pin #1',                         category = 'Harpoon' },
  { key = '<leader>2',    desc = 'Jump to Harpoon pin #2',                         category = 'Harpoon' },
  { key = '<leader>3',    desc = 'Jump to Harpoon pin #3',                         category = 'Harpoon' },
  { key = '<leader>4',    desc = 'Jump to Harpoon pin #4',                         category = 'Harpoon' },
  { key = '<leader>h]',   desc = 'Cycle to next Harpoon pin',                      category = 'Harpoon' },
  { key = '<leader>h[',   desc = 'Cycle to previous Harpoon pin',                  category = 'Harpoon' },

  -- ── Aerial (code outline) ──────────────────────────────────────────────────
  { key = '<leader>a',    desc = 'Toggle aerial code outline panel',               category = 'Navigation' },
  { key = '<leader>ao',   desc = 'Open aerial outline',                            category = 'Navigation' },
  { key = '<leader>ac',   desc = 'Close aerial outline',                           category = 'Navigation' },
  { key = '<leader>an',   desc = 'Jump to next symbol in aerial',                  category = 'Navigation' },
  { key = '<leader>ap',   desc = 'Jump to previous symbol in aerial',              category = 'Navigation' },
  { key = '<leader>aN',   desc = 'Toggle aerial navigation floating window',       category = 'Navigation' },

  -- ── Treesitter motions ────────────────────────────────────────────────────
  { key = ']m',           desc = 'Jump to start of next function',                 category = 'Navigation' },
  { key = '[m',           desc = 'Jump to start of previous function',             category = 'Navigation' },
  { key = ']M',           desc = 'Jump to end of next function',                   category = 'Navigation' },
  { key = '[M',           desc = 'Jump to end of previous function',               category = 'Navigation' },
  { key = '[C',           desc = 'Jump up to outer treesitter context',            category = 'Navigation' },

  -- ── Flash ─────────────────────────────────────────────────────────────────
  { key = 's',            desc = 'Flash: type 2 chars then pick a jump label',    category = 'Navigation' },
  { key = 'S',            desc = 'Flash treesitter: select any visible TS node',  category = 'Navigation' },

  -- ── Textobjects (mini.ai + treesitter) ────────────────────────────────────
  { key = 'aF',           desc = 'Textobject: AROUND function declaration',        category = 'Textobjects',
    hint = 'Use with operators: daF, caF, vaF, yaF' },
  { key = 'iF',           desc = 'Textobject: INSIDE function declaration body',   category = 'Textobjects',
    hint = 'Use with operators: diF, ciF, viF, yiF' },
  { key = 'aC',           desc = 'Textobject: AROUND class / struct / impl',       category = 'Textobjects',
    hint = 'Use with operators: daC, caC, vaC, yaC' },
  { key = 'iC',           desc = 'Textobject: INSIDE class / struct / impl',       category = 'Textobjects',
    hint = 'Use with operators: diC, ciC, viC, yiC' },
  { key = 'af',           desc = 'Textobject: AROUND function call (args+parens)', category = 'Textobjects',
    hint = 'mini.ai: covers the call site, e.g. foo(a, b)' },
  { key = 'if',           desc = 'Textobject: INSIDE function call arguments',     category = 'Textobjects',
    hint = 'mini.ai: just the argument list, not the parens' },

  -- ── DAP (debugging) ───────────────────────────────────────────────────────
  { key = '<leader>dc',   desc = 'Continue / start debug session',                 category = 'DAP' },
  { key = '<leader>dn',   desc = 'Step over (next line, skip into calls)',         category = 'DAP' },
  { key = '<leader>di',   desc = 'Step into the current function call',            category = 'DAP' },
  { key = '<leader>do',   desc = 'Step out of the current function',               category = 'DAP' },
  { key = '<leader>db',   desc = 'Toggle breakpoint on current line',              category = 'DAP' },
  { key = '<leader>dB',   desc = 'Set a conditional breakpoint (prompts)',         category = 'DAP' },
  { key = '<leader>dT',   desc = 'Terminate the active debug session',             category = 'DAP' },
  { key = '<leader>dr',   desc = 'Toggle the DAP REPL',                            category = 'DAP' },
  { key = '<leader>dv',   desc = 'Open DAP variable / stack view panel',           category = 'DAP' },
  { key = '<leader>da',   desc = 'Watch variable under cursor in REPL',            category = 'DAP' },
  { key = '<leader>dl',   desc = 'Re-launch the most recent debug target',         category = 'DAP' },
  { key = '<leader>dt',   desc = 'Debug C++ Bazel test — pick with Telescope',    category = 'DAP' },
  { key = '<leader>du',   desc = 'Debug Rust Bazel target — pick with Telescope', category = 'DAP' },
  { key = '<leader>dp',   desc = 'Debug Python Bazel target — pick with Telescope', category = 'DAP' },

  -- ── Bazel ─────────────────────────────────────────────────────────────────
  { key = '<leader>bs',   desc = 'Pick any Bazel target and action',              category = 'Bazel' },
  { key = '<leader>bb',   desc = 'Pick Bazel target then build it',               category = 'Bazel' },
  { key = '<leader>bt',   desc = 'Pick Bazel target then run tests',              category = 'Bazel' },
  { key = '<leader>br',   desc = 'Pick Bazel target then run it',                 category = 'Bazel' },
  { key = '<leader>bd',   desc = 'Pick Bazel target then debug it',               category = 'Bazel' },

  -- ── Overseer (task runner) ─────────────────────────────────────────────────
  { key = '<leader>o',    desc = 'Toggle Overseer task panel',                     category = 'Tasks' },
  { key = '<leader>or',   desc = 'Run an Overseer task',                           category = 'Tasks' },

  -- ── Session (persistence) ─────────────────────────────────────────────────
  { key = '<leader>Ss',   desc = 'Restore session for the current directory',      category = 'Sessions' },
  { key = '<leader>Sl',   desc = 'Restore the most recently used session',         category = 'Sessions' },
  { key = '<leader>Sd',   desc = 'Stop auto-saving session (for a clean exit)',    category = 'Sessions' },

  -- ── Windows & splits ──────────────────────────────────────────────────────
  { key = '<C-h>',        desc = 'Move focus to left window',                      category = 'Windows' },
  { key = '<C-l>',        desc = 'Move focus to right window',                     category = 'Windows' },
  { key = '<C-j>',        desc = 'Move focus to lower window',                     category = 'Windows' },
  { key = '<C-k>',        desc = 'Move focus to upper window',                     category = 'Windows' },
  { key = '<leader>t',    desc = 'Open a new terminal buffer',                     category = 'Windows' },

  -- ── Misc / editing ────────────────────────────────────────────────────────
  { key = '<leader>u',    desc = 'Toggle undo tree panel',                         category = 'Misc' },
  { key = '<leader>v',    desc = 'Toggle Venn diagram drawing mode',               category = 'Misc' },
  { key = '<leader>x',    desc = 'Execute current line as Lua',                    category = 'Misc' },
  { key = '<leader><leader>x', desc = 'Source / execute the current Lua file',    category = 'Misc' },
}
