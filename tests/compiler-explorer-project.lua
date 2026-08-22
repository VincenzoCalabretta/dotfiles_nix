local project = require("compiler_explorer_project")

local root = vim.fn.tempname()
vim.fn.mkdir(root .. "/src", "p")
vim.fn.mkdir(root .. "/include dir", "p")
vim.fn.mkdir(root .. "/build", "p")
vim.fn.writefile({ "int answer();" }, root .. "/include dir/project.h")
vim.fn.writefile({ '#include "project.h"', "int answer() { return 42; }" }, root .. "/src/main.cpp")
vim.fn.writefile({ "-DRESPONSE=1 -Wextra" }, root .. "/flags.rsp")

local database = {
	{
		directory = root,
		file = "src/main.cpp",
		arguments = {
			"ccache",
			"/nix/store/compiler/bin/clang++",
			"-I",
			"include dir",
			"-DPROJECT=1",
			"@flags.rsp",
			"-MD",
			"-MF",
			"main.d",
			"-c",
			"src/main.cpp",
			"-o",
			"main.o",
		},
	},
}
vim.fn.writefile({ vim.json.encode(database) }, root .. "/build/compile_commands.json")

local resolved, resolve_error = project.resolve(root .. "/src/main.cpp")
assert(resolved, resolve_error)
assert(resolved.compiler == "nix-clang-cpp", resolved.compiler)
assert(resolved.database == root .. "/build/compile_commands.json", resolved.database)
assert(resolved.flags:find("-DPROJECT=1", 1, true), resolved.flags)
assert(resolved.flags:find("-DRESPONSE=1", 1, true), resolved.flags)
assert(resolved.flags:find("'-I", 1, true) == nil, resolved.flags)
assert(resolved.flags:find("-I", 1, true), resolved.flags)
assert(resolved.flags:find("include dir", 1, true), resolved.flags)
assert(resolved.flags:find("-iquote " .. root .. "/src", 1, true), resolved.flags)
assert(not resolved.flags:find("main.o", 1, true), resolved.flags)
assert(not resolved.flags:find("main.d", 1, true), resolved.flags)
assert(not resolved.flags:find("src/main.cpp", 1, true), resolved.flags)

local split, split_error = project._shell_split([[gcc -I"include dir" -DNAME='hello world' -c src/main.c]])
assert(split, split_error)
assert(vim.deep_equal(split, {
	"gcc",
	"-Iinclude dir",
	"-DNAME=hello world",
	"-c",
	"src/main.c",
}))

local missing_root = vim.fn.tempname()
vim.fn.mkdir(missing_root .. "/src", "p")
vim.fn.writefile({ "int missing;" }, missing_root .. "/src/missing.cpp")
local missing, missing_error = project.resolve(missing_root .. "/src/missing.cpp")
assert(not missing)
assert(missing_error:find("no compile_commands.json found", 1, true), missing_error)

local invalid_root = vim.fn.tempname()
vim.fn.mkdir(invalid_root .. "/src", "p")
vim.fn.writefile({ "int invalid;" }, invalid_root .. "/src/invalid.cpp")
vim.fn.writefile({ "not JSON" }, invalid_root .. "/compile_commands.json")
local invalid, invalid_error = project.resolve(invalid_root .. "/src/invalid.cpp")
assert(not invalid)
assert(invalid_error:find("invalid JSON", 1, true), invalid_error)

vim.fn.writefile({ vim.json.encode({ { directory = invalid_root } }) }, invalid_root .. "/compile_commands.json")
local invalid_entry, invalid_entry_error = project.resolve(invalid_root .. "/src/invalid.cpp")
assert(not invalid_entry)
assert(invalid_entry_error:find("every entry must have a file", 1, true), invalid_entry_error)

local stale_root = vim.fn.tempname()
vim.fn.mkdir(stale_root .. "/src", "p")
vim.fn.writefile({ "int stale;" }, stale_root .. "/src/stale.cpp")
vim.fn.writefile({
	vim.json.encode({
		{
			directory = "/old/checkout",
			file = "/old/checkout/src/stale.cpp",
			arguments = { "clang++", "-c", "/old/checkout/src/stale.cpp" },
		},
	}),
}, stale_root .. "/compile_commands.json")
local stale, stale_error = project.resolve(stale_root .. "/src/stale.cpp")
assert(not stale)
assert(stale_error:find("stale compilation database", 1, true), stale_error)
assert(stale_error:find("regenerate it", 1, true), stale_error)

vim.fn.delete(root, "rf")
vim.fn.delete(missing_root, "rf")
vim.fn.delete(invalid_root, "rf")
vim.fn.delete(stale_root, "rf")
print("compiler_explorer_project: ok")
