#!/bin/bash

for d in /sys/class/backlight/*; do [ -d "$d" ] && { echo sysfs; exit 0; }; done
command -v ddcutil >/dev/null 2>&1 || exit 0

ddc='timeout 8 ddcutil'
bus=$($ddc detect 2>/dev/null | grep -m1 "I2C bus" | sed "s/.*i2c-//" | tr -d "[:space:]")
[ -n "$bus" ] && echo "ddc $bus" || echo ddc
