// Keeps opencode-mcp-repo-index's per-repo index warm without spending a
// model turn on it: after a file-modifying tool call finishes, run
// `index-once` for the current project in the background. index-once
// reuses the exact same indexing logic index_repo runs over MCP, just
// invoked directly as a CLI subcommand (see mcp-repo-index-rs/src/main.rs)
// - no MCP round-trip, so a slow/small local model never pays for it.
//
// Debounced: a burst of several edits (the common case - an agent turn
// usually touches more than one file) triggers exactly one reindex shortly
// after the burst settles, not one background process per edit.
//
// The binary path comes from OPENCODE_REPO_INDEX_BIN (set by
// modules/opencode.nix to the exact same Nix store path the `repo-index`
// MCP server itself uses), not hardcoded here, so this file stays a plain
// static config - no Nix templating inside a JS file to get wrong.

const WRITE_TOOLS = new Set(["write", "edit", "apply_patch"]);
const DEBOUNCE_MS = 2000;

export const ReindexOnSave = async ({ directory, worktree, $ }) => {
  const repoIndexBin = process.env.OPENCODE_REPO_INDEX_BIN;
  const target = worktree || directory;
  if (!repoIndexBin) {
    // Not fatal - just means this hook is a no-op until the env var is
    // set (e.g. modules/opencode.nix wiring hasn't been deployed yet).
    console.error("reindex-on-save: OPENCODE_REPO_INDEX_BIN not set, skipping");
    return {};
  }

  let timer;
  const trigger = () => {
    if (timer) clearTimeout(timer);
    timer = setTimeout(() => {
      $`${repoIndexBin} index-once ${target}`.nothrow().quiet();
    }, DEBOUNCE_MS);
  };

  return {
    "tool.execute.after": async (input) => {
      if (WRITE_TOOLS.has(input.tool)) {
        trigger();
      }
    },
  };
};
