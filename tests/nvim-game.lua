local db = require("nvim_game.db")
local capture = require("nvim_game.input")
local game = require("nvim_game")

vim.g.mapleader = " "

local function feed_answer(key)
	for _, token in ipairs(capture.tokens(key)) do
		if token == "<leader>" then
			game.handle_key("<leader>")
		else
			game.handle_key(token)
		end
	end
end

local configured = 0
local documented_defaults = 0
local ctrl_s_categories = {}
for _, question in ipairs(db) do
	if question.key == "<C-s>" then
		ctrl_s_categories[question.category] = true
	end
	if question.category ~= "Neovim defaults" then
		configured = configured + 1
		if question.key == "[d" or question.key == "]d" then
			assert(question.explanation and question.help, "missing explanation for curated default: " .. question.key)
		end
	else
		documented_defaults = documented_defaults + 1
		assert(question.raw_desc and question.raw_desc ~= "", "missing runtime default source: " .. question.key)
		assert(question.explanation and question.explanation ~= "", "missing explanation for default: " .. question.key)
		assert(question.help and question.help ~= "", "missing help topic for default: " .. question.key)
		assert(not question.explanation_fallback, "default needs curated explanation: " .. question.key)
		assert(not question.desc:find("%-default"), "internal help tag leaked: " .. question.key)
		assert(not question.desc:match("^:"), "implementation command leaked: " .. question.key)
	end
	assert(capture.can_capture(question.key), "uncapturable key: " .. question.key)
end
assert(configured >= 152, "configured bindings unexpectedly disappeared")
assert(documented_defaults >= 59, "Neovim default catalog unexpectedly shrank")
assert(ctrl_s_categories.Navigation and ctrl_s_categories["Neovim defaults"], "mode-specific Ctrl-S lessons were collapsed")

assert(vim.deep_equal(capture.tokens("<leader>gD"), { "<leader>", "g", "D" }))
assert(vim.deep_equal(capture.tokens("<C-w><C-d>"), { "<C-w>", "<C-d>" }))
assert(capture.backspace("g<C-h>") == "g")
assert(capture.backspace("<leader>") == "")
assert(capture.is_prefix("<leader>g", "<leader>gd"))
assert(not capture.is_prefix("<leader>x", "<leader>gd"))
assert(not capture.can_capture("<D-x>"))

local capture_buf = vim.api.nvim_create_buf(false, true)
capture.setup(capture_buf, function() end)
vim.api.nvim_buf_call(capture_buf, function()
	assert(vim.fn.maparg("<M-Z>", "n", false, true).buffer == 1)
	assert(vim.fn.maparg("<C-w>", "n", false, true).buffer == 1)
end)
vim.api.nvim_buf_delete(capture_buf, { force = true })

-- The default explanation is visible before any answer is submitted.
game.start_category("Neovim defaults")
local default_game = game._state_for_test()
local question_text = table.concat(vim.api.nvim_buf_get_lines(default_game.buf, 0, -1, false), "\n")
assert(question_text:find("Why this key:", 1, true))
assert(question_text:find("Learn more: :help", 1, true))
game.handle_key("__quit__")
game.handle_key("__quit__")
assert(default_game.buf == nil)

-- A wrong answer stays in the existing game window. The displayed key must be
-- typed and submitted; no practice tab or temporary example buffer is opened.
game.start_category("KeyGame")
local state = game._state_for_test()
local first = vim.deepcopy(state.questions[state.q_idx])
local original_question_count = #state.questions
local original_tab_count = #vim.api.nvim_list_tabpages()
game.handle_key("__submit__")
assert(state.phase == "remediation")
assert(state.q_idx == 1)
assert(state.wrong == 1)
assert(#state.questions == original_question_count + 1)
assert(#vim.api.nvim_list_tabpages() == original_tab_count)
local correction_text = table.concat(vim.api.nvim_buf_get_lines(state.buf, 0, -1, false), "\n")
assert(correction_text:find("ENTER THE CORRECT KEY", 1, true))
assert(correction_text:find("Type the displayed key", 1, true))
assert(correction_text:find("Correct:     " .. first.key, 1, true))

game.handle_key("__submit__")
assert(state.phase == "remediation")
assert(state.remediation_error)
feed_answer(first.key)
game.handle_key("__submit__")
assert(state.phase == "feedback")
assert(state.q_idx == 2)
assert(state.corrected == 1)
assert(state.last_attempt.corrected)
game.handle_key("x")
assert(state.phase == "question")
game.handle_key("__quit__")
assert(state.phase == "feedback")
game.handle_key("__quit__")
assert(state.buf == nil)

print("nvim_game: ok")
