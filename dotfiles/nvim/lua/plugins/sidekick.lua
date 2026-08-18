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
					vim.notify(
						[[Sidekick prompt context:
  {file} — current file
  {position} / {line} — cursor location/current line
  {selection} — visual selection
  {diagnostics} — current-buffer diagnostics
  {diagnostics_all} — workspace diagnostics
  {quickfix} — quickfix list
  {function} / {class} — symbol under the cursor (Tree-sitter)
  {this} — cursor position in a file; otherwise the visual selection]],
						vim.log.levels.INFO,
						{ title = "Sidekick" }
					)
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
