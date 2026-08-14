-- Augments the standard gd/gr keybindings: try the LSP first, and only if
-- it has nothing to offer (no client attached to the buffer, or the client
-- attached but returned zero results -- e.g. a function-pointer struct
-- field with no traceable assignment), fall through to a whole-tree,
-- config-independent gtags query via GNU Global. Same keys either way, so
-- the fallback is invisible until it's needed.
--
-- gtags database lifecycle (build + incremental refresh) is handled by
-- gtags_db.lua; this module only queries it via the `global` CLI. Results
-- are funneled through the quickfix list and Telescope's quickfix picker
-- so both LSP and gtags hits look and feel the same, matching the rest of
-- this config's Telescope-first UX.
--
-- Only definitions/references get this treatment. Hover, rename, code
-- actions, etc. have no meaningful non-semantic substitute, so they stay
-- pure LSP untouched in plugins/lsp.lua.
--
-- Each gd/gr press reports its progress through fidget.nvim (already a
-- dependency, see plugins/lsp.lua) the same way it shows LSP progress: a
-- handle whose message updates in place as the attempt moves from "check
-- LSP" to "fall back to gtags" to "done". Purely cosmetic -- if fidget is
-- ever missing, every progress call below silently no-ops.

local M = {}

---@param title string
---@return table|nil handle a fidget.nvim ProgressHandle, or nil if fidget isn't available
local function progress_start(title)
  local ok, progress = pcall(require, 'fidget.progress')
  if not ok then
    return nil
  end
  return progress.handle.create({
    title = title,
    message = 'checking LSP...',
    lsp_client = { name = 'lsp_fallback' },
  })
end

---@param handle table|nil
---@param message string
local function progress_step(handle, message)
  if handle then
    handle:report({ message = message })
  end
end

---@param handle table|nil
---@param message string
local function progress_finish(handle, message)
  if handle then
    handle:report({ message = message })
    handle:finish()
  end
end

---@param items table[] quickfix-style items ({filename, lnum, text})
---@param title string
local function open_locations(items, title)
  if #items == 0 then
    vim.notify(title .. ': no results', vim.log.levels.WARN)
    return
  end
  vim.fn.setqflist({}, ' ', { title = title, items = items })
  if #items == 1 then
    vim.cmd('cfirst')
    return
  end
  require('telescope.builtin').quickfix()
end

--- Run `global` for SYMBOL against the current buffer's gtags database and
--- parse its `-x` output into quickfix items.
---@param flag string|nil extra flag to pass to `global` (e.g. '-r' for references)
---@param symbol string
---@param handle table|nil fidget progress handle, see progress_start()
local function gtags_query(flag, symbol, handle)
  if vim.fn.executable('global') == 0 then
    progress_finish(handle, 'gtags: `global` not found on $PATH')
    vim.notify('gtags fallback: `global` not found on $PATH', vim.log.levels.WARN)
    return {}
  end

  local env = require('gtags_db').env_for_buffer()
  if not env then
    -- No project root detected for this buffer (no .git/compile_commands.json/
    -- Makefile/configure found upward) -- nothing to query.
    progress_finish(handle, 'gtags: no project root detected for this buffer')
    return {}
  end

  if require('gtags_db').is_building(env.GTAGSROOT) then
    progress_step(handle, 'gtags: index still building for this project, results may be incomplete...')
  end

  local cmd = { 'global', '-a', '-x' }
  if flag then
    table.insert(cmd, flag)
  end
  table.insert(cmd, symbol)

  local res = vim.system(cmd, { env = env, cwd = env.GTAGSROOT, text = true }):wait()
  if res.code ~= 0 or not res.stdout then
    -- Typically "no gtags database found" (initial build for this project
    -- hasn't finished yet, see gtags_db.lua) or "not found" (no matches) --
    -- neither is worth surfacing as an error, gd already reports "no
    -- results" via the empty item list.
    return {}
  end

  local items = {}
  for line in vim.gsplit(res.stdout, '\n', { trimempty = true }) do
    -- `global -a -x` output: "<tag>  <lineno>  <abs-path>  <line text>"
    local lineno, path, text = line:match('^%S+%s+(%d+)%s+(%S+)%s+(.*)$')
    if lineno then
      table.insert(items, { filename = path, lnum = tonumber(lineno), text = text })
    end
  end
  return items
end

---@param kind 'definitions'|'references'
---@param handle table|nil fidget progress handle, see progress_start()
local function gtags_fallback(kind, handle)
  local symbol = vim.fn.expand('<cword>')
  local title = string.format('gtags: %s of %s', kind, symbol)

  if kind == 'references' then
    progress_step(handle, string.format('gtags: querying references of `%s`...', symbol))
    local items = gtags_query('-r', symbol, handle)
    progress_finish(handle, string.format('gtags: %d reference(s)', #items))
    open_locations(items, title)
    return
  end

  -- Global's built-in parser only tags function/macro definitions with -x;
  -- it does NOT tag struct-field declarations (e.g. a lang_hooks/targetm
  -- vtable member like `parse_file`) as definitions at all -- only as
  -- references. That's exactly the case this fallback exists for, so a
  -- plain -x miss falls through to -r rather than reporting "no results".
  progress_step(handle, string.format('gtags: querying definitions of `%s`...', symbol))
  local items = gtags_query(nil, symbol, handle)
  if #items == 0 then
    progress_step(handle, 'gtags: no definition tag, checking references...')
    items = gtags_query('-r', symbol, handle)
    title = string.format('gtags: %s of %s (no def tag, showing references)', kind, symbol)
  end
  progress_finish(handle, string.format('gtags: %d result(s)', #items))
  open_locations(items, title)
end

--- True if LOC (an LSP Location or LocationLink) points at the exact
--- buffer+line the request was made from.
---@param loc table
---@param uri string
---@param line0 integer 0-indexed line
local function is_self_location(loc, uri, line0)
  local loc_uri = loc.uri or loc.targetUri
  local range = loc.range or loc.targetSelectionRange or loc.targetRange
  return loc_uri == uri and range ~= nil and range.start.line == line0
end

--- True if some LSP client attached to the current buffer actually returned
--- at least one *useful* result for METHOD at the cursor. False for "no
--- client", "client answered with nothing", AND "every location returned
--- was just the cursor's own line" alike -- all three mean "fall back".
---
--- That last case is real, not hypothetical: clangd answers
--- textDocument/definition on a struct/vtable field's own declaration
--- (e.g. `lang_hooks.parse_file`'s `void (*parse_file) (void);`) by
--- echoing back that exact same location -- a legitimate, non-empty
--- response that happens to be useless, since a field declaration has
--- nothing further to point to. Verified against clangd directly: asking
--- for the definition at gcc/langhooks.h:485:10 (parse_file's own decl)
--- returns gcc/langhooks.h:485:10.
---@param method string LSP method name, e.g. 'textDocument/definition'
local function has_lsp_results(method)
  local clients = vim.lsp.get_clients({ bufnr = 0, method = method })
  if #clients == 0 then
    return false
  end

  local params = vim.lsp.util.make_position_params(0, clients[1].offset_encoding)
  if method == 'textDocument/references' then
    params.context = { includeDeclaration = true }
  end

  -- Synchronous probe with a short timeout: this only decides which path
  -- to take. The real (async, Telescope-driven) request is re-issued below
  -- on the LSP path, so this doesn't change existing LSP-success UX at all.
  local ok, results = pcall(vim.lsp.buf_request_sync, 0, method, params, 1000)
  if not ok or not results then
    return false
  end

  local uri = params.textDocument.uri
  local line0 = params.position.line

  for _, res in pairs(results) do
    if res.result and not vim.tbl_isempty(res.result) then
      local locs = vim.islist(res.result) and res.result or { res.result }
      for _, loc in ipairs(locs) do
        if not is_self_location(loc, uri, line0) then
          return true
        end
      end
    end
  end
  return false
end

function M.definitions()
  local handle = progress_start('gd')
  if has_lsp_results('textDocument/definition') then
    progress_finish(handle, 'resolved via LSP')
    require('telescope.builtin').lsp_definitions()
  else
    progress_step(handle, 'LSP: no results, falling back to gtags...')
    gtags_fallback('definitions', handle)
  end
end

function M.references()
  local handle = progress_start('gr')
  if has_lsp_results('textDocument/references') then
    progress_finish(handle, 'resolved via LSP')
    require('telescope.builtin').lsp_references()
  else
    progress_step(handle, 'LSP: no results, falling back to gtags...')
    gtags_fallback('references', handle)
  end
end

function M.setup()
  vim.keymap.set('n', 'gd', M.definitions, { desc = '[G]oto [D]efinition (LSP, gtags fallback)' })
  vim.keymap.set('n', 'gr', M.references, { desc = '[G]oto [R]eferences (LSP, gtags fallback)' })
end

return M
-- vim: ts=2 sts=2 sw=2 et
