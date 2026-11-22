#!/bin/bash

bt=
while read -r k v; do
  if [ "$k" = btime ]; then bt=$v; break; fi
done < /proc/stat
IFS= read -r rel < /proc/sys/kernel/osrelease 2>/dev/null || rel=
printf 'RUNNING\t%s\nBTIME\t%s\n' "$rel" "$bt"
find /boot -maxdepth 1 -type f \
  \( -name 'vmlinuz*' -o -name 'vmlinux*' -o -name 'bzImage*' \
  -o -name 'Image*' -o -name 'zImage*' -o -name 'uImage*' -o -name 'kernel*.img' \) \
  -printf 'IMG\t%p\t%T@\n' 2>/dev/null
md=/usr/lib/modules/$rel
find "$md/updates" "$md/extramodules" "$md/extra" -type f -name '*.ko*' \
  -printf 'MOD\t%p\t%T@\n' 2>/dev/null
pid=
if [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
  IFS= read -r pid < "$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/hyprland.lock" \
    2>/dev/null || pid=
fi
if [ -z "$pid" ] && [ -n "$NIRI_SOCKET" ]; then
  s=${NIRI_SOCKET%.sock}; pid=${s##*.}; fi

if [ -z "$pid" ] && [ -n "$SWAYSOCK" ]; then
  s=${SWAYSOCK%.sock}; pid=${s##*.}; fi
printf 'COMPOSITOR\t%s\n' "$pid"
if [ -n "$pid" ] && [ -r "/proc/$pid/maps" ]; then

  awk '$0 ~ / \(deleted\)$/ { sub(/^([^ ]+ +)([^ ]+ +)([^ ]+ +)([^ ]+ +)([^ ]+ +)/, ""); sub(/ \(deleted\)$/, ""); if ($0 ~ /^\/usr\//) print "LIB\t" $0 }' \
    "/proc/$pid/maps"
fi
printf 'DONE\n'
