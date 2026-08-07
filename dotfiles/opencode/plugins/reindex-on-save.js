// Keeps opencode-mcp-repo-index's per-repo index warm without spending a
// model turn on it: after a file-modifying tool call finishes, run
// `index-once` for the current project in the background. index-once
// reuses the exact same indexing logic index_repo runs over MCP, just
// invoked directly as a CLI subcommand (see mcp-repo-index-rs/src/main.rs)
// - no MCP round-trip, so a slow/small local model never pays for it.
//
// Spawns immediately on each edit (leading-edge throttle, not a trailing
// debounce), through `setsid` and with `proc.unref()` so the reindex is
// fully detached at both the OS (new session) and Bun (not tracked as a
// "must exit before parent" child) level - verified live to matter for
// `opencode run`'s one-shot headless mode, which can exit within tens of
// milliseconds of the last tool call, before an un-detached child would
// otherwise survive. Throttling (instead of no coalescing at all) still
// keeps a rapid burst of edits from spawning one process per edit - each
// spawn is cheap anyway, since index_repo's own content-hash skip makes a
// redundant call near-instant, so occasionally spawning slightly more
// than the strict minimum is a fine trade for correctness in both modes
// (one-shot `run` and the long-lived interactive TUI).
//
// The binary paths are read from ~/.config/opencode/{repo-index-bin,
// setsid-bin} (written by modules/opencode.nix to the exact Nix store
// paths of the packages it already builds) at plugin-load time, rather
// than env vars - a shell-inherited env var only refreshes for processes
// started after a fresh login on this machine (session vars are sourced
// once by .xinitrc at X startup, not per-shell - see home.nix), so plain
// files opencode re-reads on every launch are what actually stays in sync
// with each `home-manager switch`, the same way opencode.json's own
// baked-in MCP server path already does.

import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const WRITE_TOOLS = new Set(["write", "edit", "apply_patch"]);
const THROTTLE_MS = 1500;
const CONFIG_DIR = join(process.env.XDG_CONFIG_HOME || join(homedir(), ".config"), "opencode");

function readConfigFile(name) {
  try {
    return readFileSync(join(CONFIG_DIR, name), "utf8").trim();
  } catch {
    return undefined;
  }
}

export const ReindexOnSave = async ({ directory, worktree }) => {
  const repoIndexBin = readConfigFile("repo-index-bin");
  const setsidBin = readConfigFile("setsid-bin");
  const target = worktree || directory;
  if (!repoIndexBin || !setsidBin) {
    // Not fatal - just means this hook is a no-op until both files exist
    // (e.g. modules/opencode.nix wiring hasn't been deployed yet).
    console.error(`reindex-on-save: couldn't read repo-index-bin/setsid-bin under ${CONFIG_DIR}, skipping`);
    return {};
  }

  let lastSpawnAt = 0;
  const trigger = () => {
    const now = Date.now();
    if (now - lastSpawnAt < THROTTLE_MS) return;
    lastSpawnAt = now;
    try {
      const proc = Bun.spawn([setsidBin, repoIndexBin, "index-once", target], {
        stdout: "ignore",
        stderr: "ignore",
        stdin: "ignore",
      });
      proc.unref();
    } catch (e) {
      console.error(`reindex-on-save: failed to spawn index-once: ${e}`);
    }
  };

  return {
    "tool.execute.after": async (input) => {
      if (WRITE_TOOLS.has(input.tool)) {
        trigger();
      }
    },
  };
};
