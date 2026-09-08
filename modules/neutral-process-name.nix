{ config, pkgs, lib, ... }:

# Opt-in, generic: relaunch a package's executable under a neutral name so the
# original name doesn't show up in `ps`/`top`/`htop`/`pgrep`, nor in
# kernel-side records that use a process's comm (OOM-killer messages, audit
# logs). Disabled by default, so the base profile (and the flake's `example`
# home config / CI) never builds the wrapped package.
#
# Why it needs care rather than a plain alias:
#   - The kernel sets a process's `comm` (what `ps -o comm`, `top`, `htop` and
#     OOM/audit records show) to the basename of the file handed to execve,
#     resets it on every exec, ignores argv[0] for it, and uses a symlink's
#     *own* basename rather than its target's.
#   - Many nixpkgs CLIs are makeBinaryWrapper-wrapped: `<pkg>/bin/<cmd>` is a
#     tiny C launcher that adjusts env/PATH and then execs the real ELF beside
#     it as `.<cmd>-wrapped`. That final exec is what pins comm to
#     ".<cmd>-wrapped".
#
# So we bypass that wrapper and exec the real binary ourselves through a
# neutrally-named symlink, reproducing any PATH additions the wrapper made:
#
#   <out>/libexec/<name>-core  -> symlink to the package's real ELF
#                                 => comm becomes "<name>-core"
#   <out>/bin/<name>           -> launcher: optional PATH prefix + `exec -a
#                                 <name>` the symlink => argv[0] (ps aux /
#                                 pgrep -a) is "<name>".
#
# Everything lives in the store and is rebuilt on every `home-manager switch`.
#
# Example (codex, which is makeBinaryWrapper-wrapped and needs ripgrep +
# bubblewrap on PATH — the two things its own nixpkgs wrapper adds):
#
#   dotfiles.neutralProcessName = {
#     enable = true;
#     name = "wrk";
#     package = pkgs.codex;
#     sourceCommand = "codex";
#     extraRuntimePackages = [ pkgs.ripgrep pkgs.bubblewrap ];
#   };
let
  cfg = config.dotfiles.neutralProcessName;

  runtimePath = lib.makeBinPath cfg.extraRuntimePackages;

  # Only emit the PATH line when there is something to prepend; an empty
  # makeBinPath would produce a leading ":" and put CWD on PATH.
  pathExport = lib.optionalString (cfg.extraRuntimePackages != [ ]) ''
    export PATH="${runtimePath}''${PATH:+:$PATH}"'';

  # $0-relative so the launcher finds its sibling symlink wherever the store
  # path ends up; readlink -f follows the ~/.nix-profile/bin/<name> link all
  # the way back to <out>/bin/<name>, so "../libexec/<name>-core" resolves
  # inside this same output.
  launcher = pkgs.writeShellScript cfg.name ''
    here="$(dirname "$(readlink -f "$0")")"
    ${pathExport}
    exec -a ${cfg.name} "$here/../libexec/${cfg.name}-core" "$@"
  '';

  hidden = pkgs.runCommand "neutral-process-name-${cfg.name}"
    {
      meta.description =
        "a package launched under a neutral process name (${cfg.name})";
    }
    ''
      mkdir -p "$out/bin" "$out/libexec"

      # Prefer the real ELF behind a makeBinaryWrapper ('.*-wrapped'), so comm
      # becomes "${cfg.name}-core" instead of the wrapper's name.
      core=""
      for f in ${cfg.package}/bin/.*-wrapped; do
        [ -e "$f" ] && core="$f"
      done
      ${lib.optionalString (cfg.sourceCommand != null) ''
        # Fall back to the named command if the package isn't wrapper-wrapped.
        if [ -z "$core" ] && [ -e "${cfg.package}/bin/${cfg.sourceCommand}" ]; then
          core="${cfg.package}/bin/${cfg.sourceCommand}"
        fi
      ''}
      if [ -z "$core" ]; then
        echo "neutralProcessName: no binary to wrap found in ${cfg.package}/bin;" >&2
        echo "  set dotfiles.neutralProcessName.sourceCommand to the command name." >&2
        exit 1
      fi

      ln -s "$core" "$out/libexec/${cfg.name}-core"
      cp ${launcher} "$out/bin/${cfg.name}"
      chmod +x "$out/bin/${cfg.name}"
    '';
in
{
  options.dotfiles.neutralProcessName = {
    enable = lib.mkEnableOption ''
      wrapping a package so it launches under a neutral process name, hiding
      the original from ps/top/htop/pgrep and kernel comm-based records
      (OOM-killer messages, audit logs)'';

    name = lib.mkOption {
      type = lib.types.str;
      default = "wrk";
      description = ''
        Neutral command name installed on PATH, and the visible process name:
        argv[0] (ps aux / pgrep -a) becomes this, and the kernel comm
        (ps -o comm / top / htop) becomes "<name>-core".
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      description = ''
        Package whose executable is relaunched under the neutral name. Its real
        makeBinaryWrapper ('.*-wrapped') binary is auto-detected when present;
        otherwise set {option}`sourceCommand`.
      '';
    };

    sourceCommand = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Basename of the command inside `package`/bin to launch, used when the
        package is not makeBinaryWrapper-wrapped (no '.*-wrapped' file).
      '';
    };

    extraRuntimePackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      example = lib.literalExpression "[ pkgs.ripgrep pkgs.bubblewrap ]";
      description = ''
        Packages whose /bin is prepended to PATH for the wrapped process,
        reproducing any PATH additions the package's own nixpkgs wrapper made.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ hidden ];
  };
}
