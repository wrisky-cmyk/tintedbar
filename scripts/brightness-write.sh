#!/bin/bash

kind=$1
if [ "$kind" = logind ]; then
  exec busctl call org.freedesktop.login1 /org/freedesktop/login1/session/self \
    org.freedesktop.login1.Session SetBrightness ssu backlight "$2" "$3"
fi
if [ "$kind" = ddc ]; then
  bus=${2:--1}
  if [ "$bus" -ge 0 ] 2>/dev/null; then
    exec ddcutil --bus "$bus" --sleep-multiplier 0.2 setvcp 10 "$3"
  fi
  exec ddcutil --sleep-multiplier 0.2 setvcp 10 "$3"
fi
echo "unknown kind: $kind" >&2
exit 1
