local db = require("nvim_game.db")
local capture = require("nvim_game.input")
local examples = require("nvim_game.examples")
local practice = require("nvim_game.practice")
local game = require("nvim_game")

vim.g.mapleader = " "

local function feed_mapping(key)
	local keys = key:gsub("<leader>", "<Space>")
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "x", false)
end

local missing = examples.coverage(db)
assert(#missing == 0, table.concat(missing, "\n"))

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
	local exercise = examples.resolve(question)
	assert(exercise.key == question.key)
	assert(exercise.description == question.desc)
	assert(exercise.explanation == question.explanation)
	assert(exercise.help == question.help)
	assert(#exercise.lines > 0, "empty example for " .. question.key)
	assert(exercise.cursor >= 1 and exercise.cursor <= #exercise.lines, "invalid cursor for " .. question.key)
	assert(capture.can_capture(question.key), "uncapturable key: " .. question.key)
	assert(exercise.action, "missing real-tab action for " .. question.key)
end
assert(configured >= 154, "configured bindings unexpectedly disappeared")
assert(documented_defaults >= 59, "Neovim default catalog unexpectedly shrank")
assert(ctrl_s_categories.Navigation and ctrl_s_categories["Neovim defaults"], "mode-specific Ctrl-S lessons were collapsed")

-- The conditional Compiler Explorer mapping must retain an exercise even when
-- the test environment does not enable that optional feature.
assert(examples.resolve({
	key = "K",
	desc = "Show assembly instruction/register documentation",
	category = "Compiler Explorer",
}).title == "Inspect generated assembly")

assert(vim.deep_equal(capture.tokens("<leader>gD"), { "<leader>", "g", "D" }))
assert(vim.deep_equal(capture.tokens("<C-w><C-d>"), { "<C-w>", "<C-d>" }))
assert(capture.backspace("g<C-h>") == "g")
assert(capture.backspace("<leader>") == "")
assert(capture.is_prefix("<leader>g", "<leader>gd"))
assert(not capture.is_prefix("<leader>x", "<leader>gd"))
assert(not capture.can_capture("<D-x>"))

local captured
local capture_buf = vim.api.nvim_create_buf(false, true)
capture.setup(capture_buf, function(action)
	captured = action
end)
vim.api.nvim_buf_call(capture_buf, function()
	assert(vim.fn.maparg("<M-Z>", "n", false, true).buffer == 1)
	assert(vim.fn.maparg("<C-w>", "n", false, true).buffer == 1)
end)
vim.api.nvim_buf_delete(capture_buf, { force = true })

-- The correction drill is an actual tabpage with ordinary source and info
-- buffers. Its expected key is a real buffer-local mapping, not manual token
-- comparison in a floating UI.
local direct_success = false
assert(practice.observe_ms == 3000)
practice.observe_ms = 500
practice.open({ key = "gd", desc = "Go to definition", category = "Code" }, {
	wrong_answer = "gr",
	on_success = function()
		direct_success = true
	end,
})
assert(practice.active())
local direct_drill = practice._state_for_test()
assert(vim.api.nvim_tabpage_is_valid(direct_drill.tab))
assert(vim.fn.maparg("gd", "n", false, true).buffer == 1)
assert(
	table.concat(vim.api.nvim_buf_get_lines(direct_drill.info_buf, 0, -1, false), "\n")
		:find("Goal: Go to definition", 1, true)
)
feed_mapping("gd")
assert(practice._state_for_test().completed)
assert(
	table.concat(vim.api.nvim_buf_get_lines(practice._state_for_test().info_buf, 0, -1, false), "\n")
		:find("Key executed in the correction tab", 1, true)
)
assert(
	vim.wait(1000, function()
		return direct_success
	end),
	"practice did not complete"
)
assert(not practice.active())

-- Runtime-discovered defaults must teach both the action and the convention
-- behind the spelling in the same real correction tab used during play.
local default_success = false
practice.open({
	key = "#",
	desc = "Search backward for the selected text",
	category = "Neovim defaults",
	explanation = "`*` and `#` are a directional pair.",
	help = "v_#",
}, {
	on_success = function()
		default_success = true
	end,
})
local default_drill = practice._state_for_test()
local default_info = table.concat(vim.api.nvim_buf_get_lines(default_drill.info_buf, 0, -1, false), "\n")
assert(default_info:find("Why this key: `*` and `#` are a directional pair.", 1, true))
assert(default_info:find("Learn more: :help v_#", 1, true))
feed_mapping("#")
assert(vim.wait(1000, function()
	return default_success
end), "documented default drill did not complete")
assert(not practice.active())

-- The same explanation is visible before an answer is submitted, so defaults
-- are understandable even when the player gets them right on the first try.
game.start_category("Neovim defaults")
local default_game = game._state_for_test()
local question_text = table.concat(vim.api.nvim_buf_get_lines(default_game.buf, 0, -1, false), "\n")
assert(question_text:find("Why this key:", 1, true))
assert(question_text:find("Learn more: :help", 1, true))
game.handle_key("__quit__")
game.handle_key("__quit__")
assert(default_game.buf == nil)

-- Full game transition: a wrong answer stays on the current question until
-- the example captures the shown binding, then the original is re-queued for
-- a later unaided recall attempt.
game.start_category("KeyGame")
local state = game._state_for_test()
local first = vim.deepcopy(state.questions[state.q_idx])
local original_question_count = #state.questions
game.handle_key("__submit__")
assert(state.phase == "remediation")
assert(state.q_idx == 1)
assert(state.wrong == 1)
assert(#state.questions == original_question_count + 1)
assert(practice.active())
feed_mapping(first.key)
assert(
	vim.wait(2000, function()
		return state.phase == "feedback"
	end),
	"game remediation did not finish"
)
assert(state.q_idx == 2)
assert(state.corrected == 1)
assert(state.last_attempt.corrected)
assert(not practice.active())
game.handle_key("x")
assert(state.phase == "question")
game.handle_key("__quit__")
assert(state.phase == "feedback")
game.handle_key("__quit__")
assert(state.buf == nil)
assert(not practice.active())
practice.observe_ms = 3000

print("nvim_game: ok")
