# nvim_game — Keybinding Learning Game

## How it works

### Architecture

```
lua/nvim_game/
  db.lua      keybinding database (source of truth)
  init.lua    game engine + UI renderer
  PLAN.md     this file

lua/plugins/
  nvim_game.lua   lazy.nvim spec (<leader>G to launch)
```

The plugin is a pure-Lua, zero-dependency floating-window game.
No external packages required.

---

### Game loop

```
start()
  └─ show MENU (category select)
       └─ <Enter> → build question queue → QUESTION phase
            ├─ user types answer char by char
            ├─ <Space> inserts "<leader>" token
            ├─ <BS> removes last token (bracket-aware)
            ├─ <C-c> skips the question (re-queues it)
            └─ <Enter> submits
                 ├─ correct → score + streak → FEEDBACK
                 └─ wrong   → re-insert at random later position → FEEDBACK
                      └─ any key → QUESTION (next)
                           └─ queue exhausted → RESULTS
                                ├─ <Enter> → back to MENU
                                └─ <C-c>  → close window
```

### Scoring

| Condition | Points |
|---|---|
| Correct answer | 10 × streak_multiplier |
| Streak < 3 | multiplier = 1 |
| Streak ≥ 3 | multiplier = streak count |
| Wrong / skip | streak resets to 0 |

### Spaced repetition (basic)

Wrong and skipped questions are re-inserted at a random index
`[current_idx+1 .. end_of_queue]`. This means a question you get wrong
early will resurface later in the same session. There is no cross-session
memory yet (see planned features).

### Key capture mechanism

The floating window buffer maps every printable key (a-z, A-Z, 0-9,
punctuation, Ctrl/Alt combos) to `M.handle_key(token)` via buffer-local
normal-mode keymaps with `nowait = true`. The buffer is `buftype=nofile,
modifiable=false` so nothing is ever written to it directly.

Special tokens:
- `<Space>` → appends the literal string `<leader>`
- `<C-h>` → appends `<C-h>` (the full token, used as a keybinding)
- `<C-c>` → skips a question or closes the game
- `<BS>`  → removes the last token; if the input ends with `>`, it strips
            the entire `<...>` bracket group so `<C-h>` is deleted as one unit

---

## Known issues / bugs

### Input

- **`<leader><leader>`** (two consecutive leaders) types as `<leader><leader>`
  correctly, but the render cursor `▋` may shift slightly due to how display
  width is calculated for the input line.

- **Control keys that look like printable chars**: `<C-i>` = Tab, `<C-m>` = CR
  in most terminals. These bindings cannot currently be practiced because the
  terminal sends the same byte as Tab/Enter.

- **Modifier keys beyond Ctrl and Alt**: `<D-x>` / Super bindings are not in
  the keymap table. The current configuration does not use them.

- **Multi-key non-leader prefixes**: `gq`, `gr`, `gd`, `gI`, `gD` start with
  `g`. Pressing `g` appends `g`, then `q` appends `q`, giving `gq` correctly.
  Works fine. No known issue — just documenting the mechanism.

### Menu

- **`j` / `k` dual role**: In question phase, `j` and `k` are bound to append
  `j` / `k` to the answer. In menu phase, the same handle_key routes them to
  cursor movement. This is intentional but means if menu phase falls through to
  the regular char handler, you'd type `j` into the answer. Guard logic in
  `handle_key` prevents this, but it is fragile.

### Rendering

- **Long descriptions**: wrap logic breaks on spaces. A word longer than
  `W - 6 = 66` chars will overflow the box. All current db entries fit.

- **Window resize**: The floating window position is computed once at open
  time. Resizing the terminal while the game is open will leave the window
  misaligned. Workaround: close and reopen with `<leader>G`.

- **Highlight offsets**: `find_hl` uses byte offsets but `strdisplaywidth`
  uses display cells. For pure ASCII content this is identical. Any entry
  with multi-byte characters in key or desc would shift highlights.

### Database

- The database covers user-facing global mappings and LSP/Gitsigns/Aerial
  buffer-local mappings. It intentionally excludes plugin-internal window
  controls (for example, Aerial's outline-window controls).

- **Textobject entries (`aF`, `iF`, etc.)** are not really "press this key"
  bindings — they are operator suffixes. Practicing them as standalone answers
  is valid but the feedback wording could be clearer (e.g. "used after an
  operator like d, c, v, y").

---

## Planned features

### P0 — correctness / UX

- [ ] **Auto-advance on exact match**: detect when the typed input already
      matches a known key exactly and auto-submit after a short delay (300 ms),
      removing the need to press `<Enter>` for short bindings. Keep `<Enter>`
      as an explicit submit override.

- [x] **Correct textobjects module path**: was `nvim-treesitter.textobjects.move`
      (old pre-2024 path, no longer exists); fixed to `nvim-treesitter-textobjects.move`
      which is the current hyphenated namespace used after the plugin rewrite.

- [ ] **Correct `j`/`k` binding separation**: give the menu its own keymap
      setup distinct from the question keymap setup, so `j`/`k` are only
      ambiguous in the transition frame.

- [ ] **Window resize autocmd**: listen on `VimResized` and reposition/reopen
      the window automatically.

- [ ] **Cleaner textobject question wording**: prefix description with
      "In operator-pending or visual mode — " for textobject entries so the
      question makes sense without extra thought.

### P1 — learning quality

- [ ] **Cross-session progress persistence**: save per-key statistics (times
      seen, times correct, last seen date) to a JSON file in
      `stdpath('data')/nvim_game_progress.json`. Use SM-2 or a simple
      exponential backoff to schedule re-review intervals.

- [ ] **"Hard" flag**: let the user mark a question as hard during feedback
      (press `h`). Hard questions appear 3× more often in the session.

- [ ] **Hint system**: press `?` during a question to reveal a partial hint:
      - first `?` reveals the category
      - second `?` reveals the first character of the answer
      - third `?` reveals the full answer (but awards 0 points)

- [ ] **Reverse mode**: flip the game — show the keybinding, user types the
      description (free-text, fuzzy-matched). Harder and more useful for
      deeply internalising bindings.

- [ ] **Multiple-choice mode**: instead of free-text input, show 4 keybinding
      options and press the number 1–4. Lower cognitive load — good for first
      exposure to a new category.

### P2 — gamification

- [ ] **Persistent high score table**: top 5 scores per category, stored in
      `stdpath('data')/nvim_game_scores.json`, shown on the results screen.

- [ ] **Achievements**: unlockable badges shown on the results screen.
      Examples:
      - "Streak x10" — get 10 correct in a row
      - "LSP Master" — 100% on LSP category
      - "Speed Demon" — answer 5 in a row in under 3 seconds each
      - "No Hints" — complete a session without pressing `?`

- [ ] **Daily challenge**: a fixed seed each day generates the same 10-question
      set for everyone. Score is comparable across sessions on the same day.

- [ ] **Timed mode**: optional countdown per question (e.g. 10 seconds).
      Unanswered questions are auto-skipped. Adds pressure and speeds up
      learning.

### P3 — content

- [ ] **Auto-discovery mode**: instead of a hand-written db, scan
      `vim.api.nvim_get_keymap('n')` and all buffer-local maps at startup,
      extract desc strings, and build the question list dynamically. Would
      capture every binding including ones added after this file was written.
      Challenge: many keymaps have no `desc` or have generic descs.

- [ ] **Plugin-specific drill packs**: curated question sets for "DAP only",
      "Git workflow end-to-end" (ordered sequence of related keys), etc.

- [ ] **Custom user entries**: let the user add their own q&a pairs via a
      simple config table in the lazy spec, merged with the built-in db at
      startup.

---

## File layout (target state)

```
lua/nvim_game/
  db.lua            built-in keybinding database
  init.lua          game engine + UI + key capture
  progress.lua      (planned) cross-session SM-2 progress tracker
  scores.lua        (planned) high score / achievement persistence
  discovery.lua     (planned) auto-discover keymaps from vim API
  PLAN.md           this file
```
