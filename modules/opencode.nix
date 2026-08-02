{ pkgs, ... }:

# opencode reads its global config from ~/.config/opencode/opencode.json.
# The config ships verbatim from dotfiles/opencode/ — connect an LLM provider
# there. OpenRouter is built-in: export OPENROUTER_API_KEY and pick a model
# (e.g. "openrouter/deepseek/deepseek-v4-flash"). See
# https://opencode.ai/docs/providers/ for other providers.
{
  home.packages = with pkgs; [
    opencode
  ];

  xdg.configFile."opencode/opencode.json".source =
    ../dotfiles/opencode/opencode.json;
}
