{ pkgs, ... }:

# The user's .bashrc drives everything itself and expects ble.sh
# (autosuggestions + syntax highlighting + vi mode) at ~/.config/bash/blesh
# and bash-completion at ~/.config/bash/bash-completion. We install those
# from nixpkgs and symlink them into the paths .bashrc expects.
{
  home.packages = with pkgs; [
    bashInteractive
    # git, tmux, neovim, direnv are provided by home.nix / other modules.
  ];

  home.file.".bashrc".source = ../dotfiles/bash/bashrc;
  home.file.".bash_profile".source = ../dotfiles/bash/profile;

  xdg.configFile."bash/blesh".source = "${pkgs.blesh}/share/blesh";
  xdg.configFile."bash/bash-completion".source =
    "${pkgs.bash-completion}/share/bash-completion";

  xdg.configFile."bash/custom/quote_highlighting.bash".source =
    ../dotfiles/bash/custom/quote_highlighting.bash;
  xdg.configFile."bash/custom/aliases.bash".source =
    ../dotfiles/bash/custom/aliases.bash;
  xdg.configFile."bash/custom/dir_utils.bash".source =
    ../dotfiles/bash/custom/dir_utils.bash;
  xdg.configFile."bash/custom/bazel_aliases.bash".source =
    ../dotfiles/bash/custom/bazel_aliases.bash;
  xdg.configFile."bash/custom/git_aliases.bash".source =
    ../dotfiles/bash/custom/git_aliases.bash;
}
