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
  mcpSearch = opencode-mcp-tools.packages.${system}.mcp-search;
  mcpCodeSearch = opencode-mcp-tools.packages.${system}.mcp-code-search;
  mcpTestRunner = opencode-mcp-tools.packages.${system}.mcp-test-runner;
  mcpGrammar = opencode-mcp-tools.packages.${system}.mcp-grammar;
  searxng = opencode-mcp-tools.packages.${system}.searxng;

  mcpServer = pkg: { type = "local"; command = [ "${pkg}/bin/${pkg.name}" ]; };

  opencodeConfig = {
    "$schema" = "https://opencode.ai/config.json";
    model = "llama.cpp/qwen3-30b-a3b-instruct-2507";
    provider."llama.cpp" = {
      npm = "@ai-sdk/openai-compatible";
      name = "llama-server (local)";
      options.baseURL = "http://127.0.0.1:8080/v1";
      models."qwen3-30b-a3b-instruct-2507" = {
        name = "Qwen3 30B-A3B Instruct Q4_K_M (local)";
        limit = { context = 65536; output = 8192; };
      };
    };
    mcp = {
      search = mcpServer mcpSearch;
      code-search = mcpServer mcpCodeSearch;
      test-runner = mcpServer mcpTestRunner;
      grammar = mcpServer mcpGrammar;
    };
    lsp = true;
  };
in
{
  home.packages = [
    pkgs.opencode
    pkgs.pyright # opencode's built-in Python LSP looks for this exact binary
    pkgs.nixd # opencode's built-in Nix LSP looks for this exact binary
  ];

  xdg.configFile."opencode/opencode.json".text = builtins.toJSON opencodeConfig;

  # On-demand only (`systemctl --user start llama-server` /
  # `opencode-searxng`) - deliberately no [Install]/wantedBy, since
  # auto-starting the 30B model at every login would permanently reserve
  # ~7GB of this laptop's 8GB VRAM whether or not opencode gets used that
  # session.
  systemd.user.services.llama-server = {
    Unit.Description = "Local llama.cpp server (Qwen3-30B-A3B) for opencode";
    Service = {
      ExecStart = "${llamaServer}/bin/${llamaServer.name}";
      Restart = "on-failure";
    };
  };

  systemd.user.services.opencode-searxng = {
    Unit.Description = "Local SearXNG instance backing opencode's mcp_search tool";
    Service = {
      ExecStart = "${searxng}/bin/${searxng.name}";
      Restart = "on-failure";
    };
  };
}
