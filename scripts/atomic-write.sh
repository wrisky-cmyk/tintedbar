#!/bin/bash

umask 077

[ "$#" -ge 1 ] && [ -n "$1" ] || {
  echo "usage: atomic-write.sh <dest-path>  (content on stdin)" >&2
  exit 2
}
dest=$1
if [ -d "$dest" ]; then
  echo "atomic-write: refusing to write, target is an existing directory: $dest" >&2
  exit 2
fi
dir=${dest%/*}
[ "$dir" = "$dest" ] && dir=.
mkdir -p "$dir" || exit 1
t=$(mktemp "$dest.XXXXXX") || exit 1

trap 'rm -f "$t"' EXIT
cat > "$t" && mv -f "$t" "$dest" || { rm -f "$t"; exit 1; }
trap - EXIT
