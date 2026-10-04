#!/bin/sh
set -eu

key=$1
name=$2
source=$3
executable=$4
shift 4
if [ "$#" -eq 0 ]; then
    exec "$executable"
fi
basename=${source##*/}
for filter do
    case "$filter" in
        "$key"|"$name"|"$source"|"$basename"|"${basename%.zig}")
            exec "$executable"
            ;;
    esac
done
