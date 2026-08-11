{ pkgs, llama-server, opencode-mcp-tools, ... }:

# OpenCode reads its global config from ~/.config/opencode/opencode.json,
# generated below (rather than shipped as a static file) so the "mcp" block
# can embed real Nix store paths for the servers built from the
# llama-server / opencode-mcp-tools flake inputs. That's what makes a plain
# `home-manager switch` on a fresh machine enough: those two repos are
# fetched from Forgejo (10.10.0.101) as flake inputs, built here, and wired
# in - no sibling ~/projects checkout or manual `nix run <path>` needed.
#
# `"lsp": true` enables opencode's built-in LSP diagnostics, which
# auto-detect pyright/nixd (installed below) by binary name on PATH.
let
  system = pkgs.stdenv.hostPlatform.system;

  llamaServer = llama-server.packages.${system}.default;
  embedServer = llama-server.packages.${system}.embed-server;
  mcpSearch = opencode-mcp-tools.packages.${system}.mcp-search;
  mcpCodeSearch = opencode-mcp-tools.packages.${system}.mcp-code-search;
  mcpTestRunner = opencode-mcp-tools.packages.${system}.mcp-test-runner;
  mcpGrammar = opencode-mcp-tools.packages.${system}.mcp-grammar;
  mcpRepoIndex = opencode-mcp-tools.packages.${system}.mcp-repo-index;
  searxng = opencode-mcp-tools.packages.${system}.searxng;

  # opencode's default MCP request timeout is 5s - fine for the other
  # servers' tools, but index_repo is a genuine batch operation (parsing +
  # embedding every file, plus per-file subprocess retries in mcp_repo_index
  # - see its chunker.py) that can legitimately take minutes on a real repo.
  mcpServer = pkg: timeout: { type = "local"; command = [ "${pkg}/bin/${pkg.name}" ]; inherit timeout; };

  opencodeConfig = {
    "$schema" = "https://opencode.ai/config.json";
    model = "llama.cpp/qwen3-30b-a3b-instruct-2507";
    provider."llama.cpp" = {
      npm = "@ai-sdk/openai-compatible";
      name = "llama-server (local)";
      options.baseURL = "http://127.0.0.1:8080/v1";
      models."qwen3-30b-a3b-instruct-2507" = {
        name = "Qwen3 30B-A3B Instruct Q4_K_M (local)";
        limit = { context = 98304; output = 8192; };
      };
    };
    mcp = {
      search = mcpServer mcpSearch 5000;
      code-search = mcpServer mcpCodeSearch 5000;
      test-runner = mcpServer mcpTestRunner 300000;
      grammar = mcpServer mcpGrammar 60000;
      repo-index = mcpServer mcpRepoIndex 300000;
    };
    lsp = true;
    # Standing directive, always in context (opencode's AGENTS.md-equivalent
    # mechanism) - written to ~/.config/opencode/AGENTS.md below. Added
    # because a smaller local model was observed only reaching for
    # repo-index's tools when explicitly told to, not proactively - see
    # that file for the actual guidance.
    instructions = [ "~/.config/opencode/AGENTS.md" ];
    # "allow" everything (read/edit/bash/external_directory/etc, equivalent
    # to CLI --auto) - with no "permission" key at all opencode defaults
    # every edit/bash/external_directory action to an interactive
    # ask-for-confirmation prompt. That's fine in the TUI, but it silently
    # stalls/denies actions when there's no one watching to approve (e.g.
    # editing a reposync-mirrored repo under /tmp) and the local model has
    # no way to explain *why* the tool call failed, so it fabricates a
    # plausible-sounding wrong reason instead. Trusted single-user local
    # setup, so blanket allow is acceptable here.
    permission = "allow";
  };

  # Wraps the real opencode binary so `opencode` starts llama-server +
  # opencode-embed on launch and stops them on exit, instead of requiring
  # `systemctl --user start` by hand first. Doesn't just wantedBy-enable the
  # units at login: wantedBy ties a unit to another *unit*'s lifecycle (a
  # target, a socket, etc), and opencode is a plain CLI process, not a
  # systemd unit, so there's no unit-level dependency that means "when this
  # binary runs." Hence wrapping the binary itself.
  #
  # Only stops the servers if no other opencode process is still running
  # (checked via `pgrep -f` against the real binary's exact store path,
  # which only matches actual `opencode` child processes spawned by this
  # wrapper, not the wrapper script itself) - otherwise closing one of
  # several concurrent sessions (e.g. separate tmux panes) would yank the
  # model out from under the others.
  opencodeWrapped = pkgs.writeShellApplication {
    name = "opencode";
    runtimeInputs = [ pkgs.systemd pkgs.procps ];
    text = ''
      real_opencode="${pkgs.opencode}/bin/opencode"

      systemctl --user start llama-server.service opencode-embed.service

      set +e
      "$real_opencode" "$@"
      status=$?
      set -e

      # Only stop the model if no other local opencode session needs it AND
      # no remote client is using it via llama-relay (see llama-relay.socket
      # below) - otherwise closing this session would yank the model out
      # from under a remote user mid-request.
      if ! pgrep -f "$real_opencode" > /dev/null \
        && [ "$(systemctl --user is-active llama-relay.service 2>/dev/null || true)" != "active" ]; then
        systemctl --user stop llama-server.service opencode-embed.service
      fi

      exit "$status"
    '';
  };

  # Waits for llama-server's HTTP API to actually be serving, not just for
  # its systemd unit to be "started" (which happens as soon as the process
  # forks - long before the 30B model finishes loading into VRAM). Used as
  # llama-relay's ExecStartPre so the very first proxied connection (which is
  # what triggers llama-server.service via Requires=/After=, see below)
  # doesn't get forwarded to a port nothing is listening on yet.
  waitForLlama = pkgs.writeShellApplication {
    name = "wait-for-llama";
    runtimeInputs = [ pkgs.curl ];
    text = ''
      for _ in $(seq 1 120); do
        if curl -sf -o /dev/null "http://127.0.0.1:8080/health"; then
          exit 0
        fi
        sleep 1
      done
      echo "wait-for-llama: llama-server did not become healthy within 120s" >&2
      exit 1
    '';
  };

  agentsInstructions = ''
    # Agent instructions

    ## Repo indexing (repo-index MCP server)

    If the `repo-index` MCP server is connected, treat these as default
    behavior, not something to wait to be asked for:

    - At the start of working in a repository (or a subdirectory you
      haven't indexed yet this session), call `index_repo` for its root
      path before doing anything else that needs to understand the
      codebase. It is cheap and safe to call repeatedly - unchanged files
      are skipped, so re-running it after the first call in a session is
      fast.
    - Prefer `semantic_search` and `repo_map` over `grep_code`/glob/file
      listing whenever the question is about *how* something works, *why*
      it's structured a certain way, or where a counterpart/related
      implementation lives that you haven't already located (e.g. "is
      there a C++ version of this Python component?", "where do we handle
      retries?", "what calls this function?"). Don't wait for the user to
      say "use the indexed repository" - if the tool is connected, use it
      as a first resort for these questions, not a last resort.
    - Still use `grep_code`/glob directly when you already know the exact
      file, symbol name, or literal string you're looking for - the index
      is for discovery, not a replacement for exact lookups.
  '';
in
{
  home.packages = [
    opencodeWrapped
    pkgs.pyright # opencode's built-in Python LSP looks for this exact binary
    pkgs.nixd # opencode's built-in Nix LSP looks for this exact binary
  ];

  xdg.configFile."opencode/opencode.json".text = builtins.toJSON opencodeConfig;
  xdg.configFile."opencode/AGENTS.md".text = agentsInstructions;
  xdg.configFile."opencode/plugins/reindex-on-save.js".source =
    ../dotfiles/opencode/plugins/reindex-on-save.js;
  # Read by that plugin (opencode auto-loads any .js/.ts file under
  # ~/.config/opencode/plugins/ - no config.json entry needed, unlike MCP
  # servers or npm-published plugins) at opencode-process-startup time -
  # NOT a home.sessionVariables env var, deliberately: this machine starts
  # X manually via startx/xinit (see home.nix), so session vars are only
  # ever sourced once, by .xinitrc, at X startup - a plain file opencode
  # re-reads on every launch is what actually stays in sync with each
  # `home-manager switch` without requiring a full X session restart,
  # matching how opencode.json's own baked-in MCP server path behaves.
  xdg.configFile."opencode/repo-index-bin".text = "${mcpRepoIndex}/bin/${mcpRepoIndex.name}";
  # `setsid` (util-linux) - the plugin runs index-once through it to give
  # the child its own session, fully detached from opencode's process
  # group. A live test proved this is genuinely necessary, not paranoia:
  # Bun.spawn's own `proc.unref()` (Bun's equivalent of Node's `detached`)
  # was NOT enough on its own to keep the child alive once the *parent*
  # opencode process's process group got torn down (observed with
  # `opencode run`'s one-shot headless mode exiting right after its
  # response) - only adding setsid on top made the reindex reliably
  # survive and actually complete.
  xdg.configFile."opencode/setsid-bin".text = "${pkgs.util-linux}/bin/setsid";

  # On-demand only - deliberately no [Install]/wantedBy, since auto-starting
  # the 30B model at every login would permanently reserve ~7GB of this
  # laptop's 8GB VRAM whether or not opencode gets used that session.
  # llama-server and opencode-embed are instead started/stopped around
  # opencode's own lifecycle by opencodeWrapped, above; opencode-searxng is
  # still fully manual (`systemctl --user start opencode-searxng`).
  systemd.user.services.llama-server = {
    Unit.Description = "Local llama.cpp server (Qwen3-30B-A3B) for opencode";
    Service = {
      ExecStart = "${llamaServer}/bin/${llamaServer.name}";
      Restart = "on-failure";
    };
  };

  # LAN-facing relay onto the loopback-only llama-server above, reachable
  # over the wg1 WireGuard mesh (see wireguard.nix + configuration.nix's
  # networking.firewall.interfaces.wg1.allowedTCPPorts) so another machine
  # can use this laptop's model, not just pve-remote's. Deliberately a
  # separate port (8090) rather than rebinding llama-server itself to
  # 0.0.0.0:8080 - keeps the laptop's own on-demand/loopback default
  # unchanged for local use and adds network exposure only via this socket.
  #
  # Socket-activated (Install.WantedBy sockets.target, live after every
  # login/switch - not requiring `systemctl --user start` by hand) so the
  # *first* remote connection is what lazily starts llama-server.service,
  # via this service's Requires=/After=, without needing opencode open
  # locally at all.
  systemd.user.sockets.llama-relay = {
    Unit.Description = "LAN relay socket for llama-server (wg1 only)";
    Socket = {
      ListenStream = "8090";
      Accept = false;
    };
    Install.WantedBy = [ "sockets.target" ];
  };

  systemd.user.services.llama-relay = {
    Unit = {
      Description = "LAN relay for llama-server (wg1 only)";
      Requires = [ "llama-server.service" ];
      After = [ "llama-server.service" ];
    };
    Service = {
      ExecStartPre = "${waitForLlama}/bin/wait-for-llama";
      ExecStart = "${pkgs.systemd}/lib/systemd/systemd-socket-proxyd 127.0.0.1:8080";
    };
  };

  systemd.user.services.opencode-searxng = {
    Unit.Description = "Local SearXNG instance backing opencode's mcp_search tool";
    Service = {
      ExecStart = "${searxng}/bin/${searxng.name}";
      Restart = "on-failure";
    };
  };

  systemd.user.services.opencode-embed = {
    Unit.Description = "CPU-only embedding server backing opencode's mcp_repo_index tool";
    Service = {
      ExecStart = "${embedServer}/bin/${embedServer.name}";
      Restart = "on-failure";
    };
  };
}
