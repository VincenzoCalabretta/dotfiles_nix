local M = {}

local api = vim.api
local tick = string.char(96)

local architecture_aliases = {
	x86 = "amd64",
	x86_64 = "amd64",
	arm = "arm32",
	riscv = "riscv64",
}

local references = {
	amd64 = "https://www.intel.com/content/www/us/en/developer/articles/technical/intel-sdm.html",
	aarch64 = "https://developer.arm.com/documentation/ddi0602/latest/",
	arm32 = "https://developer.arm.com/Architectures/A-Profile%20Architecture",
	riscv64 = "https://riscv.org/technical/specifications/",
	power = "https://openpowerfoundation.org/specifications/isa/",
	ptx = "https://docs.nvidia.com/cuda/parallel-thread-execution/",
	sass = "https://docs.nvidia.com/cuda/cuda-binary-utilities/",
	avr = "https://www.microchip.com/en-us/products/microcontrollers-and-microprocessors/8-bit-mcus/avr-mcus",
}

local function code(value)
	return tick .. value .. tick
end

local function markdown(title, body, reference)
	local lines = { "## " .. title, "", body }
	if reference then
		vim.list_extend(lines, { "", "[Architecture reference](" .. reference .. ")" })
	end
	return lines
end

local function numbered(token, pattern, first, last)
	local number = tonumber(token:match(pattern))
	if number and number >= first and number <= last then
		return number
	end
end

local x86_gprs = {
	{ names = { "rax", "eax", "ax", "al", "ah" }, role = "accumulator and function return value" },
	{ names = { "rbx", "ebx", "bx", "bl", "bh" }, role = "general-purpose, conventionally callee-saved" },
	{ names = { "rcx", "ecx", "cx", "cl", "ch" }, role = "counter, shift count, and fourth integer argument" },
	{ names = { "rdx", "edx", "dx", "dl", "dh" }, role = "data register and third integer argument" },
	{ names = { "rsi", "esi", "si", "sil" }, role = "source index and second integer argument" },
	{ names = { "rdi", "edi", "di", "dil" }, role = "destination index and first integer argument" },
	{ names = { "rbp", "ebp", "bp", "bpl" }, role = "frame pointer or general-purpose register" },
	{ names = { "rsp", "esp", "sp", "spl" }, role = "stack pointer" },
}

local function x86_gpr(token)
	for _, group in ipairs(x86_gprs) do
		for index, name in ipairs(group.names) do
			if token == name then
				local width = ({ 64, 32, 16, 8, 8 })[index]
				local detail = string.format(
					"A **%d-bit** view of %s, used as the %s. Writing a 32-bit view zero-extends into the full 64-bit register; 8- and 16-bit writes preserve the other bits.",
					width,
					code(group.names[1]),
					group.role
				)
				if index == 5 then
					detail = detail
						.. " This legacy high-byte register names bits 15:8 and cannot be encoded with a REX prefix."
				end
				return detail
			end
		end
	end

	local number, suffix = token:match("^r(%d+)([dwb]?)$")
	number = tonumber(number)
	if number and number >= 8 and number <= 31 then
		local width = ({ [""] = 64, d = 32, w = 16, b = 8 })[suffix]
		local detail = string.format(
			"A **%d-bit** view of extended general-purpose register %s. Writing its 32-bit view zero-extends; narrower writes preserve the other bits.",
			width,
			code("r" .. number)
		)
		if number >= 16 then
			detail = detail .. " Registers R16-R31 require Intel APX/REX2 encodings."
		end
		return detail
	end
end

local function amd64_register(token)
	local gpr = x86_gpr(token)
	if gpr then
		return gpr
	end

	if token == "rip" or token == "eip" or token == "ip" then
		local width = token == "rip" and 64 or (token == "eip" and 32 or 16)
		return string.format(
			"The **%d-bit instruction pointer**. It identifies the next instruction; x86-64 also supports RIP-relative addressing. It is not an ordinary general-purpose destination register.",
			width
		)
	end
	if token == "rflags" or token == "eflags" or token == "flags" then
		return "The architectural flags register. Arithmetic status includes CF, PF, AF, ZF, SF, and OF; control and system state includes DF, IF, and TF."
	end
	if token == "riz" or token == "eiz" then
		return "A disassembler pseudo-register meaning a constant zero index. It is not an encodable physical x86 register."
	end

	local segment_roles = {
		cs = "code segment",
		ss = "stack segment",
		ds = "data segment",
		es = "extra data segment",
		fs = "FS segment, whose hidden base commonly addresses thread-local storage",
		gs = "GS segment, whose hidden base commonly addresses thread- or kernel-local storage",
	}
	if segment_roles[token] then
		return "The **"
			.. segment_roles[token]
			.. " register**. In 64-bit mode most segmentation is disabled, but FS and GS bases remain significant."
	end

	for name, width in pairs({ xmm = 128, ymm = 256, zmm = 512 }) do
		local number = numbered(token, "^" .. name .. "(%d+)$", 0, 31)
		if number then
			return string.format(
				"A **%d-bit SIMD/vector register**. %s aliases the same physical vector state as its XMM, YMM, and ZMM views. Registers 16-31 require AVX-512 encodings.",
				width,
				code(name .. number)
			)
		end
	end

	local mask = numbered(token, "^k(%d+)$", 0, 7)
	if mask then
		return string.format(
			"AVX-512 **opmask register %d**. Its bits predicate vector lanes; K0 conventionally selects an unmasked operation when used as an instruction mask.",
			mask
		)
	end
	local mm = numbered(token, "^mm(%d+)$", 0, 7)
	if mm then
		return string.format(
			"Legacy **64-bit MMX register %d**. MMX aliases the x87 floating-point state, so MMX code restores x87 state with EMMS before x87 use.",
			mm
		)
	end
	local st = tonumber(token:match("^st%((%d)%)$"))
	if token == "st" then
		st = 0
	end
	if st and st <= 7 then
		return string.format(
			"The x87 **80-bit floating-point stack register ST(%d)**. ST(0) is the current top; stack names rotate as x87 pushes and pops.",
			st
		)
	end

	local control = numbered(token, "^cr(%d+)$", 0, 15)
	if control then
		local roles = {
			[0] = "system mode and paging controls",
			[2] = "the page-fault linear address",
			[3] = "the page-table root and PCID",
			[4] = "architectural extension enables",
			[8] = "task-priority filtering for external interrupts",
		}
		return string.format(
			"Privileged **control register CR%d**, containing %s. Unassigned control-register numbers are reserved.",
			control,
			roles[control] or "reserved or extension-defined control state"
		)
	end
	local debug = numbered(token, "^dr(%d+)$", 0, 7)
	if debug then
		local role = debug <= 3 and "a hardware-breakpoint address"
			or ({ [6] = "debug status", [7] = "debug control" })[debug]
		return string.format(
			"Privileged **debug register DR%d**, used for %s. DR4 and DR5 are obsolete aliases or reserved encodings.",
			debug,
			role or "legacy or reserved debug state"
		)
	end
	local bound = numbered(token, "^bnd(%d+)$", 0, 3)
	if bound then
		return string.format(
			"Intel MPX **bounds register BND%d**, holding lower and encoded upper pointer bounds. MPX is deprecated on current processors.",
			bound
		)
	end
	local tile = numbered(token, "^tmm(%d+)$", 0, 7)
	if tile then
		return string.format(
			"Intel AMX **tile register TMM%d**, a two-dimensional byte array whose active shape is defined by TILECFG.",
			tile
		)
	end

	local special = {
		mxcsr = "The SSE/AVX floating-point control and status register: exception flags and masks, rounding mode, denormals-are-zero, and flush-to-zero.",
		xcr0 = "Extended-control register 0. It enables state components managed by XSAVE and XRSTOR, including vector and AMX state.",
		pkru = "Protection Keys Rights for User pages. It controls read/write access for the 16 user protection-key domains.",
		gdtr = "The Global Descriptor Table register, containing the GDT base address and limit.",
		idtr = "The Interrupt Descriptor Table register, containing the IDT base address and limit.",
		ldtr = "The Local Descriptor Table register, containing the selector and cached descriptor for the current LDT.",
		tr = "The task register, containing the selector and cached descriptor for the current Task State Segment.",
		bndcfgs = "Intel MPX supervisor bounds-configuration state. MPX is deprecated on current processors.",
		bndstatus = "Intel MPX bounds-violation status state. MPX is deprecated on current processors.",
	}
	return special[token]
end

local function aarch64_register(token)
	local kind, number = token:match("^([xw])(%d+)$")
	number = tonumber(number)
	if number and number <= 30 then
		local suffix = number == 29 and " It is conventionally the frame pointer."
			or (number == 30 and " It is conventionally the link register." or "")
		return string.format(
			"A **%d-bit AArch64 general-purpose register**. Its X and W names alias the same state; writing W clears the upper 32 bits.%s",
			kind == "x" and 64 or 32,
			suffix
		)
	end
	local aliases = {
		sp = "The 64-bit AArch64 stack pointer.",
		wsp = "The 32-bit stack-pointer view; writes zero-extend into SP.",
		xzr = "The 64-bit zero register. Reads produce zero and writes are discarded.",
		wzr = "The 32-bit zero register. Reads produce zero and writes are discarded.",
		fp = "Alias for X29, conventionally the frame pointer.",
		lr = "Alias for X30, the link register that receives branch-with-link return addresses.",
		pc = "The program counter. It is exposed through PC-relative operations rather than as a general-purpose register.",
		nzcv = "The Negative, Zero, Carry, and Overflow condition flags.",
		ffr = "The SVE First-Fault Register, tracking successful lanes for first-fault and non-faulting loads.",
		za = "The SME scalable matrix accumulator array.",
		zt0 = "The SME2 512-bit lookup-table register.",
	}
	if aliases[token] then
		return aliases[token]
	end

	local prefix, vector_number, arrangement = token:match("^([vbsdqh])(%d+)(.*)$")
	vector_number = tonumber(vector_number)
	if vector_number and vector_number <= 31 then
		local widths = { b = 8, h = 16, s = 32, d = 64, q = 128, v = 128 }
		return string.format(
			"A **%d-bit view of AArch64 SIMD/FP register %d**%s. B, H, S, D, Q, and V names overlap the same 128-bit register.",
			widths[prefix],
			vector_number,
			arrangement ~= "" and " with lane arrangement " .. code(arrangement:gsub("^%.", "")) or ""
		)
	end
	local sve = numbered(token:gsub("%..*$", ""), "^z(%d+)$", 0, 31)
	if sve then
		return string.format(
			"SVE/SME **scalable vector register Z%d**. Its width is selected by the current vector length; element suffixes select a lane view.",
			sve
		)
	end
	local predicate = numbered(token:gsub("%..*$", ""), "^p(%d+)$", 0, 15)
	if predicate then
		return string.format(
			"SVE/SME **predicate register P%d**. Predicate bits control active vector lanes.",
			predicate
		)
	end
	local counter = numbered(token:gsub("%..*$", ""), "^pn(%d+)$", 0, 15)
	if counter then
		return string.format(
			"SME2 **predicate-as-counter register PN%d**, used for predicate counting and multi-vector operations.",
			counter
		)
	end
	if token:match("^za%d*%.?[bhsdq]?$") then
		return "An SME view or tile of the scalable ZA matrix accumulator. Element and tile suffixes select how the shared ZA state is addressed."
	end
	if token:match("^[a-z][a-z0-9_]*_el[0-3]$") then
		return "A named AArch64 **system register** associated with an exception level. Its access and exact semantics are architecture-extension dependent."
	end
end

local function arm32_register(token)
	local number = numbered(token, "^r(%d+)$", 0, 15)
	if number then
		local role = ({ [13] = "stack pointer", [14] = "link register", [15] = "program counter" })[number]
		return string.format(
			"ARM **32-bit core register R%d**%s.",
			number,
			role and ", conventionally the " .. role or ""
		)
	end
	local aliases = {
		sp = "Alias for ARM core register R13, the stack pointer.",
		lr = "Alias for ARM core register R14, the link register.",
		pc = "Alias for ARM core register R15, the program counter.",
		cpsr = "Current Program Status Register: flags, interrupt masks, execution state, and processor mode.",
		spsr = "Saved Program Status Register for an exception mode.",
		fpscr = "Floating-Point Status and Control Register for VFP and NEON arithmetic.",
	}
	if aliases[token] then
		return aliases[token]
	end
	for prefix, info in pairs({ s = { 31, 32 }, d = { 31, 64 }, q = { 15, 128 } }) do
		local vector = numbered(token, "^" .. prefix .. "(%d+)$", 0, info[1])
		if vector then
			return string.format(
				"ARM VFP/NEON **%d-bit %s register %d**. S, D, and Q views overlap the same register bank.",
				info[2],
				prefix:upper(),
				vector
			)
		end
	end
end

local riscv_abi = {
	zero = "hard-wired zero",
	ra = "return address",
	sp = "stack pointer",
	gp = "global pointer",
	tp = "thread pointer",
	fp = "frame pointer / saved register 0",
}

local function riscv_register(token)
	local integer = numbered(token, "^x(%d+)$", 0, 31)
	if integer then
		return string.format(
			"RISC-V **integer register X%d**. X0 is hard-wired to zero; other roles are assigned by the active ABI.",
			integer
		)
	end
	if riscv_abi[token] then
		return "The RISC-V integer ABI register for **" .. riscv_abi[token] .. "**."
	end
	local prefix, number = token:match("^([ast])(%d+)$")
	number = tonumber(number)
	if
		number
		and ((prefix == "a" and number <= 7) or (prefix == "s" and number <= 11) or (prefix == "t" and number <= 6))
	then
		return "A RISC-V integer ABI register (A: argument, S: callee-saved, T: temporary), aliasing an architectural X register."
	end
	local floating = numbered(token, "^f(%d+)$", 0, 31)
	if floating then
		return string.format(
			"RISC-V **floating-point register F%d**. Precision depends on the implemented floating-point extensions.",
			floating
		)
	end
	local fp_prefix, fp_number = token:match("^f([ast])(%d+)$")
	fp_number = tonumber(fp_number)
	if
		fp_number
		and (
			(fp_prefix == "a" and fp_number <= 7)
			or (fp_prefix == "s" and fp_number <= 11)
			or (fp_prefix == "t" and fp_number <= 11)
		)
	then
		return "A RISC-V floating-point ABI register (FA: argument, FS: callee-saved, FT: temporary)."
	end
	local vector = numbered(token, "^v(%d+)$", 0, 31)
	if vector then
		return string.format(
			"RISC-V Vector extension **register V%d**. VLEN is implementation-defined, and LMUL can group consecutive registers.",
			vector
		)
	end
	local special = {
		pc = "The RISC-V program counter, consumed by control-flow and PC-relative operations.",
		fcsr = "Floating-point control and status, combining exception flags and dynamic rounding mode.",
		fflags = "Accrued RISC-V floating-point exception flags.",
		frm = "The RISC-V dynamic floating-point rounding-mode field.",
		vl = "Vector length CSR: the number of active elements.",
		vtype = "Vector type CSR: selected element width, LMUL, and tail/mask policies.",
		vstart = "Vector start-index CSR used to resume a partially completed vector instruction.",
		vcsr = "Combined vector fixed-point rounding-mode and saturation status.",
	}
	return special[token]
end

local function power_register(token)
	for prefix, info in pairs({
		r = { 31, "general-purpose" },
		f = { 31, "floating-point" },
		v = { 31, "Altivec vector" },
		vsr = { 63, "VSX scalar/vector" },
		cr = { 7, "condition-register field" },
		sr = { 15, "segment" },
		acc = { 7, "matrix accumulator" },
	}) do
		local number = numbered(token, "^" .. prefix .. "(%d+)$", 0, info[1])
		if number then
			return string.format("Power ISA **%s register %s%d**.", info[2], prefix:upper(), number)
		end
	end
	local special = {
		lr = "Power ISA Link Register, conventionally holding a subroutine return address.",
		ctr = "Power ISA Count Register, used by counted and indirect branches.",
		xer = "Fixed-Point Exception Register, containing carry and overflow state.",
		fpscr = "Floating-Point Status and Control Register.",
		msr = "Privileged Machine State Register controlling execution mode and facilities.",
	}
	return special[token]
end

local function mos6502_register(token, extended)
	local common = {
		a = "The accumulator, used by arithmetic, logic, and load/store operations.",
		x = "The X index register, used for indexed addressing, counting, and transfers.",
		y = "The Y index register, used for indexed addressing, counting, and transfers.",
		sp = "The stack pointer, indexing the processor's hardware stack.",
		s = "Alias for the stack pointer.",
		pc = "The program counter, identifying the next instruction.",
		p = "The processor status register, containing condition and control flags.",
		sr = "Alias for the processor status register.",
	}
	if common[token] then
		return (extended and "65C816 " or "6502 ") .. common[token]
	end
	if not extended then
		return
	end
	local extra = {
		d = "The 65C816 16-bit direct-page base register.",
		dbr = "The 65C816 data-bank register, supplying the bank byte for most data accesses.",
		db = "Alias for the 65C816 data-bank register.",
		pbr = "The 65C816 program-bank register, supplying the bank byte for instruction fetches.",
		pb = "Alias for the 65C816 program-bank register.",
		e = "The 65C816 emulation-mode state bit, selecting 6502-compatible execution behavior.",
	}
	return extra[token]
end

local function avr_register(token)
	local number = numbered(token, "^r(%d+)$", 0, 31)
	if number then
		return string.format(
			"AVR **8-bit general-purpose register R%d**.%s",
			number,
			number >= 26 and " It participates in the X, Y, or Z pointer pairs." or ""
		)
	end
	local special = {
		x = "AVR 16-bit X pointer pair, R27:R26.",
		y = "AVR 16-bit Y pointer pair, R29:R28; also usable as a frame pointer.",
		z = "AVR 16-bit Z pointer pair, R31:R30; also used for program-memory addressing.",
		sp = "AVR stack pointer.",
		sreg = "AVR Status Register, containing arithmetic flags and global interrupt enable.",
		pc = "AVR program counter.",
	}
	return special[token]
end

local function ptx_register(token)
	local prefix, number = token:match("^%%?([a-z]+)(%d+)$")
	local classes = {
		p = "predicate",
		r = "32-bit integer",
		rd = "64-bit integer/address",
		f = "32-bit floating-point",
		fd = "64-bit floating-point",
		h = "16-bit value",
		rs = "16-bit integer",
	}
	if number and classes[prefix] then
		return string.format(
			"PTX virtual **%s register %%%s%s**. PTX registers are typed per-thread temporaries mapped to hardware by ptxas.",
			classes[prefix],
			prefix,
			number
		)
	end
	local special = {
		laneid = true,
		warpid = true,
		nwarpid = true,
		smid = true,
		nsmid = true,
		gridid = true,
		clock = true,
		clock64 = true,
		globaltimer = true,
		lanemask_eq = true,
		lanemask_le = true,
		lanemask_lt = true,
		lanemask_ge = true,
		lanemask_gt = true,
	}
	if
		special[token]
		or token:match("^n?tid%.[xyz]$")
		or token:match("^n?ctaid%.[xyz]$")
		or token:match("^n?clusterid%.[xyz]$")
		or token:match("^pm[0-7]$")
		or numbered(token, "^envreg(%d+)$", 0, 31)
	then
		return "A read-only PTX **predefined special register**, exposing thread, warp, CTA, cluster, SM, timer, or performance-monitor state."
	end
end

local function sass_register(token)
	if token == "rz" or token == "urz" then
		return "The SASS zero register. Reads produce zero and writes are discarded."
	end
	if token == "pt" or token == "upt" then
		return "The SASS always-true predicate register."
	end
	local prefix, number = token:match("^(u?r)(%d+)$")
	number = tonumber(number)
	if number and number <= (prefix == "ur" and 63 or 255) then
		return string.format(
			"NVIDIA SASS **%s register %s%d**.",
			prefix == "ur" and "uniform general-purpose" or "general-purpose",
			prefix:upper(),
			number
		)
	end
	prefix, number = token:match("^(u?p)(%d+)$")
	number = tonumber(number)
	if number and number <= 7 then
		return string.format(
			"NVIDIA SASS **%s predicate register %s%d**.",
			prefix == "up" and "uniform" or "per-thread",
			prefix:upper(),
			number
		)
	end
	if token:match("^sr_[a-z0-9_.]+$") then
		return "A read-only NVIDIA SASS **special register**, exposing hardware execution state."
	end
end

local register_providers = {
	amd64 = amd64_register,
	aarch64 = aarch64_register,
	arm32 = arm32_register,
	riscv64 = riscv_register,
	power = power_register,
	ptx = ptx_register,
	sass = sass_register,
	avr = avr_register,
	["6502"] = function(token)
		return mos6502_register(token, false)
	end,
	["65c816"] = function(token)
		return mos6502_register(token, true)
	end,
}

local function normalize_architecture(architecture)
	architecture = (architecture or ""):lower()
	return architecture_aliases[architecture] or architecture
end

local function normalize_token(token)
	return (token or ""):lower():gsub("^[$%%]", ""):gsub("[,;:]$", "")
end

function M.register_info(architecture, token)
	local arch = normalize_architecture(architecture)
	if arch == "llvm" and (token or ""):match("^%%") then
		local title = token:upper() .. " — LLVM SSA value"
		return {
			title = title,
			lines = markdown(
				title,
				"An LLVM IR SSA value. Each numbered or named percent-prefixed value is defined once; register allocation later maps live values to machine registers or stack locations."
			),
		}
	end
	local normalized = normalize_token(token)
	local provider = register_providers[arch]
	if not provider then
		return
	end
	local description = provider(normalized)
	if not description then
		return
	end
	local title = token:upper() .. " — " .. arch .. " register"
	return {
		title = title,
		lines = markdown(title, description, references[arch]),
	}
end

local token_character = "[%w_.$%%()]"

function M.token_at(line, column)
	if line == "" then
		return nil
	end
	local index = math.min(math.max(column + 1, 1), #line)
	if not line:sub(index, index):match(token_character) and index > 1 then
		index = index - 1
	end
	if not line:sub(index, index):match(token_character) then
		return nil
	end
	local first, last = index, index
	while first > 1 and line:sub(first - 1, first - 1):match(token_character) do
		first = first - 1
	end
	while last < #line and line:sub(last + 1, last + 1):match(token_character) do
		last = last + 1
	end
	return line:sub(first, last)
end

local instruction_prefixes = {
	bnd = true,
	lock = true,
	notrack = true,
	rep = true,
	repe = true,
	repz = true,
	repne = true,
	repnz = true,
	xacquire = true,
	xrelease = true,
}

function M.mnemonic(line)
	line = line:gsub("^%s*[%x]+:%s+", "")
	line = line:gsub("^%s*[%w_.$@?<>~]+:%s*", "")
	local words = {}
	for word in line:gmatch("[A-Za-z_.][A-Za-z0-9_.]*") do
		table.insert(words, word:lower())
	end
	if #words == 0 or vim.startswith(words[1], ".") then
		return nil
	end
	local index = 1
	while instruction_prefixes[words[index]] and words[index + 1] do
		index = index + 1
	end
	return words[index]
end

local operand_words = {
	byte = true,
	dword = true,
	far = true,
	near = true,
	offset = true,
	ptr = true,
	qword = true,
	short = true,
	tbyte = true,
	word = true,
	xmmword = true,
	ymmword = true,
	zmmword = true,
}

local function instruction_candidates(token, mnemonic)
	local result, seen = {}, {}
	local function add(candidate)
		candidate = normalize_token(candidate)
		if candidate ~= "" and not seen[candidate] then
			seen[candidate] = true
			table.insert(result, candidate)
		end
	end
	local normalized = normalize_token(token)
	if not operand_words[normalized] and not tonumber(normalized) then
		add(normalized)
	end
	add(mnemonic)
	if mnemonic then
		add(mnemonic:gsub("%..*$", ""))
		if #mnemonic > 2 and not mnemonic:find(".", 1, true) and mnemonic:match("[bwlq]$") then
			add(mnemonic:sub(1, -2))
		end
	end
	return result
end

local function open_preview(lines)
	vim.lsp.util.open_floating_preview(lines, "markdown", {
		wrap = true,
		close_events = { "CursorMoved", "InsertEnter", "BufHidden" },
		border = "single",
		focusable = true,
	})
end

local function show_impl()
	local architecture = vim.b.arch
	if not architecture or architecture == vim.NIL then
		vim.notify("Compiler Explorer: assembly architecture is unavailable", vim.log.levels.ERROR)
		return
	end
	local cursor = api.nvim_win_get_cursor(0)
	local line = api.nvim_get_current_line()
	local token = M.token_at(line, cursor[2]) or ""
	local register = M.register_info(architecture, token)
	if register then
		open_preview(register.lines)
		return
	end

	local mnemonic = M.mnemonic(line)
	for _, candidate in ipairs(instruction_candidates(token, mnemonic)) do
		local ok, response = pcall(require("compiler-explorer.rest").tooltip_get, architecture, candidate)
		if ok then
			local title = candidate:upper() .. " — " .. normalize_architecture(architecture)
			open_preview(markdown(title, response.tooltip, response.url))
			return
		end
		if not tostring(response):find("returned 404", 1, true) then
			vim.notify(
				"Compiler Explorer: assembly help request failed: " .. tostring(response),
				vim.log.levels.ERROR,
				{ title = "Compiler Explorer" }
			)
			return
		end
	end

	local subject = mnemonic or normalize_token(token)
	vim.notify(
		"Compiler Explorer: no assembly documentation for " .. (subject ~= "" and subject or "this line"),
		vim.log.levels.ERROR,
		{ title = "Compiler Explorer" }
	)
end

function M.show()
	require("compiler-explorer.async").void(show_impl)()
end

function M.setup()
	local group = api.nvim_create_augroup("CompilerExplorerAssemblyHelp", { clear = true })
	api.nvim_create_autocmd("FileType", {
		group = group,
		pattern = "asm",
		callback = function(event)
			if not api.nvim_buf_get_name(event.buf):match("^compiler%-explorer://") then
				return
			end
			vim.keymap.set("n", "K", M.show, {
				buffer = event.buf,
				desc = "Compiler Explorer: assembly instruction/register help",
			})
			api.nvim_buf_create_user_command(event.buf, "CEAssemblyHelp", M.show, {
				desc = "Show documentation for the assembly instruction or register under the cursor",
				force = true,
			})
		end,
	})
end

M._instruction_candidates = instruction_candidates

return M
