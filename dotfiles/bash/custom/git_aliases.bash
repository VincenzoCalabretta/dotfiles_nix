# Small curated subset of oh-my-zsh's git plugin (that plugin defines ~197
# aliases; shell history showed zero real usage of any of them — always
# typed `git ...` in full — so only the handful of universally-known ones
# are ported here).
git_main_branch() {
    command git rev-parse --git-dir &>/dev/null || return

    local ref
    for ref in refs/heads/main refs/heads/trunk refs/heads/mainline \
        refs/heads/default refs/heads/stable refs/heads/master \
        refs/remotes/origin/main refs/remotes/origin/trunk \
        refs/remotes/origin/mainline refs/remotes/origin/default \
        refs/remotes/origin/stable refs/remotes/origin/master \
        refs/remotes/upstream/main refs/remotes/upstream/trunk \
        refs/remotes/upstream/mainline refs/remotes/upstream/default \
        refs/remotes/upstream/stable refs/remotes/upstream/master; do
        if command git show-ref -q --verify "$ref"; then
            echo "${ref##*/}"
            return 0
        fi
    done
}

alias g='git'
alias ga='git add'
alias gaa='git add --all'
alias gst='git status'
alias gco='git checkout'
alias gcm='git checkout $(git_main_branch)'
alias gp='git push'
alias gl='git pull'
alias gd='git diff'
