{ pkgs, opencode-mcp-tools, ... }:

let
  system = pkgs.stdenv.hostPlatform.system;

  mcpSearch = opencode-mcp-tools.packages.${system}.mcp-search;
  mcpCodeSearch = opencode-mcp-tools.packages.${system}.mcp-code-search;
  mcpTestRunner = opencode-mcp-tools.packages.${system}.mcp-test-runner;
  mcpGrammar = opencode-mcp-tools.packages.${system}.mcp-grammar;
  mcpRepoIndex = opencode-mcp-tools.packages.${system}.mcp-repo-index;

  mcpServerEntry = pkg: timeout: {
    command = "${pkg}/bin/${pkg.name}";
    args = [ ];
    env = { };
    inherit timeout;
  };
in {
  home.packages = [ pkgs.claude-code ];

  xdg.configFile."claude/mcp.json".text = builtins.toJSON {
    mcpServers = {
      search = mcpServerEntry mcpSearch 5000;
      code-search = mcpServerEntry mcpCodeSearch 5000;
      test-runner = mcpServerEntry mcpTestRunner 300000;
      grammar = mcpServerEntry mcpGrammar 60000;
      repo-index = mcpServerEntry mcpRepoIndex 300000;
    };
  };
}