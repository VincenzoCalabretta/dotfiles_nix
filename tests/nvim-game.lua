local db = require("nvim_game.db")
local capture = require("nvim_game.input")
local examples = require("nvim_game.examples")
local practice = require("nvim_game.practice")
local game = require("nvim_game")

local missing = examples.coverage(db)
assert(#missing == 0, table.concat(missing, "\n"))

local configured = 0
for _, question in ipairs(db) do
	if question.category ~= "Neovim defaults" then
		configured = configured + 1
	end
	local exercise = examples.resolve(question)
	assert(exercise.key == question.key)
	assert(exercise.description == question.desc)
	assert(#exercise.lines > 0, "empty example for " .. question.key)
	assert(exercise.cursor >= 1 and exercise.cursor <= #exercise.lines, "invalid cursor for " .. question.key)
	assert(capture.can_capture(question.key), "uncapturable key: " .. question.key)
end
assert(configured >= 154, "configured bindings unexpectedly disappeared")

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

-- A correction attempt only completes after the exact sequence.  The bad
-- token is intentionally not forwarded to a real mapping.
local direct_success = false
practice.open({ key = "gd", desc = "Go to definition", category = "Code" }, {
	wrong_answer = "gr",
	on_success = function()
		direct_success = true
	end,
})
assert(practice.active())
assert(
	table.concat(vim.api.nvim_buf_get_lines(practice._state_for_test().buf, 0, -1, false), "\n")
		:find("Goal: Go to definition", 1, true)
)
practice.handle_key("g")
assert(practice._state_for_test().input == "g")
practice.handle_key("x")
assert(practice._state_for_test().input == "")
practice.handle_key("g")
practice.handle_key("d")
assert(
	vim.wait(1000, function()
		return direct_success
	end),
	"practice did not complete"
)
assert(not practice.active())

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
for _, token in ipairs(capture.tokens(first.key)) do
	practice.handle_key(token)
end
assert(
	vim.wait(1000, function()
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

print("nvim_game: ok")
