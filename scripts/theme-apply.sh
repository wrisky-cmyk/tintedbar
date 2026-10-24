#!/usr/bin/env bash

set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cfg="${XDG_CONFIG_HOME:-$HOME/.config}"

read_prefer_dark() {
  [ -f "$1" ] || return 0
  v=$(sed -n 's/^[[:space:]]*gtk-application-prefer-dark-theme[[:space:]]*=[[:space:]]*\([^[:space:]]*\).*/\1/p' "$1" | tail -n 1)
  case "$(printf '%s' "$v" | tr '[:upper:]' '[:lower:]')" in
    1|true|yes|on)  printf '1\n' ;;
    0|false|no|off) printf '0\n' ;;
  esac
}

bit4=$(read_prefer_dark "$cfg/gtk-4.0/settings.ini")
bit3=$(read_prefer_dark "$cfg/gtk-3.0/settings.ini")

if ! cur=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null); then
  echo "theme-apply: failed to read color-scheme, using only the GTK prefer-dark bit" >&2
  cur=""
fi

mode=
case "${1:-}" in
  --force) case "${2:-}" in
             dark)  mode=dark ;;
             light) mode=light ;;
             *) echo "usage: $0 [--force dark|light] | [--mode]" >&2; exit 1 ;;
           esac ;;
esac
if [ -z "$mode" ]; then
  if [ -n "$bit4" ]; then
    [ "$bit4" = "1" ] && mode=dark || mode=light
  elif [ -n "$bit3" ]; then
    [ "$bit3" = "1" ] && mode=dark || mode=light
  elif [ "$cur" = "'prefer-light'" ]; then
    mode=light
  else
    mode=dark
  fi
fi

if [ "${1:-}" = "--mode" ]; then printf '%s\n' "$mode"; exit 0; fi

"$here/icon-follow.sh" "$mode"

if [ "$mode" = dark ]; then v=1; else v=0; fi
set_prefer_dark() {

  local ini="$1"
  if [ ! -f "$ini" ]; then
    if [ "$mode" = dark ]; then
      mkdir -p "${ini%/*}"
      printf '[Settings]\ngtk-application-prefer-dark-theme=1\n' > "$ini"
    fi
  elif grep -q '^gtk-application-prefer-dark-theme=' "$ini"; then
    sed -i "s/^gtk-application-prefer-dark-theme=.*/gtk-application-prefer-dark-theme=$v/" "$ini"
  elif grep -q '^\[Settings\]' "$ini"; then
    sed -i "/^\[Settings\]/a gtk-application-prefer-dark-theme=$v" "$ini"
  else
    printf '\n[Settings]\ngtk-application-prefer-dark-theme=%s\n' "$v" >> "$ini"
  fi
}
set_prefer_dark "$cfg/gtk-3.0/settings.ini"
set_prefer_dark "$cfg/gtk-4.0/settings.ini"

if [ -n "$bit4" ] || [ -n "$bit3" ]; then
  want="'prefer-dark'"; [ "$mode" = light ] && want="'prefer-light'"
  if [ "$cur" != "$want" ] && { [ "$cur" = "'prefer-dark'" ] || [ "$cur" = "'prefer-light'" ]; }; then

    echo "theme-apply: color-scheme contradicts prefer-dark bit ($cur vs bit=$mode), one-way aligning to $want" >&2
    gsettings set org.gnome.desktop.interface color-scheme "$want" 2>/dev/null \
      || echo "theme-apply: failed to write color-scheme=$want" >&2
  fi
fi

th=""
if ! th=$(gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null); then
  echo "theme-apply: failed to read gtk-theme, skipping GTK4 CSS swap" >&2
  exit 0
fi
th=${th#\'}; th=${th%\'}
case "$th" in
  ""|/*|*/*|*..*|.*) exit 0 ;;
esac
theme_dir=""
for d in "$HOME/.local/share/themes" /usr/share/themes; do
  [ -d "$d/$th" ] && theme_dir="$d/$th" && break
done
[ -n "$theme_dir" ] || exit 0

st="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell"
acc=$(bash "$here/theme-css.sh" "$th" 2>/dev/null \
  | sed -n 's/^theme_selected_bg_color=//p' | head -n 1)

thj=$(printf '%s' "$th" | tr -d '"\\')
if mkdir -p "$st" && tmp=$(mktemp "$st/theme-palette.XXXXXX"); then

  if printf '{"family":"%s","accent":"%s"}\n' "$thj" "$acc" >"$tmp"; then
    mv -f "$tmp" "$st/theme-palette.json"
  else
    rm -f "$tmp"
  fi
else
  echo "theme-apply: failed to write $st/theme-palette.json, readers will stay on the previous copy" >&2
fi

missing=""
[ -f "$theme_dir/gtk-4.0/gtk.css" ] || missing="gtk-4.0"
[ -f "$theme_dir/gtk-3.0/gtk.css" ] || missing="${missing:+$missing/}gtk-3.0"
[ -z "$missing" ] || echo "theme-apply: theme $th lacks the $missing parts, user CSS will stay on the previous copy" >&2

if [ -f "$theme_dir/gtk-4.0/gtk.css" ]; then

  dst="$cfg/gtk-4.0/gtk.css"
  mkdir -p "${dst%/*}"
  if [ "$mode" = dark ]; then
    variant='gtk-dark.css'
  else
    variant='gtk.css'
  fi
  [ -f "$theme_dir/gtk-4.0/$variant" ] || variant='gtk.css'

  if ! tmp=$(mktemp "${dst}.XXXXXX"); then
    echo "theme-apply: failed to create temp file, skipping GTK4 CSS swap" >&2
    exit 0
  fi
  if cp -- "$theme_dir/gtk-4.0/$variant" "$tmp"; then
    chmod 0644 "$tmp"
    mv -f "$tmp" "$dst"
  else
    rm -f "$tmp"
  fi
fi
