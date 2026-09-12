# Bash port of oh-my-zsh's lib/directories.zsh (core lib, not an opt-in
# plugin, so these were always loaded under zsh).

# zsh's `auto_pushd` makes every `cd` also push onto the directory stack, so
# `dirs -v`/the numbered aliases below always have something recent to jump
# to. bash's `cd` doesn't do this on its own, so wrap it.
cd() {
    if [[ $# -eq 0 ]]; then
        builtin pushd "$HOME" >/dev/null
    else
        builtin pushd "$@" >/dev/null
    fi
}

d() {
    if [[ -n $1 ]]; then
        dirs "$@"
    else
        dirs -v | head -n 10
    fi
}

# zsh's numbered `1`.."9" aliases jump to that entry in the directory stack
# (via `cd -N`, most-recent-first under `pushdminus`). `pushd +N` is bash's
# closest analogue, counting from the top of `dirs -v` the same way — but
# bash and zsh don't guarantee identical numbering, so double check with
# `dirs -v` if a jump doesn't land where expected.
for _v_dirstack_n in 1 2 3 4 5 6 7 8 9; do
    alias "$_v_dirstack_n"="pushd +$_v_dirstack_n >/dev/null"
done
unset _v_dirstack_n

alias md='mkdir -p'
alias rd='rmdir'

alias lsa='ls -lah'
alias l='ls -lah'
alias ll='ls -lh'
alias la='ls -lAh'

# take/takedir/takeurl/takezip/takegit: mkdir+cd, or download-and-cd into
# whatever a URL/git remote unpacks to. zsh defines `mkcd`/`takedir` as two
# names for one function; bash needs two separate definitions for that.
takedir() {
    mkdir -p "$@" && cd "${!#}"
}
mkcd() {
    takedir "$@"
}

takeurl() {
    local data thedir
    data="$(mktemp)"
    curl -L "$1" >"$data"
    tar xf "$data"
    thedir="$(tar tf "$data" | head -n 1)"
    rm "$data"
    cd "$thedir"
}

takezip() {
    local data thedir
    data="$(mktemp)"
    curl -L "$1" >"$data"
    unzip "$data" -d "./"
    thedir="$(unzip -l "$data" | awk 'NR==4 {print $4}' | sed 's/\/.*//')"
    rm "$data"
    cd "$thedir"
}

takegit() {
    git clone "$1"
    cd "$(basename "${1%%.git}")"
}

take() {
    if [[ $1 =~ ^(https?|ftp).*\.(tar\.(gz|bz2|xz)|tgz)$ ]]; then
        takeurl "$1"
    elif [[ $1 =~ ^(https?|ftp).*\.(zip)$ ]]; then
        takezip "$1"
    elif [[ $1 =~ ^([A-Za-z0-9]+@|https?|git|ssh|ftps?|rsync).*\.git/?$ ]]; then
        takegit "$1"
    else
        takedir "$@"
    fi
}
