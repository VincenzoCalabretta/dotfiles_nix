# ble.sh already highlights single-quoted strings (its syntax_quoted /
# syntax_quotation faces), so this just recolors them to yellow/bold instead
# of adding a new pattern.
type ble-face &>/dev/null && {
    ble-face syntax_quoted='fg=yellow,bold'
    ble-face syntax_quotation='fg=yellow,bold'
}
