-- Builds and incrementally refreshes a GNU Global (gtags) database per
-- project, purely in Lua via vim.system(). This replaces vim-gutentags for
-- the gtags backend: gutentags' only Global-backed module is
-- 'gtags_cscope', which unconditionally throws on Neovim (`throw "...this
-- Vim has no support for cscope files."` in
-- autoload/gutentags/gtags_cscope.vim) because it hard-requires the legacy
-- :cscope commands, which Neovim has never implemented (`has('cscope')` is
-- always 0 there). There is no plain, non-cscope gtags module to fall back
-- to -- ctags/cscope/gtags_cscope/pycscope is the complete list gutentags
-- ships. Since lua/lsp_fallback.lua only ever needed the `global` CLI and
-- never the :cscope integration, the fix is to stop asking gutentags to do
-- this job at all.
--
-- The database lives out-of-tree under stdpath('cache'), keyed by a hash
-- of the project root, so nothing is ever written into the project itself.

local M = {}

-- Checked only as a fallback when no .git is found anywhere upward (see
-- find_root): a multi-component autotools tree like GCC's has its own
-- nested configure/Makefile.in in gcc/, libcpp/, libiberty/, etc, so
-- matching on those first would stop at the nearest subproject instead of
-- the real repo root.
local fallback_root_markers = { 'compile_commands.json', 'compile_flags.txt', 'Makefile', 'configure' }

-- root -> dbpath, cached per session so repeat calls don't re-stat/re-spawn.
local db_for_root = {}
-- root -> true while a build/refresh is in flight for it, so a second
-- BufReadPost (or any other trigger) before the first gtags process exits
-- doesn't spawn a concurrent writer into the same database -- two `gtags`
-- processes racing on one target directory corrupts it.
local building = {}

local function find_root(start)
  local git = vim.fs.find('.git', { path = start, upward = true })[1]
  if git then
    return vim.fs.dirname(git)
  end
  local found = vim.fs.find(fallback_root_markers, { path = start, upward = true })[1]
  return found and vim.fs.dirname(found) or nil
end

local function cache_dir_for(root)
  local hash = vim.fn.sha256(root):sub(1, 16)
  return vim.fs.joinpath(vim.fn.stdpath('cache'), 'gtags-db', hash)
end

local function run_gtags(root, dbpath, incremental, on_done)
  local args = { 'gtags' }
  if incremental then
    table.insert(args, '--incremental')
  end
  table.insert(args, dbpath)
  vim.system(args, { cwd = root, env = { GTAGSROOT = root } }, on_done)
end

---@param root string
---@param message string
---@return table|nil handle a fidget.nvim ProgressHandle, or nil if fidget isn't available
local function progress_start(root, message)
  local ok, progress = pcall(require, 'fidget.progress')
  if not ok then
    return nil
  end
  return progress.handle.create({
    title = 'gtags-db',
    message = message,
    lsp_client = { name = vim.fs.basename(root) },
  })
end

---@param handle table|nil
---@param message string
local function progress_finish(handle, message)
  if handle then
    handle:report({ message = message })
    handle:finish()
  end
end

--- Kick off (or incrementally refresh) the gtags database for ROOT in the
--- background. Safe to call repeatedly per buffer event -- cheap once a
--- build is already in flight or done for this session.
---@param root string
local function ensure_build(root)
  local dbpath = db_for_root[root]
  if not dbpath then
    dbpath = cache_dir_for(root)
    vim.fn.mkdir(dbpath, 'p')
    db_for_root[root] = dbpath
  end

  if building[root] or vim.fn.executable('gtags') == 0 then
    return dbpath
  end

  local has_db = vim.fn.filereadable(vim.fs.joinpath(dbpath, 'GTAGS')) == 1
  building[root] = true
  local handle = progress_start(
    root,
    has_db and 'refreshing gtags index...' or 'building gtags index (first run, can take a while on large trees)...'
  )

  run_gtags(root, dbpath, has_db, function(res)
    if res.code == 0 or not has_db then
      building[root] = false
      if res.code ~= 0 then
        progress_finish(handle, 'build failed, see :messages')
        vim.schedule(function()
          vim.notify(
            string.format('gtags build failed for %s: %s', root, vim.trim(res.stderr or '')),
            vim.log.levels.WARN
          )
        end)
      else
        progress_finish(handle, 'index ready')
      end
      return
    end

    -- Incremental refresh failed against an existing GTAGS -- most likely
    -- truncated/corrupted by an earlier build that never finished (crash,
    -- suspend, quitting nvim mid-build). Self-heal with one full rebuild
    -- rather than leaving the database permanently broken.
    if handle then
      handle:report({ message = 'index corrupted, rebuilding from scratch...' })
    end
    vim.fn.delete(dbpath, 'rf')
    vim.fn.mkdir(dbpath, 'p')
    run_gtags(root, dbpath, false, function(res2)
      building[root] = false
      if res2.code ~= 0 then
        progress_finish(handle, 'rebuild failed, see :messages')
        vim.schedule(function()
          vim.notify(
            string.format('gtags rebuild failed for %s: %s', root, vim.trim(res2.stderr or '')),
            vim.log.levels.WARN
          )
        end)
      else
        progress_finish(handle, 'index rebuilt')
      end
    end)
  end)

  return dbpath
end

--- Returns { GTAGSROOT, GTAGSDBPATH } for the current buffer's project, or
--- nil if no project root was found. Triggers a background build/refresh
--- as a side effect. On a brand new project the first call's build hasn't
--- finished yet, so an immediate `global` query may legitimately come back
--- empty -- that's expected, not a bug (see README notes on this repo's
--- LSP-fallback setup).
function M.env_for_buffer()
  local root = find_root(vim.fn.expand('%:p:h'))
  if not root then
    return nil
  end
  return { GTAGSROOT = root, GTAGSDBPATH = ensure_build(root) }
end

--- True if a build/refresh is currently in flight for ROOT -- useful for
--- callers (lua/lsp_fallback.lua) to explain an empty query result as "the
--- index isn't ready yet" rather than "genuinely no matches".
---@param root string
function M.is_building(root)
  return building[root] == true
end

function M.setup()
  vim.api.nvim_create_autocmd('BufReadPost', {
    group = vim.api.nvim_create_augroup('gtags-db', { clear = true }),
    callback = function()
      local root = find_root(vim.fn.expand('%:p:h'))
      if root then
        ensure_build(root)
      end
    end,
  })
end

return M
-- vim: ts=2 sts=2 sw=2 et
