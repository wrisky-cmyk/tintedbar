#!/bin/bash

t="$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null \
  | sed -n "s/^'//;s/'$//p")"

[ -n "$t" ] || t="$(sed -n 's/^gtk-icon-theme-name=//p' \
  "${XDG_CONFIG_HOME:-$HOME/.config}/gtk-3.0/settings.ini" 2>/dev/null)"
[ -n "$t" ] || t=hicolor

case "$t" in
  ""|/*|*/*|*..*|.*) t=hicolor ;;
esac

CHAIN=""
for base in "$HOME/.local/share/icons" /usr/share/icons; do
  [ -f "$base/$t/index.theme" ] && CHAIN="$CHAIN $(sed -n 's/^Inherits=//p' "$base/$t/index.theme" | tr ',' ' ')"
done

ICON_CHAIN=""
for _w in $CHAIN hicolor Adwaita default; do
  [ "$_w" = "$t" ] && continue
  _skip=0
  for _seen in $ICON_CHAIN; do
    [ "$_seen" = "$_w" ] && { _skip=1; break; }
  done
  [ "$_skip" = 1 ] && continue
  ICON_CHAIN="$ICON_CHAIN $_w"
done
unset _w _seen _skip
try_name() {
  n="$1"

  for th in "$t" $ICON_CHAIN; do
    for base in "$HOME/.local/share/icons" /usr/share/icons; do
      [ -d "$base/$th" ] || continue

      for c in apps actions status devices places categories mimetypes panel; do
        for f in "$base/$th"/*/"$c"/"$n".svg "$base/$th"/*/"$c"/"$n".png; do
          [ -f "$f" ] && { printf '%s\n' "$f"; exit 0; }
        done
      done
      for c in apps actions status devices places categories emblems; do
        for f in "$base/$th"/*/symbolic/"$c"/"$n".svg "$base/$th"/*/symbolic/"$c"/"$n".png; do
          [ -f "$f" ] && { printf '%s\n' "$f"; exit 0; }
        done
      done
      for c in apps actions status devices places categories emblems mimetypes; do
        f="$base/$th/symbolic/$c/$n.svg"
        [ -f "$f" ] && { printf '%s\n' "$f"; exit 0; }
      done
    done
  done
  for p in /usr/share/pixmaps/$n.svg /usr/share/pixmaps/$n.png /usr/share/pixmaps/$n.xpm; do
    [ -f "$p" ] && { printf '%s\n' "$p"; exit 0; }
  done
  return 1
}
probe() {
  for n in "$@"; do
    try_name "$n" && return 0
  done
  return 1
}
