local M = {}

local uv = vim.uv or vim.loop

local function normalize(path, directory)
	if not path or path == "" then
		return nil
	end
	if not vim.startswith(path, "/") then
		path = vim.fs.joinpath(directory, path)
	end
	path = vim.fs.normalize(path)
	return uv.fs_realpath(path) or path
end

local function shell_split(command)
	local result = {}
	local token = {}
	local started = false
	local quote
	local index = 1

	local function finish()
		if started then
			table.insert(result, table.concat(token))
			token = {}
			started = false
		end
	end

	while index <= #command do
		local char = command:sub(index, index)
		if quote == "'" then
			if char == "'" then
				quote = nil
			else
				table.insert(token, char)
			end
		elseif quote == '"' then
			if char == '"' then
				quote = nil
			elseif char == "\\" and index < #command then
				index = index + 1
				table.insert(token, command:sub(index, index))
			else
				table.insert(token, char)
			end
		elseif char:match("%s") then
			finish()
		elseif char == "'" or char == '"' then
			started = true
			quote = char
		elseif char == "\\" and index < #command then
			started = true
			index = index + 1
			table.insert(token, command:sub(index, index))
		else
			started = true
			table.insert(token, char)
		end
		index = index + 1
	end

	if quote then
		return nil, "unterminated quote in compilation command"
	end
	finish()
	return result
end

local function read_arguments(entry)
	if type(entry.arguments) == "table" then
		return vim.deepcopy(entry.arguments)
	end
	if type(entry.command) == "string" then
		return shell_split(entry.command)
	end
	return nil, "entry has neither arguments nor command"
end

local function expand_response_files(arguments, directory, depth)
	depth = depth or 0
	if depth > 4 then
		return nil, "response-file nesting is too deep"
	end

	local expanded = {}
	for _, argument in ipairs(arguments) do
		if vim.startswith(argument, "@") then
			local path = normalize(argument:sub(2), directory)
			if not path then
				return nil, "empty response-file path"
			end
			local ok, lines = pcall(vim.fn.readfile, path)
			if not ok then
				return nil, "cannot read response file " .. path
			end
			local nested, split_error = shell_split(table.concat(lines, "\n"))
			if not nested then
				return nil, split_error
			end
			nested, split_error = expand_response_files(nested, directory, depth + 1)
			if not nested then
				return nil, split_error
			end
			vim.list_extend(expanded, nested)
		else
			table.insert(expanded, argument)
		end
	end
	return expanded
end

local function compiler_kind(arguments)
	for index, argument in ipairs(arguments) do
		local basename = vim.fs.basename(argument)
		if basename:match("^clang%+*[%d%.%-]*$") then
			return "clang", index
		end
		if basename:match("^g%+%+[%d%.%-]*$") or basename:match("^gcc[%d%.%-]*$") then
			return "gcc", index
		end
		if basename == "cc" or basename == "c++" then
			return basename == "c++" and "gcc" or "gcc", index
		end
	end
	return nil, 1
end

local function is_cpp(path, arguments)
	for index, argument in ipairs(arguments) do
		if argument == "-x" and arguments[index + 1] then
			return arguments[index + 1]:find("c++", 1, true) ~= nil
		end
		local language = argument:match("^-x(.+)$")
		if language then
			return language:find("c++", 1, true) ~= nil
		end
	end
	local cpp_extensions = {
		cc = true,
		cp = true,
		cpp = true,
		cxx = true,
		["c++"] = true,
		hh = true,
		hpp = true,
		hxx = true,
	}
	return cpp_extensions[vim.fn.fnamemodify(path, ":e"):lower()] == true
end

local path_options = {
	["-I"] = true,
	["-F"] = true,
	["-include"] = true,
	["-imacros"] = true,
	["-idirafter"] = true,
	["-iframework"] = true,
	["-iquote"] = true,
	["-isystem"] = true,
	["-isysroot"] = true,
	["--sysroot"] = true,
}

local discard_with_value = {
	["-o"] = true,
	["-MF"] = true,
	["-MJ"] = true,
	["-MQ"] = true,
	["-MT"] = true,
	["-include-pch"] = true,
	["--serialize-diagnostics"] = true,
}

local discard = {
	["-c"] = true,
	["--compile"] = true,
	["-M"] = true,
	["-MD"] = true,
	["-MG"] = true,
	["-MM"] = true,
	["-MMD"] = true,
	["-MP"] = true,
}

local joined_path_options = {
	"--sysroot=",
	"-iframework",
	"-idirafter",
	"-isystem",
	"-isysroot",
	"-iquote",
	"-I",
	"-F",
}

local function sanitize(arguments, compiler_index, source, directory)
	local flags = { "-iquote", vim.fs.dirname(source) }
	local index = compiler_index + 1
	while index <= #arguments do
		local argument = arguments[index]
		if discard_with_value[argument] then
			index = index + 2
		elseif
			discard[argument]
			or argument:match("^-o.+")
			or argument:match("^-M[FJQT].+")
			or argument:match("^%-%-output=.+")
			or argument:match("^%-%-serialize%-diagnostics=.+")
		then
			index = index + 1
		elseif path_options[argument] and arguments[index + 1] then
			table.insert(flags, argument)
			table.insert(flags, normalize(arguments[index + 1], directory))
			index = index + 2
		elseif not vim.startswith(argument, "-") and normalize(argument, directory) == source then
			index = index + 1
		else
			local handled = false
			for _, prefix in ipairs(joined_path_options) do
				if vim.startswith(argument, prefix) and #argument > #prefix then
					table.insert(flags, prefix .. normalize(argument:sub(#prefix + 1), directory))
					handled = true
					break
				end
			end
			if not handled then
				table.insert(flags, argument)
			end
			index = index + 1
		end
	end
	return flags
end

local function shell_quote(argument)
	if argument:match("^[%w_@%%+=:,./%-]+$") then
		return argument
	end
	return "'" .. argument:gsub("'", "'\\''") .. "'"
end

local function find_database(source)
	local configured = vim.b.compiler_explorer_compile_commands or vim.g.compiler_explorer_compile_commands
	if configured then
		local path = normalize(configured, vim.fs.dirname(source))
		if path and uv.fs_stat(path) then
			return path
		end
		return nil, "configured compilation database does not exist: " .. tostring(path)
	end

	local relative_candidates = {
		"compile_commands.json",
		"build/compile_commands.json",
		"build/debug/compile_commands.json",
		"build/release/compile_commands.json",
		"cmake-build-debug/compile_commands.json",
		"cmake-build-release/compile_commands.json",
		"out/compile_commands.json",
	}
	local directory = vim.fs.dirname(source)
	while directory do
		for _, relative in ipairs(relative_candidates) do
			local candidate = vim.fs.joinpath(directory, relative)
			if uv.fs_stat(candidate) then
				return uv.fs_realpath(candidate) or candidate
			end
		end
		local parent = vim.fs.dirname(directory)
		if parent == directory then
			break
		end
		directory = parent
	end
	return nil, "no compile_commands.json found"
end

local function database_project_root(database)
	local directory = vim.fs.dirname(database)
	local build_directories = {
		build = true,
		debug = true,
		release = true,
		["cmake-build-debug"] = true,
		["cmake-build-release"] = true,
		out = true,
	}
	if build_directories[vim.fs.basename(directory)] then
		return vim.fs.dirname(directory)
	end
	return directory
end

function M.resolve(buffer_path)
	local source = normalize(buffer_path, uv.cwd())
	if not source then
		return nil, "the current buffer has no file path"
	end

	local database, database_error = find_database(source)
	if not database then
		return nil, database_error
	end

	local read_ok, lines = pcall(vim.fn.readfile, database)
	if not read_ok then
		return nil, "cannot read " .. database
	end
	local ok, decoded = pcall(vim.json.decode, table.concat(lines, "\n"))
	if not ok then
		return nil, "cannot parse " .. database .. ": invalid JSON"
	end
	if type(decoded) ~= "table" or not vim.islist(decoded) then
		return nil, "invalid compilation database " .. database .. ": expected a JSON array"
	end

	local entry
	local stale_entry
	local project_root = database_project_root(database)
	local relative_source = source:sub(#project_root + 2)
	for _, candidate in ipairs(decoded) do
		if type(candidate) ~= "table" or type(candidate.file) ~= "string" or candidate.file == "" then
			return nil, "invalid compilation database " .. database .. ": every entry must have a file"
		end
		if candidate.directory ~= nil and type(candidate.directory) ~= "string" then
			return nil, "invalid compilation database " .. database .. ": entry directory must be a string"
		end
		local directory = candidate.directory or vim.fs.dirname(database)
		local candidate_source = normalize(candidate.file, directory)
		if candidate_source == source then
			entry = candidate
			break
		end
		if relative_source ~= "" and vim.endswith(candidate_source, "/" .. relative_source) then
			stale_entry = candidate_source
		end
	end
	if not entry then
		if stale_entry then
			return nil,
				"stale compilation database "
					.. database
					.. ": entry points to "
					.. stale_entry
					.. "; regenerate it for "
					.. project_root
		end
		return nil, "the current file has no compilation database entry"
	end

	local directory = normalize(entry.directory or vim.fs.dirname(database), vim.fs.dirname(database))
	local arguments, arguments_error = read_arguments(entry)
	if not arguments then
		return nil, arguments_error
	end
	arguments, arguments_error = expand_response_files(arguments, directory)
	if not arguments then
		return nil, arguments_error
	end

	local family, compiler_index = compiler_kind(arguments)
	if not family then
		return nil, "cannot identify a GCC or Clang compiler in the database entry"
	end
	local cpp = is_cpp(source, arguments)
	local compiler = string.format("nix-%s-%s", family, cpp and "cpp" or "c")
	local flags = sanitize(arguments, compiler_index, source, directory)

	return {
		compiler = compiler,
		flags = table.concat(vim.tbl_map(shell_quote, flags), " "),
		database = database,
	}
end

function M.compile(opts)
	if vim.bo.filetype == "rust" then
		require("compiler-explorer").compile(opts, false)
		return
	end

	local resolved, resolve_error = M.resolve(vim.api.nvim_buf_get_name(0))
	if not resolved then
		vim.notify(
			"Compiler Explorer: " .. resolve_error .. ". Use :CECompile to enter flags manually.",
			vim.log.levels.ERROR,
			{ title = "Compiler Explorer" }
		)
		return
	end

	local fargs = {
		"compiler=" .. resolved.compiler,
		"flags=" .. resolved.flags,
	}
	vim.list_extend(fargs, opts.fargs)
	vim.notify("Compiler Explorer: using " .. resolved.database, vim.log.levels.INFO)

	require("compiler-explorer").compile({
		line1 = opts.line1,
		line2 = opts.line2,
		bang = opts.bang,
		fargs = fargs,
	}, false)
end

M._shell_split = shell_split

return M
