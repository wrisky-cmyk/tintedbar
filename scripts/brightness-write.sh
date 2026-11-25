#!/bin/bash

kind=$1
if [ "$kind" = logind ]; then

  command -v busctl >/dev/null 2>&1 || {
    echo "brightness-write: busctl not installed" >&2
    exit 127
  }
  exec busctl call org.freedesktop.login1 /org/freedesktop/login1/session/self \
    org.freedesktop.login1.Session SetBrightness ssu backlight "$2" "$3"
fi
if [ "$kind" = ddc ]; then

  command -v ddcutil >/dev/null 2>&1 || {
    echo "brightness-write: ddcutil not installed" >&2
    exit 127
  }
  bus=${2:--1}

  case "$bus" in
    ''|-1) : ;;
    *[!0-9]*)
      echo "brightness-write: refusing non-numeric bus number: $bus" >&2
      exit 2 ;;
  esac
  if [ "$bus" -ge 0 ] 2>/dev/null; then
    exec ddcutil --bus "$bus" --sleep-multiplier 0.2 setvcp 10 "$3"
  fi
  exec ddcutil --sleep-multiplier 0.2 setvcp 10 "$3"
fi
echo "unknown kind: $kind" >&2
exit 1
