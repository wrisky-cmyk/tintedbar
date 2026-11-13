#!/usr/bin/env bash

set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "${1:-}" in
  --set) case "${2:-}" in
           dark)  m=dark ;;
           light) m=light ;;
           *) echo "usage: $0 [--set dark|light]" >&2; exit 1 ;;
         esac ;;
  "")

         old_mode=$("$here/theme-apply.sh" --mode 2>/dev/null || true)
         if [ "$old_mode" = "dark" ]; then
           m=light
         else
           m=dark
         fi ;;
  *)     echo "usage: $0 [--set dark|light]" >&2; exit 1 ;;
esac
if [ "$m" = "dark" ]; then next=prefer-dark; else next=prefer-light; fi

[ -n "${old_mode:-}" ] || old_mode=$("$here/theme-apply.sh" --mode 2>/dev/null || true)
"$here/theme-apply.sh" --force "$m" || exit $?

if ! gsettings set org.gnome.desktop.interface color-scheme "$next" 2>/dev/null; then
  echo "theme-toggle: failed to write color-scheme=$next" >&2

  if [ -n "${old_mode:-}" ] && [ "$old_mode" != "$m" ]; then
    "$here/theme-apply.sh" --force "$old_mode" >/dev/null 2>&1 \
      || echo "theme-toggle: rollback to $old_mode failed" >&2
  fi
  exit 1
fi
