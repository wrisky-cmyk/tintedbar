#!/bin/bash

umask 077
dest=$1
dir=${dest%/*}
[ "$dir" = "$dest" ] && dir=.
mkdir -p "$dir" || exit 1
t=$(mktemp "$dest.XXXXXX") || exit 1

trap 'rm -f "$t"' EXIT
cat > "$t" && mv -f "$t" "$dest" || { rm -f "$t"; exit 1; }
trap - EXIT
