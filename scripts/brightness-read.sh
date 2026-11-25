#!/bin/bash

mode=$1
if [ "$mode" = sysfs ]; then

  d=""
  for cand in /sys/class/backlight/*; do
    [ -d "$cand" ] || continue
    d=$cand
    break
  done
  [ -n "$d" ] || exit 1
  echo "${d##*/}"
  cat "$d/brightness" "$d/max_brightness" || exit 1
  exit 0
fi
bus=${2:--1}

command -v ddcutil >/dev/null 2>&1 || {
  echo "brightness-read: ddcutil not installed" >&2
  exit 127
}

case "$bus" in
  ''|-1) : ;;
  *[!0-9]*)
    echo "brightness-read: refusing non-numeric bus number: $bus" >&2
    exit 2 ;;
esac
if [ "$bus" -ge 0 ] 2>/dev/null; then
  exec ddcutil --bus "$bus" --sleep-multiplier 0.2 getvcp 10 --brief
fi
exec ddcutil --sleep-multiplier 0.2 getvcp 10 --brief
