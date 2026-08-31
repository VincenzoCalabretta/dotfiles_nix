# LeetCode Cookie Copier

Companion to `../harness.lua` and `plugins/leetcode.lua`'s `:Leet cookie
update` flow — not a Neovim plugin itself (there's no Lua here, just a
WebExtension), grouped under `leetcode_modules/` since it's the other
piece of getting leetcode.nvim usable end to end.

A minimal Firefox WebExtension: click the toolbar icon while logged into
leetcode.com (or leetcode.cn), and it copies

```
csrftoken=<value>; LEETCODE_SESSION=<value>
```

to your clipboard, ready to paste into `:Leet cookie update` in
[leetcode.nvim](https://github.com/kawre/leetcode.nvim). No native
messaging host, no local server — it only reads cookies via the
`cookies` permission (scoped to leetcode.com/leetcode.cn) and writes to
the clipboard.

Badge turns green (✓) on success, red (✗) if you're not logged in / the
cookies aren't found.

## Install (temporary, until Firefox restarts)

Firefox's release channel only runs unsigned extensions loaded this way:

1. Go to `about:debugging#/runtime/this-firefox`.
2. Click **Load Temporary Add-on…**.
3. Select `manifest.json` in this directory.

It stays loaded until you restart Firefox, then you repeat the three
steps. Given this is only used when the LeetCode session cookie expires
(every few weeks), that's a minor inconvenience rather than something
worth signing/packaging.

If you want it to persist across restarts without reloading, that
requires either Firefox Developer Edition/Nightly/ESR with
`xpinstall.signatures.required` set to `false` in `about:config`
(not available on release Firefox), or submitting it to
addons.mozilla.org for signing (overkill for a personal tool).

## Usage

1. Log into leetcode.com (or leetcode.cn) in this Firefox profile, on
   any tab.
2. Click the toolbar icon (puzzle-piece menu → pin it for one-click
   access, or just click it from there each time).
3. Badge flashes green (✓) — the cookie string is now on your
   clipboard. A red (✗) badge means it couldn't find both cookies;
   make sure you're actually logged in on that domain.
4. In Neovim: `:Leet cookie update`, paste (`<C-r>+` in insert mode, or
   your terminal/GUI's normal paste), press Enter.

Repeat whenever `:Leet` starts failing with an auth error — that means
`LEETCODE_SESSION` expired and you need a fresh cookie.

## Security notes

- The clipboard briefly holds your LEETCODE_SESSION token after
  clicking. Paste it into `:Leet cookie update` promptly; avoid pasting
  it anywhere else.
- The extension only requests host permissions for leetcode.com/.cn and
  the `cookies` + `clipboardWrite` APIs — it can't read cookies for any
  other site.
