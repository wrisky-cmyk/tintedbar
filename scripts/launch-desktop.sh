#!/usr/bin/env bash

empty_ws=0
if [ "${1:-}" = "--empty-ws" ]; then empty_ws=1; shift; fi
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

if [ "$empty_ws" = 1 ] && command -v jq >/dev/null 2>&1; then

    qs_state="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell"
    on=true
    if [ -f "$qs_state/bar-settings.json" ]; then
        v=$(jq -r '.launcherEmptyWs // true' "$qs_state/bar-settings.json" 2>/dev/null) && on=$v
    fi
    if [ "$on" = "true" ] || [ "$on" = "1" ]; then
        if [ -n "${NIRI_SOCKET:-}" ]; then

            wss=$(niri msg -j workspaces 2>/dev/null)
            cur=$(printf '%s' "$wss" | jq -r '
                [.[] | select(.is_focused) | .idx][0] // 0' 2>/dev/null)
            out=$(niri msg -j focused-output 2>/dev/null | jq -r '.name // empty' 2>/dev/null)
            occids=",$(niri msg -j windows 2>/dev/null | jq -r '
                [.[].workspace_id] | join(",")' 2>/dev/null),"
            empty=""
            for pair in $(printf '%s' "$wss" | jq -r --arg out "$out" '
                .[] | select(.output == $out) | select(.idx >= 1 and .idx <= 20) |
                "\(.idx),\(.id)"' 2>/dev/null | sort -n); do
                idx=${pair%%,*}; id=${pair##*,}
                [ "$idx" = "$cur" ] && continue
                case ",$occids," in *",$id,"*) ;; *) empty=$idx; break ;; esac
            done
            if [ -n "$empty" ]; then
                niri msg action focus-workspace "$empty" >/dev/null 2>&1 || true
            fi
        elif [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
            aws=$(hyprctl -j activeworkspace 2>/dev/null)
            cur=$(printf '%s' "$aws" | jq -r '.id // 0' 2>/dev/null)
            mon=$(printf '%s' "$aws" | jq -r '.monitor // ""' 2>/dev/null)

            occ=" $(hyprctl -j workspaces 2>/dev/null | jq -r --arg m "$mon" '
                [.[] | select(.id >= 1 and .id <= 20)
                 | select(((.monitor // "") == $m and .windows > 0)
                          or (.monitor // "") != $m)
                 | .id] | join(" ")' 2>/dev/null) "
            empty=""
            case "$occ" in *" $cur "*) ;; *) empty="$cur" ;; esac
            if [ -z "$empty" ]; then
                for wid in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
                    [ "$wid" = "$cur" ] && continue
                    case "$occ" in *" $wid "*) ;; *) empty="$wid"; break ;; esac
                done
            fi
            if [ -n "$empty" ]; then
                hyprctl dispatch 'hl.dsp.focus({ workspace = "'"$empty"'" })' >/dev/null 2>&1 || true
            fi
        fi
    fi
fi

case "${id%.desktop}" in
    yazi)

        command -v ghostty >/dev/null 2>&1 \
            || { echo "launch-desktop: ghostty not found, cannot start yazi" >&2; exit 127; }
        exec ghostty --class=yazi -e yazi ;;
esac

in_entry=0
desktop_terminal=0
desktop_exec=""
while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
        "[Desktop Entry]") in_entry=1; continue ;;
        "["*"]") in_entry=0; continue ;;
    esac
    [ "$in_entry" = 1 ] || continue
    case "$line" in
        Terminal=*|Terminal[[:space:]]*=*)
            val=${line#*=}
            val=${val#"${val%%[![:space:]]*}"}
            val=${val%"${val##*[![:space:]]}"}
            [ "$val" = "true" ] && desktop_terminal=1
            ;;
        Exec=*|Exec[[:space:]]*=*)
            if [ -z "$desktop_exec" ]; then
                desktop_exec=${line#*=}
                desktop_exec=${desktop_exec#"${desktop_exec%%[![:space:]]*}"}
                desktop_exec=${desktop_exec%"${desktop_exec##*[![:space:]]}"}
            fi
            ;;
    esac
done < "$f"
if [ "$desktop_terminal" = 1 ] && [ -n "$desktop_exec" ]; then
    exec_line=$desktop_exec

    exec_line=$(printf '%s' "$exec_line" | sed 's/ %[fFuUdDnNickvm]//g; s/%[fFuUdDnNickvm]//g')
    [ -n "$exec_line" ] || exit 0

    read -r -a term_argv <<< "${TERMINAL:-alacritty}"
    term="${term_argv[0]}"

    command -v -- "$term" >/dev/null 2>&1 \
        || { echo "launch-desktop: terminal '$term' not found (TERMINAL or default alacritty), cannot start $base" >&2; exit 127; }

    set -f
    case "$term" in
        alacritty) exec "${term_argv[@]}" --class "$base" -e sh -c 'printf "\033]2;%s\007" "$1"; shift; exec "$@"' _ "$base" $exec_line "$@" ;;
        ghostty)   exec "${term_argv[@]}" --class="$base" -e sh -c 'printf "\033]2;%s\007" "$1"; shift; exec "$@"' _ "$base" $exec_line "$@" ;;
        *)         exec "${term_argv[@]}" -e sh -c 'printf "\033]2;%s\007" "$1"; shift; exec "$@"' _ "$base" $exec_line "$@" ;;
    esac
else

    if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && [ $# -eq 0 ] \
            && ! printf '%s' "$f" | LC_ALL=C grep -qz '[[:cntrl:]]'; then

        LC_ALL=C.UTF-8 printf -v shell_f '%q' "$f"
        cmd="gio launch $shell_f"
        esc=${cmd//\\/\\\\}
        esc=${esc//\'/\\\'}
        if hyprctl dispatch "hl.dsp.exec_cmd('$esc')" >/dev/null 2>&1; then
            exit 0
        fi
    fi
    exec gio launch "$f" "$@"
fi
