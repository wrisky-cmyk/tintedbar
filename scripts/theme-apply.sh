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
force=0
case "${1:-}" in
  --force) force=1; case "${2:-}" in
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

if command -v flock >/dev/null 2>&1; then
  lock_dir=${XDG_RUNTIME_DIR:-$HOME/.cache/tintedbar}
  mkdir -p "$lock_dir" 2>/dev/null || true
  lock_file="$lock_dir/tintedbar-theme-apply.${UID:-0}.lock"
  exec 9>"$lock_file" || { echo "theme-apply: cannot open lock $lock_file" >&2; exit 1; }
  if ! flock -w 10 9; then

    echo "theme-apply: another instance is still running; skipped (retryable)" >&2
    exit 75
  fi
fi

icon_rc=0
"$here/icon-follow.sh" "$mode" || icon_rc=$?
if [ "$icon_rc" -ne 0 ]; then
  echo "theme-apply: icon-follow failed (rc=$icon_rc); palette/GTK CSS were applied, icon theme left as-is" >&2
fi

if [ "$mode" = dark ]; then v=1; else v=0; fi
set_prefer_dark() {

  local ini="$1"
  if [ ! -f "$ini" ]; then
    if [ "$mode" = dark ]; then
      mkdir -p "${ini%/*}"
      printf '[Settings]\ngtk-application-prefer-dark-theme=1\n' > "$ini"
    fi
  elif grep -q '^[[:space:]]*gtk-application-prefer-dark-theme=' "$ini"; then

    sed -i "s/^\([[:space:]]*\)gtk-application-prefer-dark-theme=.*/\1gtk-application-prefer-dark-theme=$v/" "$ini"
  elif grep -q '^\[Settings\]' "$ini"; then
    sed -i "/^\[Settings\]/a gtk-application-prefer-dark-theme=$v" "$ini"
  else
    printf '\n[Settings]\ngtk-application-prefer-dark-theme=%s\n' "$v" >> "$ini"
  fi
}
set_prefer_dark "$cfg/gtk-3.0/settings.ini"
set_prefer_dark "$cfg/gtk-4.0/settings.ini"

if [ -n "$bit4" ] || [ -n "$bit3" ] || [ "$force" = 1 ]; then
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
  ""|/*|*/*|*..*|.*)

    echo "theme-apply: refusing unsafe theme name: $th" >&2
    exit 0 ;;
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

  if command -v jq >/dev/null 2>&1; then
    jq -n --arg family "$thj" --arg accent "$acc" \
      '{family:$family,accent:$accent}' >"$tmp"
  else

    accj=$(printf '%s' "$acc" | tr -d '"\\')
    printf '{"family":"%s","accent":"%s"}\n' "$thj" "$accj" >"$tmp"
  fi
  if [ -s "$tmp" ]; then
    mv -f "$tmp" "$st/theme-palette.json" || rm -f "$tmp"
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
    mv -f "$tmp" "$dst" || rm -f "$tmp"
  else
    rm -f "$tmp"
  fi
fi

if [ -f "$theme_dir/gtk-3.0/gtk.css" ]; then
  dst="$cfg/gtk-3.0/gtk.css"
  mkdir -p "${dst%/*}"

  ours=1
  if [ -f "$dst" ]; then
    ours=
    first=
    IFS= read -r first <"$dst" || true
    case "$first" in "/* quickshell theme-apply: generated"*) ours=1 ;; esac
    if [ -z "$ours" ]; then
      cmp -s -- "$dst" "$theme_dir/gtk-3.0/gtk.css" && ours=1
    fi
    if [ -z "$ours" ]; then
      cmp -s -- "$dst" "$theme_dir/gtk-3.0/gtk-dark.css" && ours=1
    fi
    if [ -z "$ours" ]; then

      if [ ! -f "$dst.user-backup" ]; then
        cp -p -- "$dst" "$dst.user-backup" 2>/dev/null || true
      fi
      echo "theme-apply: $dst is a user override, leaving it untouched (backup: $dst.user-backup)" >&2
      ours=0
    fi
  fi
  [ "$ours" = "1" ] || dst=
fi
if [ -n "${dst:-}" ]; then
  if [ "$mode" = dark ]; then
    variant='gtk-dark.css'
  else
    variant='gtk.css'
  fi
  [ -f "$theme_dir/gtk-3.0/$variant" ] || variant='gtk.css'
  if ! tmp=$(mktemp "${dst}.XXXXXX"); then
    echo "theme-apply: failed to create temp file, skipping GTK3 CSS swap" >&2
    exit 0
  fi

  if {
    printf '/* quickshell theme-apply: generated from %s/%s, do not edit */\n' \
      "$theme_dir/gtk-3.0" "$variant"
    cat -- "$theme_dir/gtk-3.0/$variant"
  } >"$tmp"; then
    chmod 0644 "$tmp"
    mv -f "$tmp" "$dst" || rm -f "$tmp"
  else
    rm -f "$tmp"
  fi
fi

[ "$icon_rc" -eq 0 ] || exit 76
exit 0
