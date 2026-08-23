local help = require("compiler_explorer_asm_help")

local intel = "        mov     rax, qword ptr [rbx]"
assert(help.token_at(intel, intel:find("qword", 1, true) - 1) == "qword")
assert(help.token_at(intel, intel:find("rax", 1, true) - 1) == "rax")
local x87 = "        fadd    st(0), st(3)"
assert(help.token_at(x87, x87:find("st(0)", 1, true) - 1) == "st(0)")
local ptx = "        mov.u32 %r12, %tid.x;"
assert(help.token_at(ptx, ptx:find("%r12", 1, true) - 1) == "%r12")

assert(help.mnemonic(intel) == "mov")
assert(help.mnemonic(".LBB0_2: lock add qword ptr [rax], 1") == "add")
assert(help.mnemonic("  401000: rep movsb") == "movsb")
assert(help.mnemonic("        b.eq    .Ldone") == "b.eq")
assert(help.mnemonic(".p2align 4") == nil)

local candidates = help._instruction_candidates("qword", "mov")
assert(vim.deep_equal(candidates, { "mov" }), vim.inspect(candidates))
candidates = help._instruction_candidates("movq", "movq")
assert(vim.deep_equal(candidates, { "movq", "mov" }), vim.inspect(candidates))
candidates = help._instruction_candidates(".Ldone", "b.eq")
assert(vim.deep_equal(candidates, { ".ldone", "b.eq", "b" }), vim.inspect(candidates))

local amd64_registers = {
	"rax",
	"eax",
	"ax",
	"al",
	"ah",
	"r15",
	"r15d",
	"r15w",
	"r15b",
	"r31",
	"r31d",
	"rip",
	"rflags",
	"cs",
	"fs",
	"xmm0",
	"ymm31",
	"zmm16",
	"k7",
	"mm7",
	"st(0)",
	"st(7)",
	"cr0",
	"cr8",
	"dr7",
	"bnd3",
	"tmm7",
	"mxcsr",
	"xcr0",
	"pkru",
	"gdtr",
	"idtr",
	"ldtr",
	"tr",
}
for _, register in ipairs(amd64_registers) do
	assert(help.register_info("amd64", register), "missing amd64 register " .. register)
end
for _, register in
	ipairs(
		vim.split(
			"rax eax ax al ah rbx ebx bx bl bh rcx ecx cx cl ch rdx edx dx dl dh rsi esi si sil rdi edi di dil rbp ebp bp bpl rsp esp sp spl",
			" ",
			{ plain = true }
		)
	)
do
	assert(help.register_info("amd64", register), "missing legacy GPR " .. register)
end
for number = 8, 31 do
	for _, suffix in ipairs({ "", "d", "w", "b" }) do
		local register = "r" .. number .. suffix
		assert(help.register_info("amd64", register), "missing extended GPR " .. register)
	end
end
for number = 0, 31 do
	for _, prefix in ipairs({ "xmm", "ymm", "zmm" }) do
		local register = prefix .. number
		assert(help.register_info("amd64", register), "missing vector register " .. register)
	end
end
for number = 0, 7 do
	for _, prefix in ipairs({ "k", "mm", "dr", "tmm" }) do
		local register = prefix .. number
		assert(help.register_info("amd64", register), "missing register " .. register)
	end
	assert(help.register_info("amd64", "st(" .. number .. ")"))
end
for number = 0, 15 do
	assert(help.register_info("amd64", "cr" .. number))
end
for number = 0, 3 do
	assert(help.register_info("amd64", "bnd" .. number))
end
assert(help.register_info("x86_64", "%rax"))
assert(not help.register_info("amd64", "qword"))
assert(help.register_info("amd64", "r16"))
assert(not help.register_info("amd64", "zmm32"))

for _, register in ipairs({
	"x0",
	"w30",
	"sp",
	"xzr",
	"v31.4s",
	"z31.d",
	"p15.b",
	"pn15.b",
	"ffr",
	"za",
	"za0.s",
	"tpidr_el0",
}) do
	assert(help.register_info("aarch64", register), "missing aarch64 register " .. register)
end
for _, register in ipairs({ "r0", "r15", "sp", "lr", "pc", "cpsr", "s31", "d31", "q15" }) do
	assert(help.register_info("arm32", register), "missing arm32 register " .. register)
end
for _, register in ipairs({ "x0", "x31", "zero", "ra", "a7", "s11", "t6", "f31", "fa7", "fs11", "ft11", "v31", "fcsr" }) do
	assert(help.register_info("riscv64", register), "missing riscv64 register " .. register)
end
for _, register in ipairs({ "r31", "f31", "v31", "vsr63", "cr7", "sr15", "acc7", "lr", "ctr", "xer" }) do
	assert(help.register_info("power", register), "missing power register " .. register)
end
for _, register in ipairs({ "r0", "r31", "x", "y", "z", "sp", "sreg", "pc" }) do
	assert(help.register_info("avr", register), "missing avr register " .. register)
end
for _, register in ipairs({ "%p0", "%r12", "%rd4", "%f2", "%fd7" }) do
	assert(help.register_info("ptx", register), "missing PTX register " .. register)
end
for _, register in ipairs({ "%tid.x", "%ctaid.y", "%laneid", "%clock64", "%lanemask_lt", "%envreg31" }) do
	assert(help.register_info("ptx", register), "missing PTX special register " .. register)
end
for _, register in ipairs({ "r255", "ur63", "p7", "up7", "rz", "pt", "sr_tid.x" }) do
	assert(help.register_info("sass", register), "missing SASS register " .. register)
end
for _, register in ipairs({ "a", "x", "y", "sp", "pc", "p" }) do
	assert(help.register_info("6502", register), "missing 6502 register " .. register)
end
for _, register in ipairs({ "a", "x", "y", "s", "pc", "p", "d", "dbr", "pbr", "e" }) do
	assert(help.register_info("65c816", register), "missing 65C816 register " .. register)
end
assert(help.register_info("llvm", "%result"))

local architecture, reason = help.infer_architecture({
	"/* Cortex-M7 reset stub */",
	"    .syntax unified",
	"    .thumb",
	"    ldr r0, =_stack_top",
})
assert(architecture == "arm32", architecture)
assert(reason == "a Cortex-M processor reference on line 1", reason)

architecture, reason = help.infer_architecture({ "    .intel_syntax noprefix", "    mov rax, rbx" })
assert(architecture == "amd64", architecture)
assert(reason:find("`.intel_syntax`", 1, true), reason)

architecture, reason = help.infer_architecture({ "    adrp x0, symbol", "    add x0, x0, :lo12:symbol" })
assert(architecture == "aarch64", architecture)
assert(reason == "AArch64 X-register operands on line 1", reason)

architecture, reason = help.infer_architecture({ '    .attribute arch, "rv64imac"' })
assert(architecture == "riscv64", architecture)
assert(reason:find("`rv64`", 1, true), reason)

local buffer = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_name(buffer, "compiler-explorer://test-1")
help.setup()
vim.api.nvim_set_option_value("filetype", "asm", { buf = buffer })
local mapping = vim.api.nvim_buf_call(buffer, function()
	return vim.fn.maparg("K", "n", false, true)
end)
assert(mapping.buffer == 1)
assert(mapping.desc == "Compiler Explorer: assembly instruction/register help")
assert(vim.api.nvim_buf_get_commands(buffer, {}).CEAssemblyHelp)

local ordinary_buffer = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_name(ordinary_buffer, "/tmp/ordinary.s")
vim.api.nvim_set_option_value("filetype", "asm", { buf = ordinary_buffer })
local ordinary_mapping = vim.api.nvim_buf_call(ordinary_buffer, function()
	return vim.fn.maparg("K", "n", false, true)
end)
assert(ordinary_mapping.buffer == 1)
assert(ordinary_mapping.desc == "Compiler Explorer: assembly instruction/register help")
local ordinary_commands = vim.api.nvim_buf_get_commands(ordinary_buffer, {})
assert(ordinary_commands.CEAssemblyHelp)
assert(ordinary_commands.CEAssemblyArchitecture)

local source_window = vim.api.nvim_get_current_win()
local preview_buffer, preview_window = help._open_preview({ "## Assembly help", "", "Test documentation." })
assert(vim.api.nvim_get_current_win() == source_window, "the first lookup should leave focus in the source")
assert(vim.api.nvim_win_is_valid(preview_window), "assembly help preview did not open")
local quit_mapping = vim.api.nvim_buf_call(preview_buffer, function()
	return vim.fn.maparg("q", "n", false, true)
end)
assert(quit_mapping.buffer == 1, "assembly help preview should provide a buffer-local q mapping")
local focused_buffer, focused_window = help._open_preview({ "ignored when focusing the existing preview" })
assert(focused_buffer == preview_buffer)
assert(focused_window == preview_window)
assert(vim.api.nvim_get_current_win() == preview_window, "the second lookup should focus the assembly help preview")
vim.api.nvim_set_current_win(source_window)
vim.api.nvim_win_close(preview_window, true)

vim.api.nvim_buf_set_lines(ordinary_buffer, 0, -1, false, { ".syntax unified", ".thumb", "ldr r0, =_stack_top" })
architecture, reason = help._resolve_architecture(ordinary_buffer)
assert(architecture == "arm32", architecture)
assert(reason == "the ARM/Thumb `.thumb` directive on line 2", reason)

local notices = {}
local original_notify = vim.notify
vim.notify = function(message)
	table.insert(notices, message)
end
help._notify_inferred_architecture(ordinary_buffer, architecture, reason)
vim.notify = original_notify
assert(
	notices[1]
		== "Compiler Explorer: inferred assembly architecture `arm32` because the buffer contains the ARM/Thumb `.thumb` directive on line 2",
	notices[1]
)
local test_url = vim.env.COMPILER_EXPLORER_TEST_URL
if test_url and test_url ~= "" then
	require("compiler-explorer").setup({ url = test_url })
	vim.api.nvim_set_current_buf(buffer)
	vim.api.nvim_buf_set_lines(buffer, 0, -1, false, { "        mov     rax, qword ptr [rbx]" })
	vim.b.arch = "amd64"
	vim.api.nvim_win_set_cursor(0, { 1, intel:find("qword", 1, true) - 1 })
	mapping.callback()

	local preview
	assert(
		vim.wait(10000, function()
			for _, window in ipairs(vim.api.nvim_list_wins()) do
				if vim.api.nvim_win_get_config(window).relative ~= "" then
					preview =
						table.concat(vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(window), 0, -1, false), "\n")
					return preview:find("MOV", 1, true) ~= nil
				end
			end
			return false
		end, 25),
		preview or "assembly help preview did not open"
	)
	assert(preview:find("Copies the second operand", 1, true), preview)

	for _, window in ipairs(vim.api.nvim_list_wins()) do
		if vim.api.nvim_win_get_config(window).relative ~= "" then
			vim.api.nvim_win_close(window, true)
		end
	end
	vim.api.nvim_set_current_buf(ordinary_buffer)
	vim.api.nvim_win_set_cursor(0, { 3, 0 })
	ordinary_mapping.callback()
	preview = nil
	assert(
		vim.wait(10000, function()
			for _, window in ipairs(vim.api.nvim_list_wins()) do
				if vim.api.nvim_win_get_config(window).relative ~= "" then
					preview =
						table.concat(vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(window), 0, -1, false), "\n")
					return preview:find("LDR", 1, true) ~= nil
				end
			end
			return false
		end, 25),
		preview or "ordinary ARM assembly help preview did not open"
	)
end

print("compiler_explorer_asm_help: ok")
