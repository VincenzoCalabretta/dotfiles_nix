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

#neovim fast
alias nn='cd  $HOME/.config/nvim/ && nvim .'
alias nv='nvim'
alias n='nvim'

#parallel make
export NUMCPUS=`grep -c '^processor' /proc/cpuinfo`
alias pmake='time nice make -j$NUMCPUS --load-average=$NUMCPUS'


alias docs='cd $HOME/docs/'

hm() { home-manager switch --flake ~/dotfiles-nix#v; }
