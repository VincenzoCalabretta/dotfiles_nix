# Colorize commands when possible.
alias \
	ls="ls -hN --color=auto --group-directories-first" \
	grep="grep --color=auto" \
	diff="diff --color=auto" \
	ccat="highlight --out-format=ansi" \
	ip="ip -color=auto"

# Tmux to enable colorscheme
alias tmux="TERM=screen-256color-bce tmux"

#custom commands
alias \
	src="grep -rn '.' -e " \
	srcw="grep -rnw '.' -e " \
	ksp='cd .steam/root/steamapps/common/Kerbal\ Space\ Program/ && taskset -c 0,2,4 ./KSP.x86_64'

# clear tmux history along with the screen when inside tmux; plain clear otherwise.
clear() {
    [ -n "$TMUX" ] && tmux clear-history
    command clear
}

#ESA-microProp aliases
alias dl='cd $HOME/Nextcloud/workspaceC/ESA-Prop-Software/datalogger/'
alias gs='cd $HOME/Nextcloud/workspaceC/ESA-Prop-Software/old_gss/'
alias gss='cd $HOME/Nextcloud/workspaceC/ESA-Prop-Software/gss_server/'
alias cdh='cd $HOME/Nextcloud/workspaceC/ESA-Prop-Software/cdh/'
alias wsc='cd $HOME/Nextcloud/workspaceC'
alias dl_send='scp -r $HOME/Nextcloud/workspaceC/ESA-Prop-Software/datalogger pi@192.168.0.3:/home/pi/'
alias logc='cd $HOME/Nextcloud/workspaceC/ESA-Prop-Software/log_converter/'

# find a file by (partial) name under the current directory
ff() { find . -iname "*$1*"; }

#neovim fast
alias nn='cd  $HOME/.config/nvim/ && nvim .'
alias nv='nvim'
alias n='nvim'

#parallel make
export NUMCPUS=`grep -c '^processor' /proc/cpuinfo`
alias pmake='time nice make -j$NUMCPUS --load-average=$NUMCPUS'


alias docs='cd $HOME/docs/'

hm() { home-manager switch --flake "$HOME/dotfiles-nix#v"; }

# Build llvm-project and keep the root compile_commands.json (used by clangd)
# in sync, merging in build/runtimes/runtimes-bins/compile_commands.json when
# present so libc++/libc++abi/libunwind sources and tests resolve correctly.
# Run from inside a `nix develop` shell (needs ninja + python3 on PATH).
llvm-ninja() {
  local root
  root=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "llvm-ninja: not inside a git repo" >&2; return 1; }
  ninja -C "$root/build" "$@" || return $?
  python3 - "$root" <<'PYEOF'
import json, sys, pathlib
root = pathlib.Path(sys.argv[1])
build = root / "build" / "compile_commands.json"
runtimes = root / "build" / "runtimes" / "runtimes-bins" / "compile_commands.json"
if not build.exists():
    sys.exit(0)
entries = json.loads(build.read_text())
if runtimes.exists():
    entries += json.loads(runtimes.read_text())
(root / "compile_commands.json").write_text(json.dumps(entries))
print(f"compile_commands.json refreshed: {len(entries)} entries")
PYEOF
}
