{ pkgs, ... }:

# Bash counterpart to ./zsh.nix, built the same way: the user's .bashrc
# drives everything itself and expects ble.sh (feature parity with
# zsh-autosuggestions + zsh-syntax-highlighting + zsh-vi-mode) at
# ~/.config/bash/blesh and bash-completion (parity with compinit) at
# ~/.config/bash/bash-completion. We install those from nixpkgs and symlink
# them into the paths .bashrc expects, same technique zsh.nix uses for
# oh-my-zsh.
{
  home.packages = with pkgs; [
    bashInteractive
    # git, tmux, neovim, direnv are provided by home.nix / other modules.
  ];

  home.file.".bashrc".source = ../dotfiles/bash/bashrc;
  # PATH/env setup has no zsh-specific syntax, so bash reuses zsh's zprofile
  # directly rather than maintaining a duplicate that could drift.
  home.file.".bash_profile".source = ../dotfiles/zsh/zprofile;

  xdg.configFile."bash/blesh".source = "${pkgs.blesh}/share/blesh";
  xdg.configFile."bash/bash-completion".source =
    "${pkgs.bash-completion}/share/bash-completion";

  xdg.configFile."bash/custom/quote_highlighting.bash".source =
    ../dotfiles/bash/custom/quote_highlighting.bash;
}
