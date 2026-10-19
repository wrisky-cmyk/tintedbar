#!/usr/bin/env bash

id="${1:-}"; shift || true
[ -n "$id" ] || exit 0

case "$id" in
    ""|/*|*/*|*..*|.*) exit 0 ;;
esac

app_dirs=()
declare -A _seen=()
add_app_dir() {
    local d="${1%/}"
    [ -n "$d" ] || return 0
    [ -d "$d" ] || return 0
    [ -n "${_seen[$d]:-}" ] && return 0
    _seen[$d]=1
    app_dirs+=("$d")
}

add_app_dirs() {
    local rest="$1" one
    while [ -n "$rest" ]; do
        case "$rest" in
            *:*) one="${rest%%:*}"; rest="${rest#*:}" ;;
            *)   one="$rest"; rest="" ;;
        esac
        add_app_dir "${one%/}/applications"
    done
}
add_app_dir "${XDG_DATA_HOME:-$HOME/.local/share}/applications"
add_app_dirs "${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
add_app_dir "$HOME/.local/share/flatpak/exports/share/applications"
add_app_dir "/var/lib/flatpak/exports/share/applications"

f=""
for d in "${app_dirs[@]}"; do
    for c in "$id" "${id%.desktop}"; do
        [ -f "$d/$c.desktop" ] && { f="$d/$c.desktop"; break 2; }
    done
done

[ -n "$f" ] || exit 0

base=$(basename "$f" .desktop)

case "${id%.desktop}" in
    yazi) exec ghostty --class=yazi -e yazi ;;
esac

if grep -qs '^Terminal=true' "$f"; then
    exec_line=$(sed -n 's/^Exec=//p' "$f" | head -n1)

    exec_line=$(printf '%s' "$exec_line" | sed 's/ %[fFuUdDnNickvm]//g; s/%[fFuUdDnNickvm]//g')
    [ -n "$exec_line" ] || exit 0
    term="${TERMINAL:-alacritty}"

    set -f
    case "$term" in
        alacritty) exec "$term" --class "$base" -e sh -c 'printf "\033]2;%s\007" "$1"; shift; exec "$@"' _ "$base" $exec_line "$@" ;;
        ghostty)   exec "$term" --class="$base" -e sh -c 'printf "\033]2;%s\007" "$1"; shift; exec "$@"' _ "$base" $exec_line "$@" ;;
        *)         exec "$term" -e sh -c 'printf "\033]2;%s\007" "$1"; shift; exec "$@"' _ "$base" $exec_line "$@" ;;
    esac
else
    exec gio launch "$f" "$@"
fi
