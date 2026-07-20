{ pkgs, ... }:

# The user's .zshrc drives everything itself — it sources oh-my-zsh from
# ~/.config/zsh/oh-my-zsh and expects custom plugins at
# ~/.config/zsh/custom/plugins/{zsh-autosuggestions,zsh-vi-mode,zsh-syntax-highlighting}.
# We install those from nixpkgs and symlink them into the paths .zshrc expects,
# rather than reformatting the config into HM's programs.zsh options.
{
  home.packages = with pkgs; [
    zsh
    # git, tmux, neovim, direnv are provided by home.nix / other modules.
  ];

  home.file.".zshrc".source = ../dotfiles/zsh/zshrc;
  home.file.".zprofile".source = ../dotfiles/zsh/zprofile;

  # oh-my-zsh installed at $ZSH ($HOME/.config/zsh/oh-my-zsh)
  xdg.configFile."zsh/oh-my-zsh".source =
    "${pkgs.oh-my-zsh}/share/oh-my-zsh";

  # $ZSH_CUSTOM contents (scripts + oh-my-zsh custom plugins)
  xdg.configFile."zsh/custom/single_quote_highlighting.zsh".source =
    ../dotfiles/zsh/custom/single_quote_highlighting.zsh;
  xdg.configFile."zsh/custom/aliases.zsh".source =
    ../dotfiles/zsh/custom/aliases.zsh;

  xdg.configFile."zsh/custom/plugins/zsh-autosuggestions".source =
    "${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions";
  xdg.configFile."zsh/custom/plugins/zsh-vi-mode".source =
    "${pkgs.zsh-vi-mode}/share/zsh-vi-mode";
  xdg.configFile."zsh/custom/plugins/zsh-syntax-highlighting".source =
    "${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting";
}
