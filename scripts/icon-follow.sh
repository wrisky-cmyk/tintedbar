#!/usr/bin/env bash

set -uo pipefail
mode=${1:-}
case "$mode" in dark|light) ;; *) echo "用法: $0 dark|light" >&2; exit 1 ;; esac

key=org.gnome.desktop.interface

if ! cur=$(gsettings get $key icon-theme 2>/dev/null); then
  echo "icon-follow: 读 icon-theme 失败, 跳过" >&2
  exit 0
fi
cur=${cur#\'}; cur=${cur%\'}

case "$cur" in
  ""|/*|*/*|*..*|.*) exit 0 ;;
esac

case "$cur" in
  *-[Dd]ark)  base=${cur%-[Dd]ark};  curmode=dark ;;
  *-[Ll]ight) base=${cur%-[Ll]ight}; curmode=light ;;
  *)          base=$cur;             curmode=light ;;
esac

if [ "$mode" = dark ]; then
  cands=("$base-Dark" "$base-dark")
else
  cands=("$base-Light" "$base-light")
  [ "$curmode" != light ] && cands+=("$base")
fi

target=""
for d in "$HOME/.local/share/icons" /usr/share/icons; do
  [ -d "$d" ] || continue
  for c in "${cands[@]}"; do
    if [ -d "$d/$c" ]; then target=$c; break 2; fi
  done
done

[ -n "$target" ] || exit 0
[ "$target" = "$cur" ] && exit 0

if ! gsettings set $key icon-theme "$target" 2>/dev/null; then
  echo "icon-follow: gsettings set icon-theme=$target 失败" >&2
  exit 1
fi

esc=${target//\\/\\\\}
esc=${esc//&/\\&}
esc=${esc//|/\\|}

cfg="${XDG_CONFIG_HOME:-$HOME/.config}"
set_icon_theme() {
  local ini="$1"
  if [ ! -f "$ini" ]; then
    if [ "$mode" = dark ]; then
      mkdir -p "${ini%/*}"
      printf '[Settings]\ngtk-icon-theme-name=%s\n' "$target" > "$ini"
    fi
  elif grep -q '^gtk-icon-theme-name=' "$ini"; then
    sed -i "s|^gtk-icon-theme-name=.*|gtk-icon-theme-name=$esc|" "$ini"
  elif grep -q '^\[Settings\]' "$ini"; then
    sed -i "/^\[Settings\]/a gtk-icon-theme-name=$esc" "$ini"
  else
    printf '\n[Settings]\ngtk-icon-theme-name=%s\n' "$target" >> "$ini"
  fi
}
set_icon_theme "$cfg/gtk-3.0/settings.ini"
set_icon_theme "$cfg/gtk-4.0/settings.ini"
echo "icon-theme: $cur -> $target"
