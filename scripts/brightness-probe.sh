#!/bin/bash

for d in /sys/class/backlight/*; do [ -d "$d" ] && { echo sysfs; exit 0; }; done
command -v ddcutil >/dev/null 2>&1 || exit 0

detect_out=$(timeout 8 ddcutil detect 2>/dev/null)
detect_rc=$?
if [ "$detect_rc" -ne 0 ]; then

  echo "brightness-probe: ddcutil detect failed (rc=$detect_rc), falling back to bus 0 scan" >&2
  echo ddc
  exit 0
fi

bus=$(printf '%s\n' "$detect_out" | grep -m1 'I2C bus' | sed 's/.*i2c-//' | tr -d '[:space:]')
case "$bus" in
  ''|*[!0-9]*)
    echo "brightness-probe: no usable i2c bus number in ddcutil detect output" >&2
    echo ddc ;;
  *)
    echo "ddc $bus" ;;
esac
