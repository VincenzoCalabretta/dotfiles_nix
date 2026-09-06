-- Contextual, side-effect-free examples for nvim_game correction drills.
--
-- db.lua is intentionally allowed to discover Neovim defaults at runtime, so
-- this module resolves an exercise for every question rather than maintaining
-- a fragile second copy of the keybinding list.  Each configured category has
-- a deliberately chosen fixture; core defaults get a fixture appropriate to
-- their reported mode, with action-specific variants for common families.

local M = {}

local category_cases = {
	Code = {
		title = "Source navigation and code actions",
		mode = "normal",
		prompt = "The cursor is on a symbol in a small Lua module.",
		cursor = 5,
		lines = {
			"local M = {}",
			"",
			"local function calculate_total(items)",
			"  return vim.iter(items):sum()",
			"end",
			"",
			"local total = calculate_total(cart)",
			"print(total)",
		},
	},
	Diagnostics = {
		title = "Inspect a diagnostic",
		mode = "normal",
		prompt = "The highlighted call has an error diagnostic.",
		cursor = 4,
		lines = {
			"local function render(user)",
			"  return user.name:upper()",
			"end",
			"print(render(nil))  -- error: user may be nil",
			"",
			"  1 error, 0 warnings",
		},
	},
	Git = {
		title = "Review a changed Git hunk",
		mode = "normal",
		prompt = "The cursor is inside the modified hunk.",
		cursor = 4,
		lines = {
			"@@ -12,5 +12,5 @@ function build()",
			" local target = select_target()",
			"-return run(target)",
			"+return run(target, { verbose = true })",
			" end",
			"",
			"  1 changed hunk",
		},
	},
	Search = {
		title = "Find project information",
		mode = "normal",
		prompt = "You are working in the project root.",
		cursor = 4,
		lines = {
			"project/",
			"├── src/main.lua",
			"├── src/worker.lua",
			"├── tests/main_spec.lua",
			"└── README.md",
			"",
			"Search the project, current buffer, or editor metadata.",
		},
	},
	Harpoon = {
		title = "Navigate pinned files",
		mode = "normal",
		prompt = "This project has a short list of pinned working files.",
		cursor = 3,
		lines = {
			"Harpoon list",
			"1  src/main.lua",
			"2  src/parser.lua",
			"3  tests/parser_spec.lua",
			"4  README.md",
		},
	},
	Outline = {
		title = "Navigate the code outline",
		mode = "normal",
		prompt = "The current file exposes a nested symbol outline.",
		cursor = 5,
		lines = {
			"▾ module nvim_game",
			"  ▾ function start",
			"      local state = reset_state()",
			"      open_window(state)",
			"  ▸ function finish",
			"  ▸ function render",
		},
	},
	Navigation = {
		title = "Move through structured source",
		mode = "normal",
		prompt = "The cursor is in a function within nested code.",
		cursor = 5,
		lines = {
			"local function outer(config)",
			"  local function render(item)",
			"    return format(item)",
			"  end",
			"  return vim.tbl_map(render, config.items)",
			"end",
		},
	},
	Textobjects = {
		title = "Operate on a textobject",
		mode = "operator-pending / visual",
		prompt = "The cursor is inside the function call argument list.",
		cursor = 4,
		lines = {
			"local result = transform(",
			"  source_items,",
			"  { trim = true, sort = true },",
			"  callback",
			")",
		},
	},
	Targets = {
		title = "Choose a Bazel target action",
		mode = "normal",
		prompt = "The current project exposes these Bazel targets.",
		cursor = 4,
		lines = {
			"cc_library(",
			'    name = "parser",',
			'    srcs = ["parser.cc"],',
			")",
			"",
			"//src:parser        cc_library",
			"//tests:parser_test cc_test",
		},
	},
	Debugger = {
		title = "Control an active debug session",
		mode = "normal",
		prompt = "Execution is paused at the highlighted line.",
		cursor = 4,
		lines = {
			"Thread 1  paused at src/main.cc:42",
			"  40  auto result = parse(input);",
			"  41  validate(result);",
			"▶ 42  write_result(result);",
			"  43  return 0;",
			"",
			"Breakpoints: 1    Watches: 0",
		},
	},
	Sessions = {
		title = "Restore or manage a session",
		mode = "normal",
		prompt = "A session was saved for this project directory.",
		cursor = 3,
		lines = {
			"Session: ~/projects/example",
			"  buffers: 6",
			"  last saved: today, 14:32",
			"  auto-save: enabled",
		},
	},
	AI = {
		title = "Work with the AI CLI",
		mode = "normal",
		prompt = "An AI CLI session is attached to the current project.",
		cursor = 3,
		lines = {
			"Sidekick AI CLI",
			"  session: refactor-parser",
			"▶ context: src/parser.lua:42",
			"  state: attached",
		},
	},
	Profiling = {
		title = "Inspect profiler data",
		mode = "normal",
		prompt = "The profiler has captured the latest render work.",
		cursor = 3,
		lines = {
			"Profiler",
			"  render_question      3.2 ms",
			"▶ vim.lsp.buf.format   1.7 ms",
			"  telescope.find_files 0.8 ms",
		},
	},
	KeyGame = {
		title = "Navigate the keybinding game",
		mode = "normal",
		prompt = "The keybinding game menu is open.",
		cursor = 3,
		lines = {
			"NEOVIM KEY MASTER",
			"",
			"▶ ALL CATEGORIES",
			"  Code",
			"  Git",
		},
	},
	Windows = {
		title = "Manage editor windows",
		mode = "normal / terminal",
		prompt = "The editor has source, test, and terminal windows open.",
		cursor = 3,
		lines = {
			"┌ src/main.lua ───────┬ tests/main_spec.lua ┐",
			"│                     │                     │",
			"│  current cursor     │  test output        │",
			"├─────────────────────┴─────────────────────┤",
			"│ terminal: npm test                        │",
			"└───────────────────────────────────────────┘",
		},
	},
	Misc = {
		title = "Edit the current scratch buffer",
		mode = "normal / visual",
		prompt = "The cursor is on a value in a Lua scratch buffer.",
		cursor = 3,
		lines = {
			"local retries = 41",
			"local enabled = true",
			"print(retries)",
			"",
			"-- experiment safely before applying the change",
		},
	},
	["Compiler Explorer"] = {
		title = "Inspect generated assembly",
		mode = "normal",
		prompt = "The cursor is on an assembly instruction.",
		cursor = 3,
		lines = {
			"calculate_total:",
			"  add rax, rbx",
			"  mov rcx, rax",
			"  ret",
		},
	},
}

local core_cases = {
	insert = {
		title = "Use an insert-mode default",
		mode = "insert",
		prompt = "The cursor is editing a line of text.",
		cursor = 2,
		lines = { 'local title = "Key Master"', 'local message = "type here"', "" },
	},
	visual = {
		title = "Use a visual-mode default",
		mode = "visual",
		prompt = "The marked text is the active visual selection.",
		cursor = 2,
		lines = { 'local greeting = "hello world"', "      └── selected text ──┘", "" },
	},
	operator = {
		title = "Use an operator-pending textobject",
		mode = "operator-pending / visual",
		prompt = "An operator is waiting for a structural textobject.",
		cursor = 2,
		lines = { 'local result = render({ title = "hello" })', "                        ^ cursor", "" },
	},
	normal = {
		title = "Use a Neovim default mapping",
		mode = "normal",
		prompt = "The cursor is in a small, safe example buffer.",
		cursor = 2,
		lines = { "local current_item = items[index]", "      ^ cursor", "" },
	},
}

local category_actions = {
	Code = "definition",
	Diagnostics = "diagnostic",
	Git = "diff",
	Search = "search",
	Harpoon = "file",
	Outline = "outline",
	Navigation = "move",
	Textobjects = "select",
	Targets = "target",
	Debugger = "debug",
	Sessions = "session",
	AI = "panel",
	Profiling = "profile",
	KeyGame = "menu",
	Windows = "window",
	Misc = "edit",
	["Compiler Explorer"] = "assembly",
}

local function core_case(question)
	local hint = question.hint or ""
	local template
	if hint:find("insert", 1, true) or hint:find("select", 1, true) then
		template = core_cases.insert
	elseif hint:find("operator%-pending") then
		template = core_cases.operator
	elseif hint:find("visual", 1, true) then
		template = core_cases.visual
	else
		template = core_cases.normal
	end

	local result = vim.deepcopy(template)
	if question.key == "gc" or question.key == "gcc" then
		result.title = "Comment source code"
		result.prompt = "The cursor is on a line that should be commented or uncommented."
		result.lines = { "local debug = true", "print(debug)", "" }
		result.cursor = 2
	elseif question.key:match("^[%[%]]") then
		result.title = "Navigate a list, diagnostic, or structural item"
		result.prompt = "A previous/next action is available from this cursor position."
	elseif question.key:match("^gr") or question.key == "gO" then
		result.title = "Use a built-in LSP action"
		result.prompt = "The cursor is on a symbol with language-server information."
	end
	return result
end

function M.resolve(question)
	assert(type(question) == "table", "question must be a table")
	assert(type(question.key) == "string" and question.key ~= "", "question key is required")
	assert(type(question.desc) == "string" and question.desc ~= "", "question description is required")

	local template = question.category == "Neovim defaults" and core_case(question) or category_cases[question.category]
	assert(template, "no correction exercise for category: " .. tostring(question.category))

	local result = vim.deepcopy(template)
	result.key = question.key
	result.description = question.desc
	result.explanation = question.explanation
	result.help = question.help
	result.category = question.category
	result.action = question.category == "Neovim defaults" and "default" or category_actions[question.category]
	result.exercise_id = question.category == "Neovim defaults" and ("core:" .. question.key)
		or (question.category .. ":" .. question.key)
	return result
end

function M.coverage(entries)
	local missing = {}
	for _, question in ipairs(entries) do
		local ok, err = pcall(M.resolve, question)
		if not ok then
			missing[#missing + 1] = string.format("%s (%s): %s", question.key, question.category, err)
		end
	end
	return missing
end

return M
