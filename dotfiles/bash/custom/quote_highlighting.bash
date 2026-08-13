# Bash/ble.sh counterpart to ../../zsh/custom/single_quote_highlighting.zsh.
# ble.sh already highlights single-quoted strings (its syntax_quoted /
# syntax_quotation faces), so this just recolors them to match zsh's
# yellow/bold override instead of adding a new pattern.
type ble-face &>/dev/null && {
    ble-face syntax_quoted='fg=yellow,bold'
    ble-face syntax_quotation='fg=yellow,bold'
}
