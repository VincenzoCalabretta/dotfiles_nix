-- User-facing global and LSP/Gitsigns/Aerial buffer-local keybinding database for nvim_game.
-- Each entry: { key, desc, category, hint (optional) }
-- 'key' uses the exact notation the user would type/see in config.

local mappings = {
	-- ── LSP ────────────────────────────────────────────────────────────────────
	{ key = "gd", desc = "Go to definition of symbol under cursor", category = "LSP" },
	{ key = "gr", desc = "List all references to symbol", category = "LSP" },
	{ key = "gI", desc = "Go to implementation of symbol", category = "LSP" },
	{ key = "gD", desc = "Go to declaration (not definition)", category = "LSP" },
	{ key = "K", desc = "Show hover documentation popup", category = "LSP" },
	{ key = "<leader>D", desc = "Jump to type definition", category = "LSP" },
	{ key = "<leader>rn", desc = "Rename symbol under cursor", category = "LSP" },
	{ key = "<leader>ca", desc = "Open code actions menu", category = "LSP" },
	{ key = "<leader>f", desc = "Format entire buffer via LSP", category = "LSP" },
	{ key = "gq", desc = "Format buffer (normal) or selection (visual) via LSP", category = "LSP" },
	{ key = "<leader>ds", desc = "Search document symbols (Telescope)", category = "LSP" },
	{ key = "<leader>ws", desc = "Search workspace symbols (Telescope)", category = "LSP" },
	{ key = "<leader>th", desc = "Toggle inlay hints on/off", category = "LSP" },
	{ key = "<leader>cl", desc = "Run code lens action under cursor", category = "LSP" },

	-- ── Diagnostics ────────────────────────────────────────────────────────────
	{ key = "[d", desc = "Jump to previous diagnostic", category = "Diagnostics" },
	{ key = "]d", desc = "Jump to next diagnostic", category = "Diagnostics" },
	{ key = "<leader>e", desc = "Show diagnostic under cursor in float", category = "Diagnostics" },
	{ key = "<leader>q", desc = "Send all diagnostics to location list", category = "Diagnostics" },
	{ key = "<leader>sd", desc = "Search diagnostics with Telescope", category = "Diagnostics" },

	-- ── Git — gitsigns ─────────────────────────────────────────────────────────
	{ key = "]c", desc = "Jump to next git hunk", category = "Git" },
	{ key = "[c", desc = "Jump to previous git hunk", category = "Git" },
	{ key = "<leader>hs", desc = "Stage hunk under cursor", category = "Git" },
	{ key = "<leader>hr", desc = "Reset hunk under cursor", category = "Git" },
	{ key = "<leader>hS", desc = "Stage entire buffer", category = "Git" },
	{ key = "<leader>hu", desc = "Undo the last staged hunk", category = "Git" },
	{ key = "<leader>hR", desc = "Reset entire buffer to index state", category = "Git" },
	{ key = "<leader>hp", desc = "Preview hunk diff in float", category = "Git" },
	{ key = "<leader>hb", desc = "Show git blame for current line", category = "Git" },
	{ key = "<leader>hd", desc = "Diff buffer against git index", category = "Git" },
	{ key = "<leader>hD", desc = "Diff buffer against last commit", category = "Git" },
	{ key = "<leader>tb", desc = "Toggle persistent inline git blame", category = "Git" },
	{ key = "<leader>tD", desc = "Toggle display of deleted git lines", category = "Git" },

	-- ── Git — diffview / git_branch_inspect ────────────────────────────────────
	{ key = "<leader>gC", desc = "Close diffview panel", category = "Git" },
	{ key = "<leader>gh", desc = "Open diffview file history for current file", category = "Git" },
	{ key = "<leader>gH", desc = "Open diffview repo-wide file history", category = "Git" },
	{ key = "<leader>gb", desc = "Browse files from a specific git branch", category = "Git" },
	{ key = "<leader>gd", desc = "Quick diff current file against a branch", category = "Git" },
	{ key = "<leader>gg", desc = "Open Neogit status", category = "Git" },
	{ key = "<leader>gD", desc = "Open full Diffview panel", category = "Git" },

	-- ── Telescope ──────────────────────────────────────────────────────────────
	{ key = "<leader>sf", desc = "Find files in project root", category = "Telescope" },
	{ key = "<leader>sg", desc = "Live grep across project", category = "Telescope" },
	{ key = "<leader>sw", desc = "Grep for word under cursor", category = "Telescope" },
	{ key = "<leader>sh", desc = "Search Neovim help tags", category = "Telescope" },
	{ key = "<leader>sk", desc = "Browse all defined keymaps", category = "Telescope" },
	{ key = "<leader>ss", desc = "Pick a Telescope built-in picker", category = "Telescope" },
	{ key = "<leader>sr", desc = "Resume the last Telescope search", category = "Telescope" },
	{ key = "<leader>s.", desc = "Browse recently opened files", category = "Telescope" },
	{ key = "<leader><leader>", desc = "Switch between open buffers", category = "Telescope" },
	{ key = "<leader>/", desc = "Fuzzy search inside current buffer", category = "Telescope" },
	{ key = "<leader>s/", desc = "Live grep in open files only", category = "Telescope" },
	{ key = "<leader>sn", desc = "Find files inside Neovim config directory", category = "Telescope" },
	{ key = "<leader>ep", desc = "Browse installed lazy.nvim plugins", category = "Telescope" },

	-- ── Harpoon ────────────────────────────────────────────────────────────────
	{ key = "<leader>ha", desc = "Pin current file to Harpoon list", category = "Harpoon" },
	{ key = "<leader>hh", desc = "Open Harpoon quick menu", category = "Harpoon" },
	{ key = "<leader>1", desc = "Jump to Harpoon pin #1", category = "Harpoon" },
	{ key = "<leader>2", desc = "Jump to Harpoon pin #2", category = "Harpoon" },
	{ key = "<leader>3", desc = "Jump to Harpoon pin #3", category = "Harpoon" },
	{ key = "<leader>4", desc = "Jump to Harpoon pin #4", category = "Harpoon" },
	{ key = "<leader>h]", desc = "Cycle to next Harpoon pin", category = "Harpoon" },
	{ key = "<leader>h[", desc = "Cycle to previous Harpoon pin", category = "Harpoon" },

	-- ── Aerial (code outline) ──────────────────────────────────────────────────
	{ key = "<leader>a", desc = "Toggle aerial code outline panel", category = "Navigation" },
	{ key = "<leader>ao", desc = "Open aerial outline", category = "Navigation" },
	{ key = "<leader>ac", desc = "Close aerial outline", category = "Navigation" },
	{ key = "<leader>aO", desc = "Open all nodes in aerial outline", category = "Navigation" },
	{ key = "<leader>aC", desc = "Close all nodes in aerial outline", category = "Navigation" },
	{ key = "<leader>an", desc = "Jump to next symbol in aerial", category = "Navigation" },
	{ key = "<leader>ap", desc = "Jump to previous symbol in aerial", category = "Navigation" },
	{ key = "<leader>ag", desc = "Jump to a symbol in aerial outline", category = "Navigation" },
	{ key = "<leader>aN", desc = "Toggle aerial navigation floating window", category = "Navigation" },
	{ key = "<leader>ai", desc = "Show aerial information", category = "Navigation" },
	{ key = "<leader>as", desc = "Search aerial symbols with Telescope", category = "Navigation" },
	{ key = "<leader>af", desc = "Search aerial symbols with FZF-Lua", category = "Navigation" },
	{ key = "<leader>aS", desc = "Search aerial symbols with Snacks", category = "Navigation" },
	{ key = "{", desc = "Jump to previous Aerial symbol", category = "Navigation" },
	{ key = "}", desc = "Jump to next Aerial symbol", category = "Navigation" },
	{ key = "[[", desc = "Jump to previous enclosing Aerial symbol", category = "Navigation" },
	{ key = "]]", desc = "Jump to next enclosing Aerial symbol", category = "Navigation" },

	-- ── Treesitter motions ────────────────────────────────────────────────────
	{ key = "]m", desc = "Jump to start of next function", category = "Navigation" },
	{ key = "[m", desc = "Jump to start of previous function", category = "Navigation" },
	{ key = "]M", desc = "Jump to end of next function", category = "Navigation" },
	{ key = "[M", desc = "Jump to end of previous function", category = "Navigation" },
	{ key = "[C", desc = "Jump up to outer treesitter context", category = "Navigation" },

	-- ── Flash ─────────────────────────────────────────────────────────────────
	{ key = "s", desc = "Flash: type 2 chars then pick a jump label", category = "Navigation" },
	{ key = "S", desc = "Flash treesitter: select any visible TS node", category = "Navigation" },
	{ key = "r", desc = "Flash remote motion (operator-pending mode)", category = "Navigation" },
	{ key = "R", desc = "Flash Treesitter search (operator/visual mode)", category = "Navigation" },
	{ key = "<c-s>", desc = "Toggle Flash search (command-line mode)", category = "Navigation" },

	-- ── Textobjects (mini.ai + treesitter) ────────────────────────────────────
	{
		key = "aF",
		desc = "Textobject: AROUND function declaration",
		category = "Textobjects",
		hint = "Use with operators: daF, caF, vaF, yaF",
	},
	{
		key = "iF",
		desc = "Textobject: INSIDE function declaration body",
		category = "Textobjects",
		hint = "Use with operators: diF, ciF, viF, yiF",
	},
	{
		key = "aC",
		desc = "Textobject: AROUND class / struct / impl",
		category = "Textobjects",
		hint = "Use with operators: daC, caC, vaC, yaC",
	},
	{
		key = "iC",
		desc = "Textobject: INSIDE class / struct / impl",
		category = "Textobjects",
		hint = "Use with operators: diC, ciC, viC, yiC",
	},
	{
		key = "af",
		desc = "Textobject: AROUND function call (args+parens)",
		category = "Textobjects",
		hint = "mini.ai: covers the call site, e.g. foo(a, b)",
	},
	{
		key = "if",
		desc = "Textobject: INSIDE function call arguments",
		category = "Textobjects",
		hint = "mini.ai: just the argument list, not the parens",
	},

	-- ── DAP (debugging) ───────────────────────────────────────────────────────
	{ key = "<M-c>", desc = "Continue or start a debug session", category = "DAP" },
	{ key = "<M-a>", desc = "Continue all active debug sessions", category = "DAP" },
	{ key = "<M-t>", desc = "Terminate the active debug session", category = "DAP" },
	{ key = "<M-b>", desc = "Toggle a breakpoint on the current line", category = "DAP" },
	{ key = "<M-B>", desc = "Set a conditional breakpoint", category = "DAP" },
	{ key = "<M-n>", desc = "Step over the current line", category = "DAP" },
	{ key = "<M-s>", desc = "Step into the current function call", category = "DAP" },
	{ key = "<M-o>", desc = "Step out of the current function", category = "DAP" },
	{ key = "<M-r>", desc = "Toggle the DAP REPL", category = "DAP" },
	{ key = "<M-p>", desc = "Pause the active debug session", category = "DAP" },
	{ key = "<M-f>", desc = "Jump to the current DAP stack frame", category = "DAP" },
	{ key = "<M-g>", desc = "Select an active DAP session", category = "DAP" },
	{ key = "<M-w>", desc = "Add the expression under cursor as a watch", category = "DAP" },
	{ key = "<leader>gtt", desc = "Set tracepoint at word under cursor", category = "DAP" },
	{ key = "<leader>gtT", desc = "Set tracepoint at a prompted location", category = "DAP" },
	{ key = "<leader>gts", desc = "Start tracepoint collection", category = "DAP" },
	{ key = "<leader>gtv", desc = "Stop collection and show trace timeline", category = "DAP" },
	{ key = "<leader>gtc", desc = "Clear all tracepoints", category = "DAP" },
	{ key = "<leader>gti", desc = "Show tracepoint information in the REPL", category = "DAP" },
	{ key = "<leader>gv", desc = "Open the DAP variable and stack view", category = "DAP" },
	{ key = "<leader>gV", desc = "Close the DAP variable and stack view", category = "DAP" },
	{ key = "<leader>gs", desc = "Connect DAP to SIL flight software and simulator", category = "DAP" },
	{ key = "<leader>gc", desc = "Debug a C++ Bazel target", category = "DAP" },
	{ key = "<leader>gl", desc = "Relaunch the most recent DAP target", category = "DAP" },
	{ key = "<leader>gp", desc = "Debug a Python Bazel target", category = "DAP" },
	{ key = "<leader>gP", desc = "Debug a Python target from prompted input", category = "DAP" },
	{ key = "<leader>gr", desc = "Debug a Rust Bazel target", category = "DAP" },
	{ key = "<leader>gR", desc = "Debug a Rust target from prompted input", category = "DAP" },
	{ key = "<leader>dfc", desc = "Open Telescope DAP commands picker", category = "DAP" },
	{ key = "<leader>dfb", desc = "Open Telescope DAP breakpoints picker", category = "DAP" },
	{ key = "<leader>dfv", desc = "Open Telescope DAP variables picker", category = "DAP" },
	{ key = "<leader>dff", desc = "Open Telescope DAP stack-frames picker", category = "DAP" },

	-- ── Bazel ─────────────────────────────────────────────────────────────────
	{ key = "<leader>bb", desc = "Pick Bazel target then build it", category = "Bazel" },
	{ key = "<leader>bt", desc = "Pick Bazel target then run tests", category = "Bazel" },
	{ key = "<leader>br", desc = "Pick Bazel target then run it", category = "Bazel" },
	{ key = "<leader>bd", desc = "Pick Bazel target then debug it", category = "Bazel" },
	{ key = "<leader>ba", desc = "Toggle automatic Bazel rebuilds", category = "Bazel" },
	{ key = "<leader>bh", desc = "Show recently used Bazel targets", category = "Bazel" },
	{ key = "<leader>bc", desc = "Clear recently used Bazel targets", category = "Bazel" },

	-- ── Overseer (task runner) ─────────────────────────────────────────────────
	{ key = "<leader>o", desc = "Toggle Overseer task panel", category = "Tasks" },
	{ key = "<leader>or", desc = "Run an Overseer task", category = "Tasks" },

	-- ── Session (persistence) ─────────────────────────────────────────────────
	{ key = "<leader>Ss", desc = "Restore session for the current directory", category = "Sessions" },
	{ key = "<leader>Sl", desc = "Restore the most recently used session", category = "Sessions" },
	{ key = "<leader>Sd", desc = "Stop auto-saving session (for a clean exit)", category = "Sessions" },

	-- ── Sidekick / profiling ──────────────────────────────────────────────────
	{ key = "<leader>ll", desc = "Toggle the Sidekick AI CLI", category = "AI" },
	{ key = "<leader>ls", desc = "Select or attach a Sidekick AI CLI", category = "AI" },
	{ key = "<leader>lf", desc = "Focus the Sidekick AI CLI", category = "AI" },
	{ key = "<leader>lh", desc = "Hide the Sidekick AI CLI window", category = "AI" },
	{ key = "<leader>ld", desc = "Detach the Sidekick AI CLI session", category = "AI" },
	{ key = "<leader>lp", desc = "Choose a Sidekick context-aware prompt", category = "AI" },
	{ key = "<leader>lt", desc = "Send the current location to Sidekick", category = "AI" },
	{ key = "<leader>lF", desc = "Send the current file to Sidekick", category = "AI" },
	{ key = "<leader>lv", desc = "Send the visual selection to Sidekick", category = "AI" },
	{ key = "<leader>pp", desc = "Toggle the Snacks profiler", category = "Profiling" },
	{ key = "<leader>ph", desc = "Toggle Snacks profiler highlights", category = "Profiling" },
	{ key = "<leader>ps", desc = "Open the Snacks profiler scratch buffer", category = "Profiling" },

	-- ── Keybinding game ───────────────────────────────────────────────────────
	{ key = "<leader>G", desc = "Open the keybinding game category menu", category = "KeyGame" },
	{ key = "<leader>Ga", desc = "Start the keybinding game with all categories", category = "KeyGame" },

	-- ── Windows & splits ──────────────────────────────────────────────────────
	{ key = "<Esc>", desc = "Clear search highlighting; exit terminal mode", category = "Windows" },
	{ key = "<Esc><Esc>", desc = "Exit terminal mode (alternative)", category = "Windows" },
	{ key = "<C-h>", desc = "Move focus to left window", category = "Windows" },
	{ key = "<C-l>", desc = "Move focus to right window", category = "Windows" },
	{ key = "<C-j>", desc = "Move focus to lower window", category = "Windows" },
	{ key = "<C-k>", desc = "Move focus to upper window", category = "Windows" },
	{ key = "<leader>t", desc = "Open a new terminal buffer", category = "Windows" },

	-- ── Misc / editing ────────────────────────────────────────────────────────
	{ key = "<leader>u", desc = "Toggle undo tree panel", category = "Misc" },
	{ key = "<leader>v", desc = "Toggle Venn diagram drawing mode", category = "Misc" },
	{ key = "<leader>cn", desc = "Convert the number under cursor or selection", category = "Misc" },
	{ key = "<leader>x", desc = "Execute current line as Lua", category = "Misc" },
	{ key = "<leader><leader>x", desc = "Source / execute the current Lua file", category = "Misc" },
}

if vim.env.COMPILER_EXPLORER_URL then
	table.insert(mappings, {
		key = "<leader>ce",
		desc = "Compile the current buffer or selection in Compiler Explorer",
		category = "Compiler Explorer",
	})
end

return mappings
