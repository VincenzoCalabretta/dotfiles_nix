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
		},
	},
}
