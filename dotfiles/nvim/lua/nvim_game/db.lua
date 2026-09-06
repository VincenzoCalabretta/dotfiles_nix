-- User-facing mappings plus Neovim core defaults, kept in sync with the
-- actual configuration.
-- Each entry: { key, desc, category, hint (optional) }

local mappings = {
  -- ── Code / LSP ────────────────────────────────────────────────────────────
  { key = 'gd', desc = 'Go to definition of symbol under cursor', category = 'Code' },
  { key = 'gr', desc = 'List references to symbol', category = 'Code' },
  { key = 'gI', desc = 'Go to implementation', category = 'Code' },
  { key = 'gD', desc = 'Go to declaration', category = 'Code' },
  { key = 'K', desc = 'Show hover documentation', category = 'Code' },
  { key = 'gq', desc = 'Format buffer or selection', category = 'Code' },
  { key = '<leader>ca', desc = 'Open code actions', category = 'Code' },
  { key = '<leader>cl', desc = 'Run CodeLens action at cursor', category = 'Code' },
  { key = '<leader>cr', desc = 'Rename symbol', category = 'Code' },
  { key = '<leader>cf', desc = 'Format current buffer', category = 'Code' },
  { key = '<leader>cd', desc = 'Search document symbols', category = 'Code' },
  { key = '<leader>cw', desc = 'Search workspace symbols', category = 'Code' },
  { key = '<leader>ct', desc = 'Jump to type definition', category = 'Code' },
  { key = '<leader>ch', desc = 'Toggle inlay hints', category = 'Code' },
  { key = '<leader>cn', desc = 'Convert number under cursor or selection', category = 'Code' },

  -- ── Diagnostics ──────────────────────────────────────────────────────────
  { key = '[d', desc = 'Previous diagnostic', category = 'Diagnostics' },
  { key = ']d', desc = 'Next diagnostic', category = 'Diagnostics' },
  { key = '<leader>e', desc = 'Show diagnostic at cursor', category = 'Diagnostics' },
  { key = '<leader>q', desc = 'Send diagnostics to location list', category = 'Diagnostics' },
  { key = '<leader>sd', desc = 'Search diagnostics', category = 'Diagnostics' },

  -- ── Git ──────────────────────────────────────────────────────────────────
  { key = '<leader>gg', desc = 'Open Git status', category = 'Git' },
  { key = '<leader>gb', desc = 'Browse files from a branch', category = 'Git' },
  { key = '<leader>gd', desc = 'Diff current file against a branch', category = 'Git' },
  { key = '<leader>gD', desc = 'Open full Diffview', category = 'Git' },
  { key = '<leader>gC', desc = 'Close Diffview', category = 'Git' },
  { key = '<leader>gf', desc = 'Show current-file history', category = 'Git' },
  { key = '<leader>gF', desc = 'Show repository history', category = 'Git' },
  { key = ']c', desc = 'Next Git hunk', category = 'Git' },
  { key = '[c', desc = 'Previous Git hunk', category = 'Git' },
  { key = '<leader>gs', desc = 'Stage hunk', category = 'Git' },
  { key = '<leader>gr', desc = 'Reset hunk', category = 'Git' },
  { key = '<leader>gS', desc = 'Stage buffer', category = 'Git' },
  { key = '<leader>gu', desc = 'Undo staged hunk', category = 'Git' },
  { key = '<leader>gR', desc = 'Reset buffer', category = 'Git' },
  { key = '<leader>gp', desc = 'Preview hunk', category = 'Git' },
  { key = '<leader>gB', desc = 'Blame current line', category = 'Git' },
  { key = '<leader>gi', desc = 'Diff buffer against index', category = 'Git' },
  { key = '<leader>gH', desc = 'Diff buffer against last commit', category = 'Git' },
  { key = '<leader>gt', desc = 'Toggle inline blame', category = 'Git' },
  { key = '<leader>gT', desc = 'Toggle deleted lines', category = 'Git' },

  -- ── Search ───────────────────────────────────────────────────────────────
  { key = '<leader>sf', desc = 'Find project files', category = 'Search' },
  { key = '<leader>sg', desc = 'Live grep project', category = 'Search' },
  { key = '<leader>sw', desc = 'Grep word under cursor', category = 'Search' },
  { key = '<leader>sh', desc = 'Search help tags', category = 'Search' },
  { key = '<leader>sk', desc = 'Browse keymaps', category = 'Search' },
  { key = '<leader>ss', desc = 'Pick Telescope builtin', category = 'Search' },
  { key = '<leader>sr', desc = 'Resume last search', category = 'Search' },
  { key = '<leader>s.', desc = 'Browse recent files', category = 'Search' },
  { key = '<leader>s/', desc = 'Grep open files', category = 'Search' },
  { key = '<leader>sn', desc = 'Find Neovim config files', category = 'Search' },
  { key = '<leader>sp', desc = 'Browse installed plugins', category = 'Search' },
  { key = '<leader><leader>', desc = 'Switch buffers', category = 'Search' },
  { key = '<leader>/', desc = 'Fuzzy find current buffer', category = 'Search' },

  -- ── Harpoon ──────────────────────────────────────────────────────────────
  { key = '<leader>ha', desc = 'Pin current file', category = 'Harpoon' },
  { key = '<leader>hh', desc = 'Open pin menu', category = 'Harpoon' },
  { key = '<leader>1', desc = 'Jump to pin 1', category = 'Harpoon' },
  { key = '<leader>2', desc = 'Jump to pin 2', category = 'Harpoon' },
  { key = '<leader>3', desc = 'Jump to pin 3', category = 'Harpoon' },
  { key = '<leader>4', desc = 'Jump to pin 4', category = 'Harpoon' },
  { key = '<leader>h[', desc = 'Previous pin', category = 'Harpoon' },
  { key = '<leader>h]', desc = 'Next pin', category = 'Harpoon' },

  -- ── Outline / navigation ─────────────────────────────────────────────────
  { key = '<leader>ot', desc = 'Toggle code outline', category = 'Outline' },
  { key = '<leader>oo', desc = 'Open code outline', category = 'Outline' },
  { key = '<leader>oc', desc = 'Close code outline', category = 'Outline' },
  { key = '<leader>oO', desc = 'Open all outline nodes', category = 'Outline' },
  { key = '<leader>oC', desc = 'Close all outline nodes', category = 'Outline' },
  { key = '<leader>on', desc = 'Next outline symbol', category = 'Outline' },
  { key = '<leader>op', desc = 'Previous outline symbol', category = 'Outline' },
  { key = '<leader>og', desc = 'Jump to outline symbol', category = 'Outline' },
  { key = '<leader>oN', desc = 'Toggle outline navigation window', category = 'Outline' },
  { key = '<leader>oi', desc = 'Show outline information', category = 'Outline' },
  { key = '<leader>os', desc = 'Search outline symbols with Telescope', category = 'Outline' },
  { key = '<leader>of', desc = 'Search outline symbols with FZF-Lua', category = 'Outline' },
  { key = '<leader>oS', desc = 'Search outline symbols with Snacks', category = 'Outline' },
  { key = '[o', desc = 'Previous outline symbol', category = 'Outline' },
  { key = ']o', desc = 'Next outline symbol', category = 'Outline' },
  { key = '[O', desc = 'Previous enclosing outline symbol', category = 'Outline' },
  { key = ']O', desc = 'Next enclosing outline symbol', category = 'Outline' },
  { key = ']m', desc = 'Next function start', category = 'Navigation' },
  { key = '[m', desc = 'Previous function start', category = 'Navigation' },
  { key = ']M', desc = 'Next function end', category = 'Navigation' },
  { key = '[M', desc = 'Previous function end', category = 'Navigation' },
  { key = '[C', desc = 'Jump to outer context', category = 'Navigation' },
  { key = 'gs', desc = 'Flash jump', category = 'Navigation' },
  { key = 'gS', desc = 'Flash Tree-sitter jump', category = 'Navigation' },
  { key = 'r', desc = 'Flash remote motion (operator-pending)', category = 'Navigation' },
  { key = 'R', desc = 'Flash Tree-sitter search (operator/visual)', category = 'Navigation' },
  { key = '<C-s>', desc = 'Toggle Flash search (command line)', category = 'Navigation', modes = { c = true } },

  -- ── Textobjects ──────────────────────────────────────────────────────────
  { key = 'aF', desc = 'Around function declaration', category = 'Textobjects', hint = 'daF, caF, vaF, yaF' },
  { key = 'iF', desc = 'Inside function declaration', category = 'Textobjects', hint = 'diF, ciF, viF, yiF' },
  { key = 'aC', desc = 'Around class / struct / impl', category = 'Textobjects', hint = 'daC, caC, vaC, yaC' },
  { key = 'iC', desc = 'Inside class / struct / impl', category = 'Textobjects', hint = 'diC, ciC, viC, yiC' },
  { key = 'af', desc = 'Around function call', category = 'Textobjects', hint = 'mini.ai function call' },
  { key = 'if', desc = 'Inside function call arguments', category = 'Textobjects', hint = 'mini.ai function call' },

  -- ── Build / debug targets ─────────────────────────────────────────────────
  { key = '<leader>bb', desc = 'Build Bazel target', category = 'Targets' },
  { key = '<leader>bt', desc = 'Test Bazel target', category = 'Targets' },
  { key = '<leader>br', desc = 'Run Bazel target', category = 'Targets' },
  { key = '<leader>bd', desc = 'Debug Bazel target', category = 'Targets' },
  { key = '<leader>ba', desc = 'Toggle automatic rebuilds', category = 'Targets' },
  { key = '<leader>bh', desc = 'Show recent targets', category = 'Targets' },
  { key = '<leader>bc', desc = 'Clear recent targets', category = 'Targets' },
  { key = '<leader>bC', desc = 'Debug C++ target', category = 'Targets' },
  { key = '<leader>bH', desc = 'Deploy and debug remote C++ target', category = 'Targets' },
  { key = '<leader>bp', desc = 'Debug Python target', category = 'Targets' },
  { key = '<leader>bP', desc = 'Debug Python target from input', category = 'Targets' },
  { key = '<leader>bu', desc = 'Debug Rust target', category = 'Targets' },
  { key = '<leader>bU', desc = 'Debug Rust target from input', category = 'Targets' },
  { key = '<leader>bl', desc = 'Relaunch last debug target', category = 'Targets' },
  { key = '<leader>bg', desc = 'Attach to gdbservers', category = 'Targets' },
  { key = '<leader>bv', desc = 'Toggle DAP view', category = 'Targets' },
  { key = '<leader>bT', desc = 'Open tracepoint actions', category = 'Targets' },
  { key = '<leader>b?', desc = 'Open DAP picker menu', category = 'Targets' },
  { key = '<M-c>', desc = 'Continue or start debugging', category = 'Debugger' },
  { key = '<M-a>', desc = 'Continue all debug sessions', category = 'Debugger' },
  { key = '<M-t>', desc = 'Terminate debugging', category = 'Debugger' },
  { key = '<M-b>', desc = 'Toggle breakpoint', category = 'Debugger' },
  { key = '<M-B>', desc = 'Set conditional breakpoint', category = 'Debugger' },
  { key = '<M-n>', desc = 'Step over', category = 'Debugger' },
  { key = '<M-s>', desc = 'Step into', category = 'Debugger' },
  { key = '<M-o>', desc = 'Step out', category = 'Debugger' },
  { key = '<M-r>', desc = 'Toggle debugger REPL', category = 'Debugger' },
  { key = '<M-p>', desc = 'Pause debugging', category = 'Debugger' },
  { key = '<M-f>', desc = 'Jump to current frame', category = 'Debugger' },
  { key = '<M-g>', desc = 'Select debug session', category = 'Debugger' },
  { key = '<M-w>', desc = 'Watch expression under cursor', category = 'Debugger' },

  -- ── Sessions, AI, and profiling ───────────────────────────────────────────
  { key = '<leader>Ss', desc = 'Restore session for current directory', category = 'Sessions' },
  { key = '<leader>Sl', desc = 'Restore most recent session', category = 'Sessions' },
  { key = '<leader>Sd', desc = 'Stop saving current session', category = 'Sessions' },
  { key = '<leader>ll', desc = 'Toggle AI CLI', category = 'AI' },
  { key = '<leader>ls', desc = 'Select AI CLI', category = 'AI' },
  { key = '<leader>lf', desc = 'Focus AI CLI', category = 'AI' },
  { key = '<leader>lh', desc = 'Hide AI CLI', category = 'AI' },
  { key = '<leader>ld', desc = 'Detach AI CLI session', category = 'AI' },
  { key = '<leader>lp', desc = 'Choose context-aware prompt', category = 'AI' },
  { key = '<leader>lt', desc = 'Send current location to AI CLI', category = 'AI' },
  { key = '<leader>lF', desc = 'Send current file to AI CLI', category = 'AI' },
  { key = '<leader>lv', desc = 'Send visual selection to AI CLI', category = 'AI' },
  { key = '<leader>pp', desc = 'Toggle profiler', category = 'Profiling' },
  { key = '<leader>ph', desc = 'Toggle profiler highlights', category = 'Profiling' },
  { key = '<leader>ps', desc = 'Open profiler scratch buffer', category = 'Profiling' },

  -- ── Utilities ────────────────────────────────────────────────────────────
  { key = '<leader>Gm', desc = 'Open keybinding-game menu', category = 'KeyGame' },
  { key = '<leader>Ga', desc = 'Play all keybinding-game categories', category = 'KeyGame' },
  { key = '<Esc>', desc = 'Clear search highlighting / exit terminal mode', category = 'Windows' },
  { key = '<C-h>', desc = 'Focus left window', category = 'Windows' },
  { key = '<C-j>', desc = 'Focus lower window', category = 'Windows' },
  { key = '<C-k>', desc = 'Focus upper window', category = 'Windows' },
  { key = '<C-l>', desc = 'Focus right window', category = 'Windows' },
  { key = '<leader>t', desc = 'Open terminal buffer', category = 'Windows' },
  { key = '<leader>u', desc = 'Toggle undo tree', category = 'Misc' },
  { key = '<leader>v', desc = 'Toggle Venn drawing mode', category = 'Misc' },
  { key = '<leader>x', desc = 'Execute current Lua line or selection', category = 'Misc' },
  { key = '<leader>X', desc = 'Source current Lua file', category = 'Misc' },
}

local default_explanations = require('nvim_game.default_explanations')

-- These two default diagnostic mappings are already present in the curated
-- Diagnostics category, so enrich those entries instead of asking the same
-- normal-mode question twice under a second category.
for _, mapping in ipairs(mappings) do
  if mapping.key == '[d' or mapping.key == ']d' then
    local explanation = default_explanations.for_mapping(mapping.key, mapping.desc)
    mapping.explanation = explanation.why
    mapping.help = explanation.help
  end
end

local config_home = vim.env.XDG_CONFIG_HOME or (vim.env.HOME .. '/.config')
local compiler_explorer_enabled = vim.env.COMPILER_EXPLORER_URL
  or vim.fn.filereadable(config_home .. '/compiler-explorer-nvim/url') == 1

if compiler_explorer_enabled then
  table.insert(mappings, {
    key = '<leader>ce',
    desc = 'Compile current buffer or selection in Compiler Explorer',
    category = 'Code',
  })
  table.insert(mappings, {
    key = 'K',
    desc = 'Show assembly instruction/register documentation',
    category = 'Compiler Explorer',
  })
end

-- Neovim registers its own default mappings with the internal script id -8.
-- Add every described, user-typeable default at runtime so this category stays
-- aligned with the installed Neovim version.  Explicit mappings above win if
-- the configuration replaces a default.
local core_modes = {
  n = 'normal',
  i = 'insert',
  c = 'command-line',
  x = 'visual',
  o = 'operator-pending',
  s = 'select',
}

local function canonical_key(key)
  -- Neovim reports control-key names with an uppercase letter, while the game
  -- records them in lowercase (for example, <C-l>).
  key = key:gsub('<C%-([A-Z])>', function(letter)
    return '<C-' .. letter:lower() .. '>'
  end)
  -- Space is the configured leader in this setup, and the game already uses
  -- <leader> as the answer token for it.
  -- `nvim_get_keymap()` represents a literal Space as either `<Space>` or a
  -- literal byte depending on the mapping. Answers use the readable leader
  -- token because this configuration's leader is Space.
  return key:gsub('<Space>', '<leader>'):gsub(' ', '<leader>')
end

local known_keys = {}
for _, mapping in ipairs(mappings) do
  -- Most curated keys replace a mapping in every relevant mode.  A key with
  -- explicit modes only suppresses an identically-mode default: Flash's
  -- command-line <C-s>, for example, must not hide Neovim's Insert/Select
  -- signature-help default on the same physical keys.
  known_keys[mapping.key] = mapping.modes or true
end

local defaults = {}
for mode, mode_name in pairs(core_modes) do
  for _, map in ipairs(vim.api.nvim_get_keymap(mode)) do
    local key = canonical_key(map.lhs)
    local overridden = known_keys[key]
    if map.sid == -8
      and map.desc
      and not key:match('^<Plug>')
      and not (overridden == true or (type(overridden) == 'table' and overridden[mode])) then
      local entry = defaults[key]
      if entry then
        entry.modes[#entry.modes + 1] = mode_name
      else
        defaults[key] = {
          key = key,
          desc = map.desc:gsub('^:help ', ''),
          category = 'Neovim defaults',
          modes = { mode_name },
        }
      end
    end
  end
end

for _, entry in pairs(defaults) do
  local explanation = default_explanations.for_mapping(entry.key, entry.desc)
  entry.raw_desc = entry.desc
  entry.desc = explanation.what
  entry.explanation = explanation.why
  entry.help = explanation.help
  entry.explanation_fallback = explanation.fallback or false
  entry.hint = 'Mode: ' .. table.concat(entry.modes, ' / ')
  entry.modes = nil
  table.insert(mappings, entry)
end

return mappings
