-- nvim_game — learn every keybinding through a flashcard game.
-- Entry point: require('nvim_game').start()
--              require('nvim_game').start_category('LSP')

local M = {}
local db = require('nvim_game.db')

--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------
local W, H   = 72, 26
local NS     = vim.api.nvim_create_namespace('nvim_game')
local LEADER = '<leader>'

-- Points awarded per correct answer; streak multiplier kicks in at 3+.
local BASE_SCORE     = 10
local STREAK_THRESH  = 3

--------------------------------------------------------------------------------
-- Highlight groups (idempotent)
--------------------------------------------------------------------------------
local function setup_hl()
  local hls = {
    NvimGameTitle    = { fg = '#FFD700', bold = true },
    NvimGameSubtitle = { fg = '#AAAAAA' },
    NvimGameCorrect  = { fg = '#44FF88', bold = true },
    NvimGameWrong    = { fg = '#FF5555', bold = true },
    NvimGameInput    = { fg = '#00CCFF', bold = true },
    NvimGameCat      = { fg = '#BB88FF', bold = true },
    NvimGameScore    = { fg = '#FFD700', bold = true },
    NvimGameMuted    = { fg = '#555566' },
    NvimGameKey      = { fg = '#FFAA33', bold = true },
    NvimGameBar      = { fg = '#44FFAA' },
    NvimGameStreak   = { fg = '#FF8800', bold = true },
    NvimGameHint     = { fg = '#777788', italic = true },
    NvimGameSel      = { fg = '#FFD700', bg = '#2a2a4a', bold = true },
    NvimGameFeedOk   = { fg = '#00FF88', bold = true },
    NvimGameFeedErr  = { fg = '#FF4444', bold = true },
  }
  for name, val in pairs(hls) do
    vim.api.nvim_set_hl(0, name, val)
  end
end

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------
local S = {}   -- game state, reset on each M.start()

local function reset_state()
  S = {
    buf        = nil,
    win        = nil,
    phase      = 'menu',   -- 'menu' | 'question' | 'feedback' | 'results'
    input      = '',
    score      = 0,
    streak     = 0,
    max_streak = 0,
    correct    = 0,
    wrong      = 0,
    skipped    = 0,
    -- question list for current session
    questions  = {},
    q_idx      = 1,
    -- categories
    categories = nil,    -- nil = all
    cat_cursor = 1,      -- menu cursor
    cat_list   = {},     -- [1..n] + 'ALL' entry
    -- feedback
    was_correct = false,
    correct_key = '',
  }
end

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------
local function pad_center(text, width)
  width = width or W
  local len = vim.fn.strdisplaywidth(text)
  local left = math.max(0, math.floor((width - len) / 2))
  return string.rep(' ', left) .. text
end

local function pad_right(text, width)
  local len = vim.fn.strdisplaywidth(text)
  return text .. string.rep(' ', math.max(0, width - len))
end

local function bar(current, total, width)
  if total == 0 then return string.rep('░', width) end
  local filled = math.floor(current / total * width)
  return string.rep('█', filled) .. string.rep('░', width - filled)
end

-- Write lines to the game buffer (clears first)
local function set_buf(lines)
  vim.bo[S.buf].modifiable = true
  vim.api.nvim_buf_set_lines(S.buf, 0, -1, false, lines)
  vim.bo[S.buf].modifiable = false
end

-- Add a highlight. line is 0-indexed.
local function hl(line, cs, ce, group)
  pcall(vim.api.nvim_buf_add_highlight, S.buf, NS, group, line, cs, ce)
end

-- Find a byte-offset in a line string for a substring (for highlight math)
local function find_hl(line_str, sub)
  local s = line_str:find(sub, 1, true)
  if s then return s - 1, s - 1 + #sub end
  return nil, nil
end

--------------------------------------------------------------------------------
-- Category helpers
--------------------------------------------------------------------------------
local function all_categories()
  local seen, list = {}, {}
  for _, kb in ipairs(db) do
    if not seen[kb.category] then
      seen[kb.category] = true
      table.insert(list, kb.category)
    end
  end
  table.sort(list)
  return list
end

local function questions_for(cats)
  local qs = {}
  for _, kb in ipairs(db) do
    if cats == nil then
      table.insert(qs, vim.deepcopy(kb))
    else
      for _, c in ipairs(cats) do
        if kb.category == c then
          table.insert(qs, vim.deepcopy(kb)); break
        end
      end
    end
  end
  -- Fisher-Yates shuffle
  math.randomseed(os.time())
  for i = #qs, 2, -1 do
    local j = math.random(i)
    qs[i], qs[j] = qs[j], qs[i]
  end
  return qs
end

--------------------------------------------------------------------------------
-- Window
--------------------------------------------------------------------------------
local function open_win()
  if S.buf and vim.api.nvim_buf_is_valid(S.buf) then
    pcall(vim.api.nvim_buf_delete, S.buf, { force = true })
  end

  S.buf = vim.api.nvim_create_buf(false, true)
  vim.bo[S.buf].bufhidden  = 'wipe'
  vim.bo[S.buf].buftype    = 'nofile'
  vim.bo[S.buf].filetype   = 'nvimgame'
  vim.bo[S.buf].modifiable = false

  local col = math.floor((vim.o.columns - W) / 2)
  local row = math.floor((vim.o.lines   - H) / 2)

  S.win = vim.api.nvim_open_win(S.buf, true, {
    relative  = 'editor',
    width     = W,
    height    = H,
    col       = col,
    row       = row,
    style     = 'minimal',
    border    = 'rounded',
    title     = '  ⌨  NEOVIM KEY MASTER  ',
    title_pos = 'center',
    zindex    = 300,
  })

  vim.wo[S.win].cursorline = false
  vim.wo[S.win].wrap       = false
  vim.wo[S.win].signcolumn = 'no'
end

local function close_win()
  if S.win and vim.api.nvim_win_is_valid(S.win) then
    vim.api.nvim_win_close(S.win, true)
  end
  if S.buf and vim.api.nvim_buf_is_valid(S.buf) then
    pcall(vim.api.nvim_buf_delete, S.buf, { force = true })
  end
  S.win, S.buf = nil, nil
end

--------------------------------------------------------------------------------
-- Key mapping (game buffer)
--------------------------------------------------------------------------------
local function clear_keys()
  pcall(vim.api.nvim_buf_clear_namespace, S.buf, NS, 0, -1)
end

local function bind(key, action, modes)
  modes = modes or { 'n' }
  vim.keymap.set(modes, key, function()
    M.handle_key(action)
  end, { buffer = S.buf, nowait = true, silent = true })
end

local function setup_keys()
  -- All printable keys that appear in keybindings
  local alpha = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
  local digits = '1234567890'
  local puncts = { '[', ']', '.', '/', ';', ',', "'", '-', '=' }

  for i = 1, #alpha do  bind(alpha:sub(i,i), alpha:sub(i,i)) end
  for i = 1, #digits do bind(digits:sub(i,i), digits:sub(i,i)) end
  for _, c in ipairs(puncts) do bind(c, c) end

  -- Space = <leader> in answers
  bind('<Space>', LEADER)

  -- Control combos used as keybindings
  for _, c in ipairs({ 'h', 'j', 'k', 'l', 's' }) do
    bind('<C-' .. c .. '>', '<C-' .. c .. '>')
  end

  -- Game control
  bind('<CR>',  '__submit__')
  bind('<BS>',  '__bs__')
  bind('<Esc>', '__quit__')

  -- Menu navigation
  bind('j', '__down__')
  bind('k', '__up__')
  -- 'j' and 'k' also get bound above to append; we'll route them correctly
  -- in handle_key based on phase.
end

--------------------------------------------------------------------------------
-- Rendering helpers
--------------------------------------------------------------------------------
local DIVIDER = string.rep('─', W)

local function render_header(lines, hls_list)
  -- Score bar
  local total = #S.questions
  local done  = S.q_idx - 1
  local pct   = total > 0 and math.floor(done / total * 100) or 0
  local streak_txt = S.streak >= STREAK_THRESH
    and ('  🔥 ×' .. S.streak)
    or  ('  streak: ' .. S.streak)

  local score_line = pad_right(
    string.format(' Score: %-6d%s', S.score, streak_txt), W)
  local prog_line  = pad_right(
    string.format(' Q %d/%d  [%s] %d%%',
      math.min(S.q_idx, total), total,
      bar(done, total, 20), pct), W)

  table.insert(lines, score_line)
  table.insert(lines, prog_line)
  table.insert(lines, DIVIDER)

  local li = #lines
  table.insert(hls_list, { li - 2, 0, -1, 'NvimGameScore' })
  table.insert(hls_list, { li - 1, 0, -1, 'NvimGameBar' })
  table.insert(hls_list, { li,     0, -1, 'NvimGameMuted' })
end

--------------------------------------------------------------------------------
-- Phase: MENU
--------------------------------------------------------------------------------
local function render_menu()
  local cats = all_categories()
  S.cat_list = vim.list_extend({ 'ALL CATEGORIES' }, cats)
  if S.cat_cursor < 1 then S.cat_cursor = #S.cat_list end
  if S.cat_cursor > #S.cat_list then S.cat_cursor = 1 end

  local lines, hls_list = {}, {}

  -- Title block
  table.insert(lines, '')
  table.insert(lines, pad_center('⌨   NEOVIM KEY MASTER'))
  table.insert(lines, pad_center('Learn your keybindings the fun way'))
  table.insert(lines, '')
  table.insert(lines, DIVIDER)
  table.insert(lines, '')
  table.insert(lines, pad_center('Select a category to practice:'))
  table.insert(lines, '')

  local title_line = 1
  hls_list[#hls_list+1] = { title_line, 0, -1, 'NvimGameTitle' }
  hls_list[#hls_list+1] = { title_line+1, 0, -1, 'NvimGameSubtitle' }
  hls_list[#hls_list+1] = { title_line+3, 0, -1, 'NvimGameMuted' }

  for i, cat in ipairs(S.cat_list) do
    local count = 0
    if cat == 'ALL CATEGORIES' then
      count = #db
    else
      for _, kb in ipairs(db) do
        if kb.category == cat then count = count + 1 end
      end
    end
    local marker = (i == S.cat_cursor) and '▶ ' or '  '
    local entry  = string.format('%s%-22s  (%d keybindings)', marker, cat, count)
    table.insert(lines, pad_center(entry))
    local li = #lines
    if i == S.cat_cursor then
      hls_list[#hls_list+1] = { li - 1, 0, -1, 'NvimGameSel' }
    else
      hls_list[#hls_list+1] = { li - 1, 0, -1, 'NvimGameSubtitle' }
    end
  end

  table.insert(lines, '')
  table.insert(lines, DIVIDER)
  table.insert(lines, pad_center('j/k  navigate    <Enter>  start    <Esc>  quit'))
  local last = #lines
  hls_list[#hls_list+1] = { last - 1, 0, -1, 'NvimGameMuted' }
  hls_list[#hls_list+1] = { last,     0, -1, 'NvimGameMuted' }

  -- Pad to window height
  while #lines < H do table.insert(lines, '') end

  set_buf(lines)
  vim.api.nvim_buf_clear_namespace(S.buf, NS, 0, -1)
  for _, h in ipairs(hls_list) do
    hl(h[1], h[2], h[3], h[4])
  end
end

--------------------------------------------------------------------------------
-- Phase: QUESTION
--------------------------------------------------------------------------------
local function current_q()
  return S.questions[S.q_idx]
end

local function render_question()
  local q     = current_q()
  if not q then M.finish(); return end

  local lines, hls_list = {}, {}
  table.insert(lines, '')

  -- Header (score / progress)
  render_header(lines, hls_list)

  table.insert(lines, '')
  -- Category badge
  local cat_line = pad_center('[ ' .. q.category .. ' ]')
  table.insert(lines, cat_line)
  hls_list[#hls_list+1] = { #lines - 1, 0, -1, 'NvimGameCat' }

  table.insert(lines, '')

  -- Description box
  local desc = q.desc
  -- Wrap description to W-6 chars
  local max_desc_w = W - 6
  local wrapped = {}
  while #desc > max_desc_w do
    local break_at = max_desc_w
    while break_at > 1 and desc:sub(break_at, break_at) ~= ' ' do
      break_at = break_at - 1
    end
    if break_at == 1 then break_at = max_desc_w end
    table.insert(wrapped, desc:sub(1, break_at))
    desc = vim.trim(desc:sub(break_at + 1))
  end
  table.insert(wrapped, desc)

  local box_w = max_desc_w + 4
  local box_pad = string.rep(' ', math.floor((W - box_w) / 2))

  table.insert(lines, box_pad .. '┌' .. string.rep('─', box_w - 2) .. '┐')
  for _, wl in ipairs(wrapped) do
    local inner = pad_right('  ' .. wl, box_w - 2)
    table.insert(lines, box_pad .. '│' .. inner .. '│')
    hls_list[#hls_list+1] = { #lines - 1, #box_pad + 1, #box_pad + 1 + #inner, 'NvimGameTitle' }
  end
  table.insert(lines, box_pad .. '└' .. string.rep('─', box_w - 2) .. '┘')

  -- Hint (if any)
  if q.hint then
    table.insert(lines, '')
    local hl_line = pad_center('💡 ' .. q.hint)
    table.insert(lines, hl_line)
    hls_list[#hls_list+1] = { #lines - 1, 0, -1, 'NvimGameHint' }
  end

  table.insert(lines, '')

  -- Input field
  local input_display = S.input == '' and '▋' or (S.input .. '▋')
  local input_line = pad_center('Answer: ' .. input_display)
  table.insert(lines, input_line)
  local il = #lines - 1
  local s, e = find_hl(lines[il + 1], input_display)
  if s then hls_list[#hls_list+1] = { il, s + math.floor((W - #lines[il+1]) / 2), -1, 'NvimGameInput' } end

  table.insert(lines, '')
  table.insert(lines, DIVIDER)
  table.insert(lines, pad_center('<Space>=<leader>  <Enter> submit  <BS> backspace  <Esc> quit'))
  hls_list[#hls_list+1] = { #lines - 1, 0, -1, 'NvimGameMuted' }

  while #lines < H do table.insert(lines, '') end
  set_buf(lines)
  vim.api.nvim_buf_clear_namespace(S.buf, NS, 0, -1)
  for _, h in ipairs(hls_list) do hl(h[1], h[2], h[3], h[4]) end
end

--------------------------------------------------------------------------------
-- Phase: FEEDBACK
--------------------------------------------------------------------------------
local function render_feedback()
  local q = S.questions[S.q_idx - 1] or S.questions[#S.questions]

  local lines, hls_list = {}, {}
  table.insert(lines, '')
  render_header(lines, hls_list)
  table.insert(lines, '')
  table.insert(lines, '')

  if S.was_correct then
    local pts = BASE_SCORE * (S.streak >= STREAK_THRESH and S.streak or 1)
    table.insert(lines, pad_center('✓  CORRECT!'))
    hls_list[#hls_list+1] = { #lines - 1, 0, -1, 'NvimGameCorrect' }
    table.insert(lines, '')
    table.insert(lines, pad_center(string.format('+%d points', pts)
      .. (S.streak >= STREAK_THRESH and string.format('  (×%d streak!)', S.streak) or '')))
    hls_list[#hls_list+1] = { #lines - 1, 0, -1, 'NvimGameScore' }
  else
    table.insert(lines, pad_center('✗  WRONG'))
    hls_list[#hls_list+1] = { #lines - 1, 0, -1, 'NvimGameWrong' }
    table.insert(lines, '')
    local you_line = pad_center('You typed:   ' .. (S.input ~= '' and S.input or '(empty)'))
    table.insert(lines, you_line)
    hls_list[#hls_list+1] = { #lines - 1, 0, -1, 'NvimGameSubtitle' }
  end

  table.insert(lines, '')
  local ans_line = pad_center('Correct:     ' .. q.key)
  table.insert(lines, ans_line)
  local al = #lines - 1
  local ks, ke = find_hl(lines[al + 1], q.key)
  if ks then
    local off = math.floor((W - vim.fn.strdisplaywidth(lines[al + 1])) / 2)
    hls_list[#hls_list+1] = { al, off + ks, off + ke, 'NvimGameKey' }
  end

  if not S.was_correct then
    table.insert(lines, '')
    table.insert(lines, pad_center('↺  Added back to retry queue'))
    hls_list[#hls_list+1] = { #lines - 1, 0, -1, 'NvimGameHint' }
  end

  table.insert(lines, '')
  table.insert(lines, '')
  table.insert(lines, DIVIDER)
  table.insert(lines, pad_center('<Enter> or any key → next question'))
  hls_list[#hls_list+1] = { #lines - 1, 0, -1, 'NvimGameMuted' }

  while #lines < H do table.insert(lines, '') end
  set_buf(lines)
  vim.api.nvim_buf_clear_namespace(S.buf, NS, 0, -1)
  for _, h in ipairs(hls_list) do hl(h[1], h[2], h[3], h[4]) end
end

--------------------------------------------------------------------------------
-- Phase: RESULTS
--------------------------------------------------------------------------------
local function render_results()
  local total   = S.correct + S.wrong + S.skipped
  local acc     = total > 0 and math.floor(S.correct / total * 100) or 0
  local grade
  if acc >= 90 then grade = 'S  — Vim Grandmaster'
  elseif acc >= 75 then grade = 'A  — Keyboard Ninja'
  elseif acc >= 60 then grade = 'B  — Getting There'
  elseif acc >= 40 then grade = 'C  — Keep Practicing'
  else grade = 'D  — Back to Basics' end

  local lines, hls_list = {}, {}
  table.insert(lines, '')
  table.insert(lines, pad_center('━━━  SESSION COMPLETE  ━━━'))
  hls_list[#hls_list+1] = { 0, 0, -1, 'NvimGameTitle' }
  table.insert(lines, '')
  table.insert(lines, pad_center('Grade: ' .. grade))
  hls_list[#hls_list+1] = { #lines - 1, 0, -1,
    acc >= 75 and 'NvimGameCorrect' or (acc >= 50 and 'NvimGameScore' or 'NvimGameWrong') }
  table.insert(lines, '')
  table.insert(lines, DIVIDER)

  local stats = {
    { 'Final score',   tostring(S.score)   },
    { 'Correct',       string.format('%d / %d (%d%%)', S.correct, total, acc) },
    { 'Wrong',         tostring(S.wrong)   },
    { 'Skipped',       tostring(S.skipped) },
    { 'Best streak',   tostring(S.max_streak) },
  }
  for _, row in ipairs(stats) do
    local line = pad_center(string.format('%-20s %s', row[1], row[2]))
    table.insert(lines, line)
  end

  table.insert(lines, '')
  table.insert(lines, DIVIDER)
  table.insert(lines, pad_center('<Enter> play again   <Esc> quit'))
  hls_list[#hls_list+1] = { #lines - 1, 0, -1, 'NvimGameMuted' }

  while #lines < H do table.insert(lines, '') end
  set_buf(lines)
  vim.api.nvim_buf_clear_namespace(S.buf, NS, 0, -1)
  for _, h in ipairs(hls_list) do hl(h[1], h[2], h[3], h[4]) end
end

--------------------------------------------------------------------------------
-- Render dispatcher
--------------------------------------------------------------------------------
local function render()
  if not (S.buf and vim.api.nvim_buf_is_valid(S.buf)) then return end
  vim.api.nvim_buf_clear_namespace(S.buf, NS, 0, -1)
  if     S.phase == 'menu'     then render_menu()
  elseif S.phase == 'question' then render_question()
  elseif S.phase == 'feedback' then render_feedback()
  elseif S.phase == 'results'  then render_results()
  end
end

--------------------------------------------------------------------------------
-- Game logic
--------------------------------------------------------------------------------
function M.finish()
  S.phase = 'results'
  render()
end

local function advance()
  if S.q_idx > #S.questions then
    M.finish()
  else
    S.phase = 'question'
    S.input = ''
    render()
  end
end

local function submit()
  local q = current_q()
  if not q then return end

  local answer  = vim.trim(S.input)
  local correct = (answer == q.key)

  S.was_correct = correct
  S.q_idx       = S.q_idx + 1

  if correct then
    S.streak     = S.streak + 1
    if S.streak > S.max_streak then S.max_streak = S.streak end
    local mult   = S.streak >= STREAK_THRESH and S.streak or 1
    S.score      = S.score + BASE_SCORE * mult
    S.correct    = S.correct + 1
  else
    -- Re-queue the question at a random later position
    local requeue_at = math.random(S.q_idx, #S.questions + 1)
    table.insert(S.questions, requeue_at, vim.deepcopy(q))
    S.streak = 0
    S.wrong  = S.wrong + 1
  end

  S.phase = 'feedback'
  render()
end

local function skip()
  local q = current_q()
  if not q then return end
  -- Re-queue the skipped question
  local requeue_at = math.random(S.q_idx + 1, #S.questions + 1)
  table.insert(S.questions, requeue_at, vim.deepcopy(q))
  S.q_idx   = S.q_idx + 1
  S.streak  = 0
  S.skipped = S.skipped + 1
  S.phase   = 'feedback'
  S.was_correct = false
  render()
end

--------------------------------------------------------------------------------
-- Key handler (all phases)
--------------------------------------------------------------------------------
function M.handle_key(action)
  if S.phase == 'menu' then
    if action == '__down__' or action == 'j' then
      S.cat_cursor = S.cat_cursor % #S.cat_list + 1
      render()
    elseif action == '__up__' or action == 'k' then
      S.cat_cursor = ((S.cat_cursor - 2) % #S.cat_list) + 1
      render()
    elseif action == '__submit__' then
      local sel  = S.cat_list[S.cat_cursor]
      local cats = sel ~= 'ALL CATEGORIES' and { sel } or nil
      S.categories = cats
      S.questions  = questions_for(cats)
      S.q_idx      = 1
      S.phase      = 'question'
      S.input      = ''
      render()
    elseif action == '__quit__' then
      close_win()
    end

  elseif S.phase == 'question' then
    if action == '__submit__' then
      submit()
    elseif action == '__bs__' then
      -- Remove last token: if ends with '>', strip back to '<'
      if S.input:sub(-1) == '>' then
        local p = S.input:find('<[^<>]*>$')
        S.input = p and S.input:sub(1, p - 1) or S.input:sub(1, -2)
      else
        S.input = S.input:sub(1, -2)
      end
      render()
    elseif action == '__quit__' then
      -- Esc from question → skip
      skip()
    elseif action ~= '__down__' and action ~= '__up__' then
      -- Regular character or special token
      S.input = S.input .. action
      render()
    end

  elseif S.phase == 'feedback' then
    -- Any key advances
    if action == '__quit__' then
      close_win()
      return
    end
    advance()

  elseif S.phase == 'results' then
    if action == '__quit__' then
      close_win()
    elseif action == '__submit__' then
      -- Play again — back to menu
      S.score, S.streak, S.max_streak = 0, 0, 0
      S.correct, S.wrong, S.skipped   = 0, 0, 0
      S.phase    = 'menu'
      S.cat_cursor = 1
      render()
    end
  end
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------
function M.start(cats)
  setup_hl()
  reset_state()
  S.categories = cats
  open_win()
  setup_keys()

  if cats then
    S.questions = questions_for(cats)
    S.phase     = 'question'
  else
    -- Show menu so user can pick category
    S.cat_list   = vim.list_extend({ 'ALL CATEGORIES' }, all_categories())
    S.cat_cursor = 1
    S.phase      = 'menu'
  end
  render()
end

function M.start_category(cat)
  M.start({ cat })
end

return M
