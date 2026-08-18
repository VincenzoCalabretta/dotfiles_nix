return {
	{
		"folke/sidekick.nvim",
		opts = {
			-- Keep Sidekick's CLI integration without automatic Next Edit Suggestions.
			nes = {
				enabled = false,
			},
		},
		keys = {
			{
				"<leader>aa",
				function()
					require("sidekick.cli").toggle()
				end,
				desc = "Sidekick: Toggle AI CLI",
			},
		},
	},
}
