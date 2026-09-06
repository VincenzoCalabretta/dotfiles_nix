-- Plain-language explanations for Neovim's runtime-discovered defaults.
--
-- Neovim exposes many defaults with internal help tags (for example,
-- `v_#-default`) or implementation names (such as `:cpfile`).  Those are
-- precise, but not teachable.  This catalog is the learning-facing layer:
-- `what` says what will happen and `why` explains the mnemonic, convention,
-- or historical notation behind the key sequence.

local M = {}

local function entry(what, why, help)
	return { what = what, why = why, help = help }
end

local catalog = {
	["#"] = entry(
		"Search backward for the selected text",
		"`*` and `#` are a directional pair: `*` searches forward and `#` searches backward. In Visual mode they reuse the current selection as the search text.",
		"v_#"
	),
	["*"] = entry(
		"Search forward for the selected text",
		"`*` and `#` are a directional pair: `*` searches forward and `#` searches backward. In Visual mode they reuse the current selection as the search text.",
		"v_star"
	),
	["&"] = entry(
		"Repeat the last substitution, keeping its flags",
		"`&` is the traditional shorthand for repeating `:substitute`; the character also has a long history in substitution syntax as the matched text. Neovim maps it to `:&&`, the form that preserves the previous flags.",
		"&"
	),
	["<C-u>"] = entry(
		"Delete everything entered before the cursor on this line",
		"This comes from the Unix terminal line-editing convention: Ctrl-U is the line-kill command. It is historical rather than an English initial, and Neovim starts a fresh undo block before deleting.",
		"i_CTRL-U"
	),
	["<C-w>"] = entry(
		"Delete the word before the cursor",
		"This is another Unix terminal editing convention: Ctrl-W erases the previous word. The `W` is best remembered as “word”, although the binding predates modern GUI text editing.",
		"i_CTRL-W"
	),
	["<C-s>"] = entry(
		"Show language-server signature help while inserting or selecting text",
		"This is Neovim's Insert/Select-mode LSP binding; `S` stands for signature. It deliberately remains mode-specific, so a command-line Ctrl-S mapping can coexist without replacing it.",
		"i_CTRL-S"
	),
	["<Tab>"] = entry(
		"Jump to the next active built-in snippet placeholder, or insert a Tab",
		"Tab conventionally moves forward through fields. Neovim keeps its normal Tab behavior when no snippet is active, so ordinary indentation and completion workflows still work.",
		"vim.snippet"
	),
	["<S-Tab>"] = entry(
		"Jump to the previous active built-in snippet placeholder, or insert Shift-Tab",
		"Shift reverses Tab's usual forward direction, so this is the backwards partner of Tab while stepping through snippet placeholders.",
		"vim.snippet"
	),
	["<C-w>d"] = entry(
		"Show diagnostics under the cursor in a floating window",
		"Ctrl-W is Neovim's window-command prefix; `d` stands for diagnostic. The Ctrl-D spelling is kept as a convenient synonym for terminals and muscle memory.",
		"CTRL-W_d"
	),
	["<C-w><C-d>"] = entry(
		"Show diagnostics under the cursor in a floating window",
		"This is a synonym for Ctrl-W then `d`. Ctrl-W is Neovim's window-command prefix and `d` stands for diagnostic; the doubled-control version follows the common Ctrl-W command style.",
		"CTRL-W_d"
	),
	["@"] = entry(
		"Run a chosen macro register once for every selected line",
		"`@` is Vim's normal “execute register” command. In linewise Visual mode Neovim extends it to apply that same macro to every selected line.",
		"v_@"
	),
	["Q"] = entry(
		"Repeat the last recorded macro for every selected line",
		"Lowercase `q` records a macro and `@` executes one; uppercase `Q` is the compact repeat-last variant. In linewise Visual mode it repeats that macro for each selected line.",
		"v_Q"
	),
	["Y"] = entry(
		"Yank from the cursor to the end of the line",
		"`y` means yank. Neovim maps uppercase `Y` to `y$` so it mirrors the handy line-ending forms `D` and `C`, instead of requiring a motion after `y`.",
		"Y"
	),
	["gO"] = entry(
		"List document symbols from the language server",
		"`g` is Vim's extended-command prefix and uppercase `O` evokes an outline. The result is the language server's table of contents for the current file.",
		"vim.lsp.buf.document_symbol()"
	),
	["gc"] = entry(
		"Toggle comments for the current selection or a following motion",
		"`g` is the extended operator namespace and `c` means comment. In Normal mode it starts a comment operator, in Visual mode it acts on the selection, and in operator-pending mode it provides a comment text object.",
		"gc"
	),
	["gcc"] = entry(
		"Toggle the comment on the current line",
		"This is the linewise form of `gc`: the second `c` follows Vim's doubled-key convention for “the current line”, like `dd` and `yy`.",
		"gcc"
	),
	["gra"] = entry(
		"Show available language-server code actions",
		"`gr` is Neovim's global LSP prefix and the suffix `a` means action. The family keeps language-server operations together without claiming common one-letter commands.",
		"gra"
	),
	["gri"] = entry(
		"Go to a language-server implementation",
		"`gr` is Neovim's global LSP prefix and `i` means implementation. The suffixes in this family are semantic initials.",
		"gri"
	),
	["grn"] = entry(
		"Rename the symbol under the cursor through the language server",
		"`gr` is Neovim's global LSP prefix and `n` stands for name, so this is the rename member of the family.",
		"grn"
	),
	["grr"] = entry(
		"List language-server references to the symbol under the cursor",
		"`gr` is Neovim's global LSP prefix and the final `r` means references. The doubled `r` is prefix plus mnemonic, not an accidental repeat.",
		"grr"
	),
	["grt"] = entry(
		"Go to the language-server type definition",
		"`gr` is Neovim's global LSP prefix and `t` means type. It is the type-definition member of the same mnemonic family.",
		"grt"
	),
	["grx"] = entry(
		"Run the language-server CodeLens at the cursor",
		"`gr` is Neovim's global LSP prefix. `x` is the execute-style suffix here: a CodeLens is an actionable annotation rather than a place to jump to.",
		"grx"
	),
	["gx"] = entry(
		"Open the file path, URL, or selected URI with the system handler",
		"`g` is Vim's extended-command prefix; `x` is the long-standing external/open-style suffix. It hands the target to your file manager, browser, or other system opener.",
		"gx"
	),
	["an"] = entry(
		"Select the parent syntax node around the cursor",
		"This follows Vim text-object grammar: `a` means around/outer and `n` means node. It grows the structural selection to the parent, using Tree-sitter or an LSP selection range.",
		"an"
	),
	["in"] = entry(
		"Select the child syntax node inside the current selection",
		"This follows Vim text-object grammar: `i` means inner and `n` means node. It shrinks a structural selection to a child, using Tree-sitter or an LSP selection range.",
		"in"
	),
}

local directions = {
	["["] = { word = "previous", edge = "first" },
	["]"] = { word = "next", edge = "last" },
}

local function directional(what, why, help)
	for bracket, direction in pairs(directions) do
		catalog[bracket .. what.suffix] =
			entry(what[direction.word], direction.word == "previous" and why.previous or why.next, help[direction.word])
	end
end

-- Neovim adopts the familiar vim-unimpaired convention: [ means previous or
-- above and ] means next or below. The suffix names the list being traversed.
for suffix, spec in pairs({
	a = {
		name = "argument list",
		previous = "Go to the previous file in the argument list",
		next = "Go to the next file in the argument list",
		help = { previous = ":previous", next = ":next" },
	},
	b = {
		name = "buffer list",
		previous = "Go to the previous buffer",
		next = "Go to the next buffer",
		help = { previous = ":bprevious", next = ":bnext" },
	},
	q = {
		name = "quickfix list",
		previous = "Go to the previous quickfix entry",
		next = "Go to the next quickfix entry",
		help = { previous = ":cprevious", next = ":cnext" },
	},
	l = {
		name = "location list",
		previous = "Go to the previous location-list entry",
		next = "Go to the next location-list entry",
		help = { previous = ":lprevious", next = ":lnext" },
	},
	t = {
		name = "tag stack",
		previous = "Go to the previous matching tag",
		next = "Go to the next matching tag",
		help = { previous = ":tprevious", next = ":tnext" },
	},
}) do
	directional({
		suffix = suffix,
		previous = spec.previous,
		next = spec.next,
	}, {
		previous = "`[` means previous and `]` means next in Neovim's vim-unimpaired-style navigation family. `"
			.. suffix
			.. "` names the "
			.. spec.name
			.. ".",
		next = "`[` means previous and `]` means next in Neovim's vim-unimpaired-style navigation family. `"
			.. suffix
			.. "` names the "
			.. spec.name
			.. ".",
	}, spec.help)
end

for suffix, spec in pairs({
	A = {
		name = "argument list",
		first = "Go to the first file in the argument list",
		last = "Go to the last file in the argument list",
		help = { previous = ":rewind", next = ":last" },
	},
	B = {
		name = "buffer list",
		first = "Go to the first buffer",
		last = "Go to the last buffer",
		help = { previous = ":brewind", next = ":blast" },
	},
	Q = {
		name = "quickfix list",
		first = "Go to the first quickfix entry",
		last = "Go to the last quickfix entry",
		help = { previous = ":crewind", next = ":clast" },
	},
	L = {
		name = "location list",
		first = "Go to the first location-list entry",
		last = "Go to the last location-list entry",
		help = { previous = ":lrewind", next = ":llast" },
	},
	T = {
		name = "tag stack",
		first = "Go to the first matching tag",
		last = "Go to the last matching tag",
		help = { previous = ":trewind", next = ":tlast" },
	},
}) do
	directional({
		suffix = suffix,
		previous = spec.first,
		next = spec.last,
	}, {
		previous = "Uppercase `"
			.. suffix
			.. "` is the endpoint variant for the "
			.. spec.name
			.. ": `[` goes to its first item and `]` goes to its last item.",
		next = "Uppercase `"
			.. suffix
			.. "` is the endpoint variant for the "
			.. spec.name
			.. ": `[` goes to its first item and `]` goes to its last item.",
	}, spec.help)
end

directional({
	suffix = "<C-q>",
	previous = "Go to the last quickfix entry in the previous file",
	next = "Go to the first quickfix entry in the next file",
}, {
	previous = "`[` and `]` still mean previous and next. Ctrl-Q identifies the quickfix list, while the control modifier distinguishes moving by file from `[q` and `]q`, which move by individual entry.",
	next = "`[` and `]` still mean previous and next. Ctrl-Q identifies the quickfix list, while the control modifier distinguishes moving by file from `[q` and `]q`, which move by individual entry.",
}, { previous = ":cpfile", next = ":cnfile" })

directional({
	suffix = "<C-l>",
	previous = "Go to the last location-list entry in the previous file",
	next = "Go to the first location-list entry in the next file",
}, {
	previous = "`[` and `]` still mean previous and next. Ctrl-L identifies the local location list, while the control modifier distinguishes moving by file from `[l` and `]l`, which move by individual entry.",
	next = "`[` and `]` still mean previous and next. Ctrl-L identifies the local location list, while the control modifier distinguishes moving by file from `[l` and `]l`, which move by individual entry.",
}, { previous = ":lpfile", next = ":lnfile" })

directional({
	suffix = "<C-t>",
	previous = "Show the previous matching tag in the preview window",
	next = "Show the next matching tag in the preview window",
}, {
	previous = "`[` and `]` provide the previous/next direction, while Ctrl-T names the tag command's preview-window variant. It is the preview counterpart to `[t` and `]t`.",
	next = "`[` and `]` provide the previous/next direction, while Ctrl-T names the tag command's preview-window variant. It is the preview counterpart to `[t` and `]t`.",
}, { previous = ":ptprevious", next = ":ptnext" })

catalog["[<leader>"] = entry(
	"Add an empty line above the cursor",
	"`[` is the above/previous side of the bracket family, and the trailing Space literally evokes the blank line it creates. The game displays that Space as `<leader>` because this setup uses Space as leader.",
	"[<Space>"
)
catalog["]<leader>"] = entry(
	"Add an empty line below the cursor",
	"`]` is the below/next side of the bracket family, and the trailing Space literally evokes the blank line it creates. The game displays that Space as `<leader>` because this setup uses Space as leader.",
	"]<Space>"
)

catalog["[D"] = entry(
	"Jump to the first diagnostic in the current buffer",
	"The bracket family supplies direction: `[` means backward/first and `]` means forward/last. Uppercase `D` is the endpoint form for diagnostics, while lowercase `[d` and `]d` move one diagnostic at a time.",
	"[D-default"
)
catalog["]D"] = entry(
	"Jump to the last diagnostic in the current buffer",
	"The bracket family supplies direction: `[` means backward/first and `]` means forward/last. Uppercase `D` is the endpoint form for diagnostics, while lowercase `[d` and `]d` move one diagnostic at a time.",
	"]D-default"
)
catalog["[d"] = entry(
	"Jump to the previous diagnostic in the current buffer",
	"The bracket family supplies direction: `[` means previous and `]` means next, while `d` means diagnostic. Uppercase `[D` and `]D` are the first/last endpoint forms.",
	"[d-default"
)
catalog["]d"] = entry(
	"Jump to the next diagnostic in the current buffer",
	"The bracket family supplies direction: `[` means previous and `]` means next, while `d` means diagnostic. Uppercase `[D` and `]D` are the first/last endpoint forms.",
	"]d-default"
)

for bracket, direction in pairs(directions) do
	catalog[bracket .. "n"] = entry(
		direction.word == "previous" and "Select the previous syntax node" or "Select the next syntax node",
		"`[` and `]` give the previous/next direction and `n` means syntax node. This changes a Visual selection structurally using Tree-sitter.",
		direction.word == "previous" and "[n" or "]n"
	)
	catalog[bracket .. "N"] = entry(
		direction.word == "previous" and "Select the previous sibling syntax node"
			or "Select the next sibling syntax node",
		"`[` and `]` give the previous/next direction and `n` means syntax node. Uppercase `N` selects the sibling-node variant, rather than the adjacent structural node.",
		direction.word == "previous" and "[N" or "]N"
	)
end

function M.for_mapping(key, raw_desc)
	local documented = catalog[key]
	if documented then
		return vim.deepcopy(documented)
	end

	-- New Neovim releases can add defaults. Keep them usable immediately, but
	-- make the missing catalog entry visible to tests and maintainers.
	return {
		what = raw_desc,
		why = "This Neovim default is new to the game catalog. Its runtime description is shown until a plain-language explanation is added.",
		help = nil,
		fallback = true,
	}
end

function M.documented(key)
	return catalog[key] ~= nil
end

return M
