#!/usr/bin/env bash

set -uo pipefail

name=${1:-}

case "$name" in
  ""|/*|*/*|*..*|.*) echo "usage: $0 <theme-name>" >&2; exit 2 ;;
esac

entry=
for root in "$HOME/.local/share/themes" /usr/share/themes; do
  if [ -f "$root/$name/gtk-3.0/gtk-dark.css" ]; then entry="$root/$name/gtk-3.0/gtk-dark.css"; break; fi
done
[ -n "$entry" ] || exit 1

theme_dir=${entry%/gtk-3.0/gtk-dark.css}
user_themes=$HOME/.local/share/themes
system_themes=/usr/share/themes
user_gtk3=${XDG_CONFIG_HOME:-$HOME/.config}/gtk-3.0

declare -A seen=()
declare -A defs=()
nfiles=0
maxfiles=32

walk() {
  local f=$1 real base imp line
  [ -f "$f" ] || return 0

  if [ "$(wc -c < "$f" 2>/dev/null || echo 0)" -gt 1048576 ]; then
    echo "theme-css: skip >1MiB: $f" >&2
    return 0
  fi
  real=$(readlink -f -- "$f" 2>/dev/null) || real=$f
  [ -z "${seen[$real]:-}" ] || return 0
  seen[$real]=1
  nfiles=$((nfiles + 1))
  [ "$nfiles" -le "$maxfiles" ] || return 0
  base=$(dirname -- "$f")

  while IFS= read -r imp || [ -n "$imp" ]; do
    imp=$(printf '%s' "$imp" | tr -d "\"' \t")
    [ -n "$imp" ] || continue
    case "$imp" in
      http://*|https://*|data:*|//*) continue ;;
    esac
    case "$imp" in
      /*) cand=$imp ;;
      *) cand="$base/$imp" ;;
    esac
    real=$(readlink -f -- "$cand" 2>/dev/null) || continue
    case "$real" in
      "$theme_dir"/*|"$user_themes"/*|"$system_themes"/*|"$user_gtk3"/*) walk "$real" ;;
      *) continue ;;
    esac

  done < <(tr "'" '"' < "$f" | sed -n \
    -e 's|^[[:space:]]*@import[[:space:]]*url(\([^)]*\)).*|\1|p' \
    -e 's|^[[:space:]]*@import[[:space:]]*"\([^"]*\)".*|\1|p')

  while IFS= read -r line || [ -n "$line" ]; do
    [ -n "$line" ] || continue
    defs[${line%%=*}]=${line#*=}
  done < <(sed -n \
    's|^[[:space:]]*@define-color[[:space:]]\{1,\}\([A-Za-z0-9_-]\{1,\}\)[[:space:]]\{1,\}\([^;]*\);.*|\1=\2|p' "$f")
}

walk "$entry"

cfg=${XDG_CONFIG_HOME:-$HOME/.config}
ovr="$cfg/gtk-3.0/gtk.css"
ours=
if [ -f "$ovr" ]; then
  first=
  IFS= read -r first <"$ovr" || true

  case "$first" in "/* quickshell theme-apply: generated"*) ours=1 ;; esac
  if [ -z "$ours" ]; then
    cmp -s -- "$ovr" "$theme_dir/gtk-3.0/gtk.css" && ours=1
  fi
  if [ -z "$ours" ]; then
    cmp -s -- "$ovr" "$theme_dir/gtk-3.0/gtk-dark.css" && ours=1
  fi
fi
[ -n "$ours" ] || walk "$ovr"

resolve() {
  local k=$1 v depth=0
  v=${defs[$k]:-}
  while :; do
    case "$v" in
      @*)
        k=${v#@}
        k=${k%%[[:space:]]*}

        [ -n "$k" ] || return 1
        [ -n "${defs[$k]+x}" ] || return 1
        v=${defs[$k]}
        depth=$((depth + 1))
        [ "$depth" -le 8 ] || return 1 ;;
      *) break ;;
    esac
  done
  printf '%s\n' "$v"
}

for k in "${!defs[@]}"; do
  v=$(resolve "$k") || continue
  [ -n "$v" ] || continue
  case "$v" in
    \#*)
      h=${v#\#}
      case "${#h}" in 3|4|6|8) ;; *) continue ;; esac
      case "$h" in *[!0-9A-Fa-f]*) continue ;; esac
      printf '%s=%s\n' "$k" "$v" ;;
    rgb\(*|rgba\(*) printf '%s=%s\n' "$k" "$v" ;;
    *)
      case "$v" in *"("*) continue ;; esac
      case "$v" in *[!A-Za-z]*) continue ;; esac
      printf '%s=%s\n' "$k" "$v" ;;
  esac
done

if [ -n "${2:-}" ]; then printf '#CSSGEN %s\n' "$2"; fi

exit 0
