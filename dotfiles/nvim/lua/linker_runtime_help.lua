-- K-key reference for two things that have no LSP/tags coverage because
-- they're not declared anywhere a language server or ctags looks:
--
--  1) Standard ELF/linker-script *section names* (.text, .init_array, ...).
--     Bound directly to K in `ld` (linker script) buffers.
--  2) C/C++ runtime *symbols* (_start, __cxa_throw, _Znwm, ...) contributed
--     by crt*.o/libgcc/libstdc++/glibc rather than by any header the LSP
--     can see. Exposed via M.lookup() and consumed by
--     compiler_explorer_asm_help.lua as its final fallback tier, since
--     these are exactly the bare symbol names disassembly shows as call
--     targets (`call __cxa_throw@plt`, `call _Znwm@plt`, ...).
--
-- Sourced directly from primary references where one exists: the System V
-- gABI "Special Sections" table, the GNU ld manual, the Itanium C++ ABI
-- (base + exception-handling) specs, and the glibc/GCC crt sources -- see
-- the `refs` table below for exact URLs. A handful of ubiquitous
-- linker/loader symbols (_GLOBAL_OFFSET_TABLE_, __bss_start, etc.) aren't
-- specified in any single manual page; those are long-standing toolchain
-- convention, documented here from that convention rather than a spec.

local M = {}

local api = vim.api
local tick = string.char(96)

local function code(value)
	return tick .. value .. tick
end

local refs = {
	gabi = "https://www.sco.com/developers/gabi/latest/ch4.sheader.html",
	ld_provide = "https://sourceware.org/binutils/docs/ld/PROVIDE.html",
	ld_symbols = "https://sourceware.org/binutils/docs/ld/Symbols.html",
	itanium_abi = "https://itanium-cxx-abi.github.io/cxx-abi/abi.html",
	itanium_eh = "https://itanium-cxx-abi.github.io/cxx-abi/abi-eh.html",
	glibc_start = "https://sourceware.org/git/?p=glibc.git;a=blob;f=csu/libc-start.c",
	crtstuff = "https://gcc.gnu.org/git/?p=gcc.git;a=blob;f=libgcc/crtstuff.c",
	tls_abi = "https://www.akkadia.org/drepper/tls.pdf",
}

local function markdown(title, body, reference)
	local lines = { "## " .. title, "", body }
	if reference then
		vim.list_extend(lines, { "", "[Reference](" .. reference .. ")" })
	end
	return lines
end

-- ── 1. Standard ELF/linker-script section names ──────────────────────────

local sections = {
	-- System V gABI "Special Sections" (ch4.sheader.html)
	[".bss"] = {
		r = "gabi",
		b = "Uninitialized data (`SHT_NOBITS`, `SHF_ALLOC+SHF_WRITE`). It occupies no file space; the OS zero-fills the mapped range at load time.",
	},
	[".comment"] = {
		r = "gabi",
		b = "Version-control / compiler-identification strings (`SHT_PROGBITS`, unmarked -- not loaded into memory).",
	},
	[".data"] = { r = "gabi", b = "Initialized read-write data (`SHT_PROGBITS`, `SHF_ALLOC+SHF_WRITE`)." },
	[".data1"] = { r = "gabi", b = "A second initialized read-write data section, alongside " .. code(".data") .. "." },
	[".debug"] = {
		r = "gabi",
		b = "Unspecified symbolic debugging information (`SHT_PROGBITS`, not loaded); superseded in practice by the DWARF "
			.. code(".debug_*")
			.. " sections below.",
	},
	[".dynamic"] = {
		r = "gabi",
		b = "Dynamic-linking information -- the array of `Elf_Dyn` tag/value entries read by the runtime loader (`SHT_DYNAMIC`, `SHF_ALLOC`; writability is processor-specific).",
	},
	[".dynstr"] = { r = "gabi", b = "String table backing " .. code(".dynsym") .. " (`SHT_STRTAB`, `SHF_ALLOC`)." },
	[".dynsym"] = {
		r = "gabi",
		b = "The dynamic-linking symbol table: symbols this module imports from and exports to other shared objects (`SHT_DYNSYM`, `SHF_ALLOC`).",
	},
	[".fini"] = {
		r = "gabi",
		b = "A single function invoked during process/DSO termination, after atexit handlers (`SHT_PROGBITS`, `SHF_ALLOC+SHF_EXECINSTR`); the classic complement of "
			.. code(".init")
			.. ", superseded by "
			.. code(".fini_array")
			.. ".",
	},
	[".fini_array"] = {
		r = "gabi",
		b = "An array of function pointers run at termination, in *reverse* order (`SHT_FINI_ARRAY`, `SHF_ALLOC+SHF_WRITE`).",
	},
	[".got"] = {
		r = "gabi",
		b = "The Global Offset Table: a per-module table of absolute addresses that position-independent code loads indirectly instead of baking relocations straight into "
			.. code(".text")
			.. " (`SHT_PROGBITS`).",
	},
	[".hash"] = {
		r = "gabi",
		b = "A symbol hash table accelerating dynamic-symbol lookup (`SHT_HASH`, `SHF_ALLOC`); mostly superseded by "
			.. code(".gnu.hash")
			.. " on Linux.",
	},
	[".init"] = {
		r = "gabi",
		b = "A single function invoked during process/DSO startup, before `main` (`SHT_PROGBITS`, `SHF_ALLOC+SHF_EXECINSTR`); the classic complement of "
			.. code(".fini")
			.. ", superseded by "
			.. code(".init_array")
			.. ".",
	},
	[".init_array"] = {
		r = "gabi",
		b = "An array of function pointers run at startup, in order, before `main()` (`SHT_INIT_ARRAY`, `SHF_ALLOC+SHF_WRITE`); populated by C++ global constructors and `__attribute__((constructor))` functions.",
	},
	[".interp"] = {
		r = "gabi",
		b = "The path of the program interpreter (dynamic linker), e.g. `/lib64/ld-linux-x86-64.so.2`, read by the kernel via `PT_INTERP` (`SHT_PROGBITS`).",
	},
	[".line"] = {
		r = "gabi",
		b = "Legacy line-number debugging information linking source lines to machine code (`SHT_PROGBITS`, not loaded); superseded by DWARF "
			.. code(".debug_line")
			.. ".",
	},
	[".note"] = {
		r = "gabi",
		b = "Vendor/system-specific auxiliary information in ELF note format (`SHT_NOTE`); see the specific " .. code(
			".note.*"
		) .. " sections below for the ones actually in use.",
	},
	[".plt"] = {
		r = "gabi",
		b = "The Procedure Linkage Table: stubs that resolve calls into shared objects through the GOT, lazily on first call unless linked `-z now` (`SHT_PROGBITS`).",
	},
	[".preinit_array"] = {
		r = "gabi",
		b = "Function pointers run before "
			.. code(".init_array")
			.. " and before "
			.. code(".init")
			.. "; only meaningful in the main executable, ignored in shared objects (`SHT_PREINIT_ARRAY`, `SHF_ALLOC+SHF_WRITE`).",
	},
	[".rodata"] = {
		r = "gabi",
		b = "Read-only initialized data, normally mapped into a non-writable segment (`SHT_PROGBITS`, `SHF_ALLOC`).",
	},
	[".rodata1"] = { r = "gabi", b = "A second read-only data section, alongside " .. code(".rodata") .. "." },
	[".shstrtab"] = {
		r = "gabi",
		b = "The section-header string table: the name of every section in the file (`SHT_STRTAB`, not loaded).",
	},
	[".strtab"] = { r = "gabi", b = "String table backing " .. code(".symtab") .. "'s symbol names (`SHT_STRTAB`)." },
	[".symtab"] = {
		r = "gabi",
		b = "The full (non-dynamic) symbol table, normally stripped from release binaries (`SHT_SYMTAB`).",
	},
	[".symtab_shndx"] = {
		r = "gabi",
		b = "Extended section-index array for "
			.. code(".symtab")
			.. " entries whose true section index would overflow the 16-bit `st_shndx` field (`SHT_SYMTAB_SHNDX`).",
	},
	[".tbss"] = {
		r = "gabi",
		b = "Uninitialized thread-local storage: one zero-filled copy per thread (`SHT_NOBITS`, `SHF_ALLOC+SHF_WRITE+SHF_TLS`).",
	},
	[".tdata"] = {
		r = "gabi",
		b = "Initialized thread-local storage, copied into each new thread's TLS block (`SHT_PROGBITS`, `SHF_ALLOC+SHF_WRITE+SHF_TLS`).",
	},
	[".tdata1"] = {
		r = "gabi",
		b = "A second initialized thread-local-storage section, alongside " .. code(".tdata") .. ".",
	},
	[".text"] = {
		r = "gabi",
		b = "The program's executable machine instructions (`SHT_PROGBITS`, `SHF_ALLOC+SHF_EXECINSTR`).",
	},

	-- GNU/Linux toolchain extensions in near-universal use, outside the gABI table
	[".eh_frame"] = {
		r = "ld_symbols",
		b = "Call-frame information (CFI) in DWARF format describing how to unwind each function's stack frame; read by the C++ exception unwinder and by debuggers/backtrace tools.",
	},
	[".eh_frame_hdr"] = {
		r = "ld_symbols",
		b = "A compact, binary-searchable index over "
			.. code(".eh_frame")
			.. " so the unwinder can find a PC's FDE without a linear scan; emitted by `--eh-frame-hdr`.",
	},
	[".gcc_except_table"] = {
		r = "ld_symbols",
		b = "GCC's per-function exception tables (the LSDA -- Language-Specific Data Area): try/catch regions and their handlers, referenced from "
			.. code(".eh_frame")
			.. "'s augmentation data.",
	},
	[".got.plt"] = {
		r = "ld_symbols",
		b = "The subset of the GOT used by "
			.. code(".plt")
			.. " stubs; entry 0 holds a linker-reserved value, and unresolved entries initially point back into the PLT's lazy-binding resolver.",
	},
	[".plt.sec"] = {
		r = "ld_symbols",
		b = "Secondary PLT stubs emitted for `-fcf-protection`/IBT or retpoline (`-mindirect-branch=thunk`) builds, kept separate from the main "
			.. code(".plt")
			.. " so those mitigations don't add an extra indirection to every call.",
	},
	[".plt.got"] = {
		r = "ld_symbols",
		b = "PLT-style call stubs for symbols that already have a GOT entry from an ordinary (non-PLT) relocation, avoiding a duplicate GOT slot.",
	},
	[".data.rel.ro"] = {
		r = "ld_symbols",
		b = "Initialized data that needs a load-time relocation but is otherwise constant (vtables, `const` pointers): placed separately so the loader can `mprotect` it read-only after relocating it (RELRO hardening).",
	},
	[".data.rel.ro.local"] = {
		r = "ld_symbols",
		b = "The "
			.. code(".data.rel.ro")
			.. " subset whose relocations are against local (non-preemptible) symbols, split out for finer-grained RELRO placement.",
	},
	[".ctors"] = {
		r = "crtstuff",
		b = "Legacy, pre-"
			.. code(".init_array")
			.. " array of C++ global-constructor pointers, conventionally walked back-to-front; superseded by "
			.. code(".init_array")
			.. " but still emitted on some targets/toolchains.",
	},
	[".dtors"] = {
		r = "crtstuff",
		b = "Legacy, pre-"
			.. code(".fini_array")
			.. " array of C++ global-destructor pointers, the "
			.. code(".ctors")
			.. " counterpart; superseded by "
			.. code(".fini_array")
			.. ".",
	},
	[".jcr"] = {
		r = "crtstuff",
		b = "Java Class Registration table: pointers to compiler-emitted per-translation-unit class records for GCC's long-removed Java front end. Mostly startup-time dead weight on modern toolchains, but the section and its crt plumbing linger for ABI compatibility.",
	},
	[".tm_clone_table"] = {
		r = "crtstuff",
		b = "A table of (original-function, transactional-memory-clone) pairs from GCC's `-fgnu-tm` support, registered with libitm via `register_tm_clones`.",
	},
	[".rela.dyn"] = {
		r = "gabi",
		b = "RELA relocations applied to data at load time (e.g. fixing up a shared library's global pointers) -- the dynamic linker's data relocation work list (`SHT_RELA`).",
	},
	[".rela.plt"] = {
		r = "gabi",
		b = "RELA relocations for the "
			.. code(".got.plt")
			.. " entries of imported functions, applied eagerly under `-z now` or lazily as each PLT stub is first taken.",
	},
	[".rel.dyn"] = {
		r = "gabi",
		b = "The REL-format (implicit addend) equivalent of "
			.. code(".rela.dyn")
			.. ", used on targets whose relocations don't carry an explicit addend field (e.g. 32-bit x86, 32-bit ARM).",
	},
	[".rel.plt"] = { r = "gabi", b = "The REL-format equivalent of " .. code(".rela.plt") .. "." },
	[".gnu.hash"] = {
		r = "ld_symbols",
		b = "GNU's faster, smaller replacement for the gABI "
			.. code(".hash")
			.. " symbol-lookup table; the default on essentially all current Linux toolchains.",
	},
	[".gnu.version"] = {
		r = "ld_symbols",
		b = "Per-`.dynsym`-entry symbol-versioning indices (`SHT_GNU_versym`), pairing each dynamic symbol with a version defined in "
			.. code(".gnu.version_d")
			.. " or required from "
			.. code(".gnu.version_r")
			.. ".",
	},
	[".gnu.version_d"] = {
		r = "ld_symbols",
		b = "Version definitions this shared object exports (`SHT_GNU_verdef`), e.g. glibc's `GLIBC_2.34`.",
	},
	[".gnu.version_r"] = {
		r = "ld_symbols",
		b = "Version requirements this object places on the symbols it imports from other shared objects (`SHT_GNU_verneed`).",
	},
	[".note.gnu.build-id"] = {
		r = "ld_symbols",
		b = "A build-unique identifier (typically a hash) used to correlate a binary with its separate debug-info file and by crash-report/symbol servers.",
	},
	[".note.gnu.property"] = {
		r = "ld_symbols",
		b = "GNU program-property notes -- e.g. `GNU_PROPERTY_X86_FEATURE_1_AND` flags advertising IBT/SHSTK (Intel CET) support -- read by the loader and by `ld -z` compatibility checks.",
	},
	[".note.GNU-stack"] = {
		r = "ld_symbols",
		b = "An empty marker note whose presence/absence controls whether the linker emits an executable-stack `PT_GNU_STACK` program header; modern toolchains default to a non-executable stack.",
	},
	[".note.ABI-tag"] = {
		r = "ld_symbols",
		b = "Records the minimum OS/kernel ABI this binary expects (e.g. a minimum Linux kernel version), checked by the dynamic loader.",
	},
	[".ARM.exidx"] = {
		r = "ld_symbols",
		b = "ARM EHABI exception-index table: compact per-function unwind entries, AArch32's replacement for " .. code(
			".eh_frame"
		) .. " (paired with " .. code(".ARM.extab") .. " for entries too large to inline).",
	},
	[".ARM.extab"] = {
		r = "ld_symbols",
		b = "Extended ARM EHABI unwinding/exception-handling tables referenced by out-of-line entries in " .. code(
			".ARM.exidx"
		) .. ".",
	},
	[".ARM.attributes"] = {
		r = "ld_symbols",
		b = "Build-attribute section recording ABI/ISA choices (FP ABI, extensions, ...) the linker checks for compatibility across input objects.",
	},
	[".gnu.attributes"] = {
		r = "ld_symbols",
		b = "The architecture-generic form of a build-attributes section; " .. code(".ARM.attributes") .. "/" .. code(
			".riscv.attributes"
		) .. " are its per-architecture names.",
	},
	[".sdata"] = {
		r = "ld_symbols",
		b = '"Small data": data below a configurable size threshold, placed near the GOT/GP register on GP-relative architectures (MIPS, RISC-V, historically PowerPC) so it\'s addressable with one relative load instead of a full address computation.',
	},
	[".sbss"] = { r = "ld_symbols", b = "The uninitialized counterpart of " .. code(".sdata") .. "." },
	[".gnu_debuglink"] = {
		r = "ld_symbols",
		b = "Holds the filename (and a CRC) of a separate file containing this binary's debug info, letting `gdb`/`objdump` find it after `strip --only-keep-debug`.",
	},
	[".gnu_debugdata"] = {
		r = "ld_symbols",
		b = "A compressed (xz/LZMA) minimal symbol table produced by `objcopy`'s MiniDebugInfo, for symbolizing stripped binaries without a full separate debug file.",
	},
	["COMMON"] = {
		r = "ld_symbols",
		b = 'Not a real ELF section: the pseudo-section name GNU ld scripts use in an input-section pattern (e.g. `*(COMMON)`) to match Fortran/C "common" (possibly multiply-defined, uninitialized) symbols, which the linker normally folds into '
			.. code(".bss")
			.. ".",
	},

	-- DWARF debugging-information sections
	[".debug_info"] = {
		r = "ld_symbols",
		b = "DWARF: the core per-compilation-unit debugging-information entries (DIEs) -- types, variables, functions -- forming a tree rooted at each compilation unit.",
	},
	[".debug_abbrev"] = {
		r = "ld_symbols",
		b = "DWARF: abbreviation tables letting "
			.. code(".debug_info")
			.. " encode each DIE compactly, by referencing a previously-declared attribute/tag pattern instead of repeating it.",
	},
	[".debug_line"] = {
		r = "ld_symbols",
		b = "DWARF: the line-number program mapping machine-code addresses back to source file/line/column; what debuggers and backtrace symbolizers use to show source locations.",
	},
	[".debug_line_str"] = {
		r = "ld_symbols",
		b = "DWARF5: the string table backing "
			.. code(".debug_line")
			.. "'s file/directory names (split out from the general "
			.. code(".debug_str")
			.. ").",
	},
	[".debug_str"] = {
		r = "ld_symbols",
		b = "DWARF: the string table backing offset references from "
			.. code(".debug_info")
			.. " (names, paths, etc.).",
	},
	[".debug_str_offsets"] = {
		r = "ld_symbols",
		b = "DWARF5: an index of offsets into "
			.. code(".debug_str")
			.. ", letting "
			.. code(".debug_info")
			.. " reference strings with a small index instead of a full offset (and enabling string deduplication across a `.dwp`).",
	},
	[".debug_loc"] = {
		r = "ld_symbols",
		b = "DWARF (pre-5): location-list expressions describing where a variable lives (register, stack slot, memory) across different PC ranges.",
	},
	[".debug_loclists"] = { r = "ld_symbols", b = "DWARF5's more compact encoding of " .. code(".debug_loc") .. "." },
	[".debug_ranges"] = {
		r = "ld_symbols",
		b = "DWARF (pre-5): non-contiguous PC range lists, e.g. for a DIE (like an inlined subroutine) covering several disjoint code ranges.",
	},
	[".debug_rnglists"] = { r = "ld_symbols", b = "DWARF5's more compact encoding of " .. code(".debug_ranges") .. "." },
	[".debug_aranges"] = {
		r = "ld_symbols",
		b = "DWARF: a fast address-to-compilation-unit lookup table, so a debugger can find the right CU for a PC without scanning all of "
			.. code(".debug_info")
			.. ".",
	},
	[".debug_frame"] = {
		r = "ld_symbols",
		b = "DWARF: call-frame information in the same format as "
			.. code(".eh_frame")
			.. ", used when a platform's ABI keeps unwind info out of the loaded/executable "
			.. code(".eh_frame")
			.. " section.",
	},
	[".debug_macinfo"] = {
		r = "ld_symbols",
		b = "DWARF (pre-5): macro-definition/undefinition history for a compilation unit, for debuggers that expand macros.",
	},
	[".debug_names"] = {
		r = "ld_symbols",
		b = "DWARF5's unified name-lookup index, mapping identifier names to the DIEs that define them; supersedes "
			.. code(".debug_pubnames")
			.. "/"
			.. code(".debug_pubtypes")
			.. ".",
	},
	[".debug_pubnames"] = {
		r = "ld_symbols",
		b = "Older GCC-emitted name-to-DIE lookup index for globally visible names; superseded by DWARF5's " .. code(
			".debug_names"
		) .. ".",
	},
	[".debug_pubtypes"] = {
		r = "ld_symbols",
		b = "Older GCC-emitted name-to-DIE lookup index for globally visible types; superseded by DWARF5's " .. code(
			".debug_names"
		) .. ".",
	},
	[".debug_types"] = {
		r = "ld_symbols",
		b = "DWARF4's separate section for de-duplicated type-unit DIEs (referenced by signature from " .. code(
			".debug_info"
		) .. "); dropped again in DWARF5.",
	},
	[".debug_cu_index"] = {
		r = "ld_symbols",
		b = "DWARF package-file (`.dwp`) index mapping a compilation-unit signature to its slice of each `.debug_*` section within the `.dwp`.",
	},
	[".debug_tu_index"] = { r = "ld_symbols", b = "The " .. code(".debug_cu_index") .. " counterpart for type units." },
	[".debug_addr"] = {
		r = "ld_symbols",
		b = "DWARF5: a table of addresses referenced indirectly (by index) from "
			.. code(".debug_info")
			.. "/"
			.. code(".debug_loclists")
			.. ", part of the split-DWARF scheme that keeps addresses out of the (potentially shared/cached) `.dwo` files.",
	},
}

local section_patterns = {
	{
		pattern = "^%.debug_",
		r = "ld_symbols",
		b = "A DWARF debugging-information section (not loaded at runtime); consumed by debuggers, disassemblers, and profilers rather than by the running program.",
	},
	{
		pattern = "^%.rela%.",
		r = "gabi",
		b = "RELA relocation entries (each carrying an explicit addend) to be applied to the correspondingly-named output section at load/link time; the gABI convention names a relocation section "
			.. code(".rela")
			.. " + the target section's name.",
	},
	{
		pattern = "^%.rel%.",
		r = "gabi",
		b = "REL relocation entries (addend taken from the relocated location itself) to be applied to the correspondingly-named output section; the gABI convention names a relocation section "
			.. code(".rel")
			.. " + the target section's name.",
	},
	{
		pattern = "^%.rodata%.cst%d+$",
		r = "ld_symbols",
		b = "A compiler-emitted, mergeable (`SHF_MERGE`) constant-pool section holding literal constants of one fixed size, so the linker can fold identical constants contributed by different translation units.",
	},
	{
		pattern = "^%.text%.hot",
		r = "ld_symbols",
		b = "The hot/frequently-executed partition of `-freorder-functions`-split code, grouped separately for instruction-cache locality.",
	},
	{
		pattern = "^%.text%.unlikely",
		r = "ld_symbols",
		b = "The cold/unlikely-to-execute partition of `-freorder-functions`-split code (e.g. slow paths, `__builtin_expect(..., 0)` targets).",
	},
	{
		pattern = "^%.text%.startup",
		r = "ld_symbols",
		b = "The constructor-only partition of `-freorder-functions`-split code (functions only ever called once, at startup).",
	},
	{
		pattern = "^%.text%.exit",
		r = "ld_symbols",
		b = "The destructor-only partition of `-freorder-functions`-split code.",
	},
	{
		pattern = "^%.text%.",
		r = "gabi",
		b = "A named sub-section of "
			.. code(".text")
			.. " -- typically a per-function section from `-ffunction-sections`, or a linker/COMDAT-merged group -- with the same executable-code semantics as "
			.. code(".text")
			.. " itself.",
	},
	{
		pattern = "^%.data%.",
		r = "gabi",
		b = "A named sub-section of "
			.. code(".data")
			.. " -- typically a per-variable section from `-fdata-sections` -- with the same read-write-data semantics as "
			.. code(".data")
			.. " itself.",
	},
	{
		pattern = "^%.bss%.",
		r = "gabi",
		b = "A named sub-section of " .. code(".bss") .. ", typically a per-variable section from `-fdata-sections`.",
	},
	{
		pattern = "^%.note%.",
		r = "gabi",
		b = "A vendor/system-specific ELF note (`SHT_NOTE`): a small tagged binary record consumed by the loader, an ABI-compatibility check, or tooling, rather than by the program's own code.",
	},
	{
		pattern = "^%.gnu%.",
		r = "ld_symbols",
		b = "A GNU-toolchain extension section (outside the portable gABI section set), used by the GNU linker/loader/binutils for a linker- or loader-specific purpose.",
	},
	{
		pattern = "^%.riscv%.",
		r = "ld_symbols",
		b = "A RISC-V-specific build-metadata section (parallel to "
			.. code(".ARM.attributes")
			.. "), recording ISA/ABI choices the linker checks for compatibility.",
	},
}

function M.section(token)
	local entry = sections[token]
	if not entry then
		for _, rule in ipairs(section_patterns) do
			if token:match(rule.pattern) then
				entry = rule
				break
			end
		end
	end
	if not entry then
		return nil
	end
	local title = token .. " -- linker/ELF section"
	return { title = title, lines = markdown(title, entry.b, refs[entry.r]) }
end

-- ── 2. C/C++ runtime symbols (crt*.o, libgcc, libstdc++, glibc) ──────────

local symbols = {
	-- Process startup / CRT
	["_start"] = {
		b = "The ELF entry point (`e_entry`): the very first instruction the kernel/loader transfers control to, before any C runtime exists. On glibc it's `crt1.o`'s assembly stub, which sets up `argc`/`argv`/`envp` and calls `__libc_start_main`.",
	},
	["__libc_start_main"] = {
		r = "glibc_start",
		b = "glibc's C-runtime bootstrap, called from `_start`: sets up the stack-protector guard and thread-local storage, runs `.preinit_array`/`.init_array`/`_init` callbacks, registers a `.fini_array` teardown via `__cxa_atexit`, then calls `main(argc, argv, envp)` and passes its result to `exit()`.",
	},
	["__libc_csu_init"] = {
		b = "Older glibc/csu helper that walked `.preinit_array` and `.init_array` calling each constructor in order. On current glibc this loop is inlined directly into `__libc_start_main`'s `call_init`, so the symbol may be absent from binaries built with recent glibc.",
	},
	["__libc_csu_fini"] = {
		b = "The `__libc_csu_init` counterpart that walked `.fini_array` in reverse; likewise folded away on current glibc in favor of registering the teardown via `__cxa_atexit`.",
	},
	["__libc_csu_irel"] = {
		b = "glibc CRT startup code that resolves `R_*_IRELATIVE` relocations (GNU indirect functions / IFUNC resolvers) before `.init_array` runs, since an IFUNC-selected implementation might itself be called from a constructor.",
	},
	["_init"] = {
		b = "The single legacy startup function in the `.init` section, invoked once before `.init_array`/`main`; still emitted by `crti.o`/`crtn.o` glue for ABI compatibility even though its body typically just calls `frame_dummy`.",
	},
	["_fini"] = {
		b = "The single legacy shutdown function in the `.fini` section, the `_init` counterpart, invoked once during teardown.",
	},
	["frame_dummy"] = {
		r = "crtstuff",
		b = "GCC `crtstuff.c` code placed in `.init`: registers this object's DWARF CFI frame info and its transactional-memory clone table, so file-scope C++ static objects and TM code work correctly inside a shared library.",
	},
	["register_tm_clones"] = {
		r = "crtstuff",
		b = "GCC `crtstuff.c` helper that registers this object's transactional-memory clone table (`.tm_clone_table`) with libitm via `_ITM_registerTMCloneTable`, becoming a no-op if the program isn't linked against libitm.",
	},
	["deregister_tm_clones"] = {
		r = "crtstuff",
		b = "The `register_tm_clones` counterpart, unregistering the clone table at shutdown.",
	},
	["__do_global_ctors_aux"] = {
		r = "crtstuff",
		b = "Legacy `.ctors`-based constructor runner compiled into `crtbegin.o`/`crtend.o`: walks the `.ctors` array back-to-front calling each constructor, then registers `__do_global_dtors_aux` with `atexit`. Superseded by `.init_array`/`.fini_array` on modern targets.",
	},
	["__do_global_dtors_aux"] = {
		r = "crtstuff",
		b = "Legacy `.dtors`-based destructor runner, the `__do_global_ctors_aux` counterpart; registered via `atexit()` and guarded so it only runs once even if `exit()` is invoked recursively.",
	},
	["__init_array_start"] = {
		b = "Linker-provided boundary symbol marking the start of `.init_array`; startup code iterates the function-pointer array from here up to (not including) `__init_array_end`.",
	},
	["__init_array_end"] = {
		b = "Linker-provided boundary symbol marking the end of `.init_array` (one-past-the-last entry).",
	},
	["__fini_array_start"] = {
		b = "Linker-provided boundary symbol marking the start of `.fini_array`, iterated in *reverse* at teardown (from `__fini_array_end` down to here).",
	},
	["__fini_array_end"] = { b = "Linker-provided boundary symbol marking the end of `.fini_array`." },
	["__preinit_array_start"] = {
		b = "Linker-provided boundary symbol marking the start of `.preinit_array`, meaningful only in the main executable.",
	},
	["__preinit_array_end"] = { b = "Linker-provided boundary symbol marking the end of `.preinit_array`." },
	["etext"] = {
		r = "ld_provide",
		b = "Linker-provided symbol marking the address just past the end of the loaded `.text` (code) segment; the classic Unix convention, emitted via a `PROVIDE(etext = .)`-style rule in the default linker scripts.",
	},
	["_etext"] = {
		r = "ld_provide",
		b = "Underscore-prefixed alias for `etext` (the reserved-namespace form, safe to reference from strict-ISO C).",
	},
	["edata"] = {
		b = "Linker-provided symbol marking the end of the initialized-data (`.data`) segment -- i.e. where `.bss` begins on disk.",
	},
	["_edata"] = { b = "Underscore-prefixed alias for `edata`." },
	["end"] = {
		b = "Linker-provided symbol marking the very end of the program's statically-known address space -- the traditional starting point for a naive `sbrk`-based heap.",
	},
	["_end"] = { b = "Underscore-prefixed alias for `end`." },
	["__bss_start"] = {
		b = "Linker-provided symbol marking the start of `.bss`; some libcs use this rather than `_edata` to find the exact zero-fill boundary when `.data` and `.bss` aren't perfectly adjacent.",
	},
	["__executable_start"] = {
		r = "ld_symbols",
		b = "Linker-provided symbol for the very first address of the executable's first loaded segment, from GNU ld's default linker scripts.",
	},
	["_GLOBAL_OFFSET_TABLE_"] = {
		r = "ld_symbols",
		b = "The linker-defined base address of this module's Global Offset Table (`.got`/`.got.plt`). Position-independent code computes it once (e.g. via `_GLOBAL_OFFSET_TABLE_(%rip)` on x86-64) and indexes into it for every GOT-relative access.",
	},
	["_DYNAMIC"] = {
		r = "ld_symbols",
		b = "The linker-defined address of the `.dynamic` section's array of `Elf_Dyn` tag/value entries -- how `ld.so` (or a static binary's own minimal loader glue) finds things like `DT_NEEDED`, `DT_SYMTAB`, `DT_STRTAB`.",
	},
	["__dso_handle"] = {
		r = "itanium_abi",
		b = 'A private per-DSO "handle" (only its own address matters) passed to `__cxa_atexit`/`__cxa_finalize`, so destructors registered by one shared object can be run for just that object on `dlclose()`.',
	},

	-- Itanium C++ ABI: exception handling
	["__cxa_throw"] = {
		r = "itanium_eh",
		b = "Hands a fully-constructed exception object, its `std::type_info`, and its destructor to the unwind library, beginning stack unwinding to find a matching `catch`.",
	},
	["__cxa_rethrow"] = {
		r = "itanium_eh",
		b = "Re-throws the exception currently being handled (a bare `throw;`), resuming unwinding from the enclosing handler.",
	},
	["__cxa_begin_catch"] = {
		r = "itanium_eh",
		b = "Called on entering a `catch` block: increments the handler count, pushes the exception onto the per-thread caught-exceptions stack, and returns the (possibly adjusted) pointer to the exception object.",
	},
	["__cxa_end_catch"] = {
		r = "itanium_eh",
		b = "Called on leaving a `catch` block: decrements the handler count and, once it reaches zero, destroys and frees the exception object.",
	},
	["__cxa_get_exception_ptr"] = {
		r = "itanium_eh",
		b = "Returns the adjusted exception-object pointer without altering the handler count.",
	},
	["__cxa_allocate_exception"] = {
		r = "itanium_eh",
		b = "Allocates the temporary heap storage (with a small emergency-buffer fallback on out-of-memory) that will hold a thrown exception object, ahead of its constructor running.",
	},
	["__cxa_free_exception"] = {
		r = "itanium_eh",
		b = "Frees exception storage obtained from `__cxa_allocate_exception`, used when constructing the exception object itself fails.",
	},
	["__cxa_get_globals"] = {
		r = "itanium_eh",
		b = "Returns this thread's `__cxa_eh_globals` block (uncaught-exception count and the caught-exceptions stack), lazily initializing it if necessary.",
	},
	["__cxa_get_globals_fast"] = {
		r = "itanium_eh",
		b = "Like `__cxa_get_globals`, but assumes it's already been initialized by a prior call on this thread -- skips the lazy-init check.",
	},
	["__cxa_current_exception_type"] = {
		r = "itanium_eh",
		b = "Returns the `std::type_info` of the exception currently being handled, or null if none.",
	},
	["__cxa_bad_cast"] = {
		r = "itanium_abi",
		b = "Throws `std::bad_cast`; emitted for a `dynamic_cast<T&>` that fails (the pointer form returns null instead of calling this).",
	},
	["__cxa_bad_typeid"] = {
		r = "itanium_abi",
		b = "Throws `std::bad_typeid`; emitted for `typeid` applied through a null polymorphic pointer.",
	},
	["__cxa_call_unexpected"] = {
		r = "itanium_abi",
		b = "Invoked when an exception escapes a function whose (deprecated, pre-C++17) dynamic exception-specification didn't permit it; calls the installed `std::unexpected_handler`.",
	},
	["__cxa_call_terminate"] = {
		r = "itanium_abi",
		b = "Invoked when unwinding fails to find a handler for a new exception raised while another is already propagating (e.g. throwing from a destructor during unwinding); calls `std::terminate`.",
	},
	["__gxx_personality_v0"] = {
		r = "itanium_eh",
		b = "GCC/libstdc++'s C++ personality routine: the function `.eh_frame`'s CFI augmentation points at, which the generic unwinder calls at each frame to test whether that frame's LSDA (`.gcc_except_table`) has a matching `catch`.",
	},
	["_Unwind_RaiseException"] = {
		r = "itanium_eh",
		b = "libgcc's architecture-generic stack unwinder: starts a new unwind (search phase, then cleanup phase) walking `.eh_frame`/CFI and calling each frame's personality routine.",
	},
	["_Unwind_Resume"] = {
		r = "itanium_eh",
		b = "Continues unwinding after a cleanup (destructor) landing pad has finished running.",
	},
	["_Unwind_DeleteException"] = {
		r = "itanium_eh",
		b = "Releases an exception object once unwinding/handling is complete.",
	},
	["_Unwind_GetIP"] = {
		r = "itanium_eh",
		b = "Reads the saved instruction pointer of the stack frame currently being unwound; used by personality routines and landing-pad code.",
	},
	["_Unwind_SetIP"] = {
		r = "itanium_eh",
		b = "Patches the saved instruction pointer of the frame being unwound, to redirect execution into a landing pad.",
	},
	["_Unwind_GetGR"] = {
		r = "itanium_eh",
		b = "Reads a saved general-purpose register of the frame currently being unwound (landing pads use fixed registers to receive the exception pointer/selector).",
	},
	["_Unwind_SetGR"] = {
		r = "itanium_eh",
		b = "Writes a saved general-purpose register of the frame being unwound, e.g. to hand the exception pointer to a landing pad.",
	},
	["_Unwind_Backtrace"] = {
		r = "itanium_eh",
		b = "Walks every frame from the caller outward *without* unwinding, invoking a callback per frame -- the primitive underneath `backtrace()` and crash backtraces.",
	},

	-- Itanium C++ ABI: one-time construction (function-local static guard vars)
	["__cxa_guard_acquire"] = {
		r = "itanium_abi",
		b = "Called before initializing a function-local `static` with a non-constant initializer: returns non-zero (and locks) if this thread should run the initializer, zero if another thread already completed it.",
	},
	["__cxa_guard_release"] = {
		r = "itanium_abi",
		b = 'Marks a function-local `static`\'s guard "initialized" after its initializer completes, and wakes any other thread blocked in `__cxa_guard_acquire`.',
	},
	["__cxa_guard_abort"] = {
		r = "itanium_abi",
		b = "Called if a function-local `static`'s initializer throws: releases the guard without marking it initialized, so a later attempt can retry.",
	},

	-- Itanium C++ ABI: DSO-scoped atexit
	["__cxa_atexit"] = {
		r = "itanium_abi",
		b = "Registers `func(arg)` to run at `exit()`/`dlclose()`, scoped to the DSO identified by `dso_handle`. How C++ global/static destructors -- and `atexit()` itself -- are actually implemented in glibc.",
	},
	["__cxa_finalize"] = {
		r = "itanium_abi",
		b = "Runs (and unregisters) every pending `__cxa_atexit` callback for one DSO, in reverse registration order; called from `_fini`/`dlclose()` teardown, or with a null handle to flush everything at process exit.",
	},
	["__cxa_thread_atexit"] = {
		b = "The `thread_local` analogue of `__cxa_atexit`: registers a destructor to run when the *calling thread* exits, rather than at process exit.",
	},
	["__cxa_thread_atexit_impl"] = { b = "glibc's underlying implementation entry point for `__cxa_thread_atexit`." },

	-- Itanium C++ ABI: pure/deleted virtuals
	["__cxa_pure_virtual"] = {
		r = "itanium_abi",
		b = "The body every pure-virtual vtable slot points to until overridden. Being called at all means a derived class never overrode it (e.g. it was invoked transitively from a base constructor/destructor); it aborts.",
	},
	["__cxa_deleted_virtual"] = {
		r = "itanium_abi",
		b = "The C++11 counterpart of `__cxa_pure_virtual` for a virtual function declared `= delete`. Reaching it is always a bug; it aborts.",
	},

	-- Itanium C++ ABI: array new/delete helpers
	["__cxa_vec_new"] = {
		r = "itanium_abi",
		b = "Allocates and constructs a `new T[n]` array for non-trivial `T` (with a size cookie ahead of the data), destroying already-constructed elements if a later constructor throws.",
	},
	["__cxa_vec_new2"] = {
		r = "itanium_abi",
		b = "`__cxa_vec_new` variant taking a custom (non-default) allocation function.",
	},
	["__cxa_vec_new3"] = {
		r = "itanium_abi",
		b = "`__cxa_vec_new` variant taking both custom allocation and deallocation functions (for exception-safety cleanup).",
	},
	["__cxa_vec_ctor"] = {
		r = "itanium_abi",
		b = "Constructs `n` already-allocated array elements in place, given per-element constructor/destructor pointers (the destructor is used to unwind a partially-constructed array on exception).",
	},
	["__cxa_vec_dtor"] = { r = "itanium_abi", b = "Destroys `n` array elements in reverse order, e.g. for `delete[]`." },
	["__cxa_vec_cleanup"] = {
		r = "itanium_abi",
		b = "Destroys only the already-constructed prefix of a partially-constructed array after a mid-construction exception.",
	},
	["__cxa_vec_delete"] = {
		r = "itanium_abi",
		b = "Destructs every element and frees an array allocated by `__cxa_vec_new`, reading its size back out of the cookie -- the implementation behind `delete[]`.",
	},
	["__cxa_vec_delete2"] = {
		r = "itanium_abi",
		b = "`__cxa_vec_delete` variant using a custom deallocation function.",
	},
	["__cxa_vec_delete3"] = {
		r = "itanium_abi",
		b = "`__cxa_vec_delete` variant using a custom destructor *and* deallocation function.",
	},

	-- Demangling
	["__cxa_demangle"] = {
		b = "libstdc++'s C++ name demangler: converts a mangled Itanium name like `_Znwm` into `operator new(unsigned long)`. The library entry point behind `c++filt` and behind pretty-printed backtraces.",
	},

	-- Mangled operator new/delete, as they literally appear in disassembly call targets
	["_Znwm"] = {
		b = "Mangled `operator new(unsigned long)` (`operator new(size_t)` on LP64) -- the ordinary throwing scalar allocation function.",
	},
	["_Znam"] = { b = "Mangled `operator new[](unsigned long)` -- the ordinary throwing array allocation function." },
	["_ZdlPv"] = { b = "Mangled `operator delete(void*)` -- the ordinary scalar deallocation function." },
	["_ZdaPv"] = { b = "Mangled `operator delete[](void*)` -- the ordinary array deallocation function." },
	["_ZdlPvm"] = {
		b = "Mangled `operator delete(void*, unsigned long)` -- the C++14 *sized* scalar deallocation function, called when the compiler already knows the object's size.",
	},
	["_ZdaPvm"] = {
		b = "Mangled `operator delete[](void*, unsigned long)` -- the C++14 sized array deallocation function.",
	},
	["_ZnwmRKSt9nothrow_t"] = {
		b = "Mangled `operator new(unsigned long, const std::nothrow_t&)` -- the non-throwing scalar allocation overload; returns null instead of throwing `std::bad_alloc`.",
	},
	["_ZnamRKSt9nothrow_t"] = {
		b = "Mangled `operator new[](unsigned long, const std::nothrow_t&)` -- the non-throwing array allocation overload.",
	},
	["_ZSt9terminatev"] = {
		b = "Mangled `std::terminate()` -- calls the installed terminate handler (`std::abort()` by default). Reached when exception handling has no way to continue: no matching handler, an exception escaping during unwinding, a `noexcept` violation, etc.",
	},

	-- TLS (ELF "Handling For Thread-Local Storage" ABI)
	["__tls_get_addr"] = {
		r = "tls_abi",
		b = "The general-dynamic/local-dynamic TLS access function: given a module-ID/offset pair (a `tls_index`), returns the calling thread's address for that `thread_local` variable, lazily allocating its TLS block if needed.",
	},
	["___tls_get_addr"] = {
		r = "tls_abi",
		b = "Double-underscore-prefixed variant of `__tls_get_addr` used by some 32-bit x86 relocation types/toolchains; same purpose.",
	},

	-- Stack protector / hardening
	["__stack_chk_fail"] = {
		b = 'Called by `-fstack-protector`-instrumented function epilogues when the saved stack canary no longer matches. Prints "stack smashing detected" and aborts, since a corrupted canary means a buffer overflow already happened.',
	},
	["__stack_chk_fail_local"] = {
		b = "A PLT-avoiding local trampoline to `__stack_chk_fail`, emitted per-object on some targets/toolchains to save a PLT indirection in the hot check-and-branch epilogue.",
	},
	["__stack_chk_guard"] = {
		b = "The global canary value stack-protector prologues copy onto the stack and epilogues compare against; glibc randomizes it at startup from kernel-supplied entropy.",
	},

	-- errno / process globals
	["__errno_location"] = {
		b = "Returns the address of the calling thread's `errno` storage. `errno` itself is a macro expanding to `(*__errno_location())`, which is how it can be a normal per-thread lvalue without being a literal thread-local variable in every libc.",
	},
	["environ"] = { b = "The process's environment-variable array (`char **`, NULL-terminated)." },
	["__environ"] = { b = "glibc's internal alias for `environ`, kept in sync with the public name." },
	["program_invocation_name"] = {
		b = "glibc global holding `argv[0]` verbatim, set up by `__libc_start_main` before `main` runs; used by `error()` and many CLI tools' diagnostics.",
	},
	["program_invocation_short_name"] = {
		b = "glibc global holding the basename of `argv[0]` (i.e. `program_invocation_name` with any leading directory stripped).",
	},
}

function M.symbol(token)
	local entry = symbols[token]
	if not entry then
		return nil
	end
	local title = token .. " -- C/C++ runtime symbol"
	return { title = title, lines = markdown(title, entry.b, entry.r and refs[entry.r]) }
end

--- Look up TOKEN as either a linker-script section name (leading `.`) or a
--- C/C++ runtime symbol. Returns `{ title, lines }` (see M.section/M.symbol)
--- or nil if TOKEN isn't one of the entries above.
---@param token string
function M.lookup(token)
	if not token or token == "" then
		return nil
	end
	if vim.startswith(token, ".") then
		return M.section(token)
	end
	return M.symbol(token) or (token == "COMMON" and M.section(token)) or nil
end

local token_character = "[%w_.$]"

local function token_at(line, column)
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

local function open_preview(lines)
	return vim.lsp.util.open_floating_preview(lines, "markdown", {
		wrap = true,
		close_events = { "CursorMoved", "InsertEnter", "BufHidden" },
		border = "single",
		focusable = true,
		focus_id = "linker_runtime_help",
	})
end

function M.show()
	local cursor = api.nvim_win_get_cursor(0)
	local line = api.nvim_get_current_line()
	local token = token_at(line, cursor[2])
	local result = token and M.lookup(token)
	if result then
		open_preview(result.lines)
		return
	end
	vim.notify(
		"Linker/runtime help: no reference for " .. (token and code(token) or "this line"),
		vim.log.levels.WARN,
		{ title = "Linker/runtime help" }
	)
end

local function attach(buffer)
	vim.keymap.set("n", "K", M.show, {
		buffer = buffer,
		desc = "Linker section / C++ runtime symbol reference",
	})
	api.nvim_buf_create_user_command(buffer, "LinkerRuntimeHelp", M.show, {
		desc = "Show documentation for the linker-script section name or runtime symbol under the cursor",
		force = true,
	})
end

function M.setup()
	local group = api.nvim_create_augroup("LinkerRuntimeHelp", { clear = true })
	api.nvim_create_autocmd("FileType", {
		group = group,
		pattern = "ld",
		callback = function(event)
			attach(event.buf)
		end,
	})
	if vim.bo.filetype == "ld" then
		attach(api.nvim_get_current_buf())
	end
end

return M
