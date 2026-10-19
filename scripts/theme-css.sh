#!/usr/bin/env bash

set -uo pipefail

name=${1:-}

case "$name" in
  ""|/*|*/*|*..*|.*) echo "用法: $0 <主题名>" >&2; exit 2 ;;
esac

entry=
for root in "$HOME/.local/share/themes" /usr/share/themes; do
  if [ -f "$root/$name/gtk-3.0/gtk-dark.css" ]; then entry="$root/$name/gtk-3.0/gtk-dark.css"; break; fi
done
[ -n "$entry" ] || exit 1

declare -A seen=()
declare -A defs=()
nfiles=0
maxfiles=32

walk() {
  local f=$1 real base imp line
  [ -f "$f" ] || return 0
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
      /*) walk "$imp" ;;
      *) walk "$base/$imp" ;;
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
walk "$cfg/gtk-3.0/gtk.css"

resolve() {
  local k=$1 v depth=0
  v=${defs[$k]:-}
  while :; do
    case "$v" in
      @*)
        k=${v#@}
        k=${k%%[[:space:]]*}
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
