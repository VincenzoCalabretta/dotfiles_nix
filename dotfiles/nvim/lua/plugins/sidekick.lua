local function show_help()
	local lines = {
		"Sidekick — AI CLI shortcuts (closes automatically)",
		"",
		"<leader>ll  Toggle the active AI CLI",
		"<leader>ls  Select or attach an AI CLI",
		"<leader>lf  Focus the AI CLI",
		"<leader>lh  Hide the AI CLI window",
		"<leader>ld  Detach the current AI CLI session",
		"<leader>lp  Choose and send a context-aware prompt",
		"<leader>lt  Send the current cursor location",
		"<leader>lF  Send the current file",
		"<leader>lv  Send the visual selection",
		"",
		"Prompt context:",
		"{file} — current file",
		"{position} / {line} — cursor location/current line",
		"{selection} — visual selection (actual code)",
		"{diagnostics} / {diagnostics_all} — buffer/workspace diagnostics",
		"{quickfix} — quickfix list",
		"{function} / {class} — symbol under the cursor (Tree-sitter)",
		"{this} — cursor location in a file; otherwise visual selection",
		"",
		"In the AI terminal: <C-z> returns to code; q hides the window.",
	}
	local width = math.min(86, vim.o.columns - 4)
	local height = math.min(#lines, vim.o.lines - 4)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false

	local win = vim.api.nvim_open_win(buf, false, {
		border = "rounded",
		col = math.max(0, math.floor((vim.o.columns - width) / 2)),
		focusable = false,
		height = height,
		noautocmd = true,
		relative = "editor",
		row = math.max(0, math.floor((vim.o.lines - height) / 2)),
		style = "minimal",
		title = " Sidekick ",
		title_pos = "center",
		width = width,
		zindex = 50,
	})
	vim.wo[win].winblend = 10
	vim.defer_fn(function()
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end, 8000)
end

return {
	{
		"folke/sidekick.nvim",
		opts = {
			-- Keep Sidekick's CLI integration without automatic Next Edit Suggestions.
			nes = {
				enabled = false,
			},
			-- Keep AI CLI processes alive outside Neovim and reattach through tmux.
			cli = {
				mux = {
					enabled = true,
					backend = "tmux",
				},
			},
		},
		keys = {
			{
				"<leader>ll",
				function()
					show_help()
					require("sidekick.cli").toggle()
				end,
				desc = "Sidekick: Toggle AI CLI",
			},
			{
				"<leader>ls",
				function()
					require("sidekick.cli").select()
				end,
				desc = "Sidekick: Select AI CLI",
			},
			{
				"<leader>lf",
				function()
					require("sidekick.cli").focus()
				end,
				desc = "Sidekick: Focus AI CLI",
			},
			{
				"<leader>lh",
				function()
					require("sidekick.cli").hide()
				end,
				desc = "Sidekick: Hide AI CLI",
			},
			{
				"<leader>ld",
				function()
					require("sidekick.cli").close()
				end,
				desc = "Sidekick: Detach AI CLI session",
			},
			{
				"<leader>lp",
				function()
					require("sidekick.cli").prompt()
				end,
				desc = "Sidekick: Choose context-aware prompt",
			},
			{
				"<leader>lt",
				function()
					require("sidekick.cli").send({ msg = "{this}" })
				end,
				desc = "Sidekick: Send current location",
			},
			{
				"<leader>lF",
				function()
					require("sidekick.cli").send({ msg = "{file}" })
				end,
				desc = "Sidekick: Send current file",
			},
			{
				"<leader>lv",
				function()
					require("sidekick.cli").send({ msg = "{selection}" })
				end,
				mode = "x",
				desc = "Sidekick: Send visual selection",
			},
		},
	},
}
