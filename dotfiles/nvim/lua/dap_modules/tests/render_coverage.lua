-- Renders a self-contained HTML line-coverage report from the .cov.lua
-- files generate_coverage.sh collects into a data directory.
--
-- Usage: nvim -l render_coverage.lua <data_dir> <output.html> <root> [root ...]
-- Each <root> is either a .lua file, or a directory globbed non-recursively
-- for *.lua files (so tests/ and examples/ subdirectories are naturally
-- excluded when <root> is the dap_modules directory itself).

local data_dir = assert(arg[1], "usage: render_coverage.lua <data_dir> <output.html> <root...>")
local output   = assert(arg[2], "usage: render_coverage.lua <data_dir> <output.html> <root...>")

local this_dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h")
local coverage = dofile(this_dir .. "/coverage.lua")

local files = {}
for i = 3, #arg do
  local root = arg[i]
  if vim.fn.isdirectory(root) == 1 then
    vim.list_extend(files, vim.fn.glob(root .. "/*.lua", false, true))
  else
    table.insert(files, root)
  end
end
table.sort(files)

local merged = coverage.merge(data_dir)

local function escape_html(s)
  return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

-- Lines that never receive a hook event even when "covered" in spirit
-- (blank, full-line comments, bare structural keywords) are reported as
-- "n/a" rather than counted as covered or uncovered, to avoid a report
-- that's misleadingly full of "red" comment lines.
local function classify(trimmed)
  if trimmed == "" then return "na" end
  if trimmed:match("^%-%-") then return "na" end
  if trimmed == "end" or trimmed == "end," or trimmed == "end)" or trimmed == "else"
    or trimmed == "do" or trimmed == "then" or trimmed == "repeat" then
    return "na"
  end
  return "code"
end

local total_coverable, total_covered = 0, 0
local file_reports = {}

for _, path in ipairs(files) do
  local fh = io.open(path, "r")
  if fh then
    local lines = {}
    for line in fh:lines() do table.insert(lines, line) end
    fh:close()

    local hits = merged[path] or {}
    local coverable, covered = 0, 0
    local rows = {}

    for i, text in ipairs(lines) do
      local trimmed = text:match("^%s*(.-)%s*$")
      local kind  = classify(trimmed)
      local count = hits[i]

      if kind == "code" then
        coverable = coverable + 1
        if count and count > 0 then covered = covered + 1 end
      end

      table.insert(rows, { n = i, text = text, kind = kind, count = count })
    end

    total_coverable = total_coverable + coverable
    total_covered = total_covered + covered

    table.insert(file_reports, {
      path      = path,
      name      = vim.fn.fnamemodify(path, ":t"),
      rows      = rows,
      coverable = coverable,
      covered   = covered,
      pct       = coverable > 0 and (covered / coverable * 100) or 100,
    })
  end
end

-- Worst-covered first: that's what actually needs attention.
table.sort(file_reports, function(a, b) return a.pct < b.pct end)

local function pct_class(pct)
  if pct >= 90 then return "good" end
  if pct >= 60 then return "warn" end
  return "bad"
end

local out = {}
local function emit(s) table.insert(out, s) end

local overall_pct = total_coverable > 0 and (total_covered / total_coverable * 100) or 100

emit([[<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>dap_modules coverage</title>
<style>
:root {
  --bg: #ffffff; --fg: #1a1a1a; --muted: #6b7280; --border: #e5e7eb;
  --row-hit-bg: #dcfce7; --row-miss-bg: #fee2e2; --row-na-fg: #9ca3af;
  --good: #16a34a; --warn: #ca8a04; --bad: #dc2626; --card-bg: #f9fafb;
}
@media (prefers-color-scheme: dark) {
  :root {
    --bg: #0f1115; --fg: #e5e7eb; --muted: #9ca3af; --border: #2a2e37;
    --row-hit-bg: #103621; --row-miss-bg: #3a1414; --row-na-fg: #565d6b;
    --good: #4ade80; --warn: #facc15; --bad: #f87171; --card-bg: #171a21;
  }
}
* { box-sizing: border-box; }
body {
  background: var(--bg); color: var(--fg); margin: 0; padding: 2rem;
  font-family: ui-sans-serif, system-ui, sans-serif;
}
h1 { font-size: 1.4rem; margin: 0 0 .25rem; }
.subtitle { color: var(--muted); margin: 0 0 1.5rem; font-size: .9rem; }
.summary { border-collapse: collapse; width: 100%; margin-bottom: 2rem; }
.summary th, .summary td { text-align: left; padding: .4rem .75rem; border-bottom: 1px solid var(--border); }
.summary th { color: var(--muted); font-weight: 600; font-size: .8rem; text-transform: uppercase; }
.summary a { color: inherit; text-decoration: none; }
.summary a:hover { text-decoration: underline; }
.pct { font-variant-numeric: tabular-nums; font-weight: 600; }
.good { color: var(--good); } .warn { color: var(--warn); } .bad { color: var(--bad); }
.bar { display: inline-block; width: 80px; height: 8px; background: var(--border); border-radius: 4px; overflow: hidden; vertical-align: middle; margin-right: .5rem; }
.bar > span { display: block; height: 100%; }
.file { background: var(--card-bg); border: 1px solid var(--border); border-radius: 8px; margin-bottom: 1.5rem; overflow: hidden; }
.file h2 { font-size: .95rem; font-family: ui-monospace, monospace; margin: 0; padding: .6rem 1rem; border-bottom: 1px solid var(--border); }
.src { border-collapse: collapse; width: 100%; font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: .8rem; }
.src td { padding: 0 .5rem; white-space: pre; }
.src .ln { color: var(--muted); text-align: right; width: 3.5em; user-select: none; }
.src .hits { color: var(--muted); text-align: right; width: 3em; user-select: none; }
.src tr.hit { background: var(--row-hit-bg); }
.src tr.miss { background: var(--row-miss-bg); }
.src tr.na .code, .src tr.na .ln, .src tr.na .hits { color: var(--row-na-fg); }
</style>
</head>
<body>
<h1>dap_modules line coverage</h1>
<p class="subtitle">]])
emit(string.format("%d / %d coverable lines (%.1f%%) across %d files -- generated by generate_coverage.sh",
  total_covered, total_coverable, overall_pct, #file_reports))
emit([[</p>
<table class="summary">
<tr><th>File</th><th>Coverage</th><th>Lines</th></tr>
]])

for i, f in ipairs(file_reports) do
  emit(string.format(
    [[<tr><td><a href="#file-%d">%s</a></td><td><span class="bar"><span style="width:%.0f%%;background:var(--%s)"></span></span><span class="pct %s">%.1f%%</span></td><td>%d / %d</td></tr>
]],
    i, escape_html(f.name), f.pct, pct_class(f.pct), pct_class(f.pct), f.pct, f.covered, f.coverable
  ))
end

emit("</table>\n")

for i, f in ipairs(file_reports) do
  emit(string.format('<div class="file"><h2 id="file-%d">%s</h2>\n<table class="src">\n', i, escape_html(f.path)))
  for _, row in ipairs(f.rows) do
    local rowclass
    if row.kind == "na" then
      rowclass = "na"
    elseif row.count and row.count > 0 then
      rowclass = "hit"
    else
      rowclass = "miss"
    end
    emit(string.format(
      '<tr class="%s"><td class="ln">%d</td><td class="hits">%s</td><td class="code">%s</td></tr>\n',
      rowclass, row.n, row.count and tostring(row.count) or "", escape_html(row.text)
    ))
  end
  emit("</table></div>\n")
end

emit("</body></html>\n")

local fh = assert(io.open(output, "w"))
fh:write(table.concat(out))
fh:close()

print(string.format("Coverage: %d/%d (%.1f%%) -> %s", total_covered, total_coverable, overall_pct, output))
