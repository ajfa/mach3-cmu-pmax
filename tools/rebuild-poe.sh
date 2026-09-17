#!/bin/bash
# Recompiles the POE sources given on the command line and relinks the server.
set -e
M=$HOME/machpmax
B=$M/build-poe
SRC=$M/poe/poe/poe
D=$M/dist/pmax_mach/lib

cd "$B"
FLAGS=$(cat incflags)

for f in "$@"; do
    base=$(basename "$f" .c)
    src="$SRC/$f"
    [ -f "$src" ] || src="$B/$f"
    echo "compiling $base"
    "$M/cross/bin/machcc" -c $FLAGS "$src" -o "$base.o" 2> "$base.err" || {
        echo "FAILED on $base:"; tail -25 "$base.err"; exit 1; }
done

OBJS=$(ls *.o | grep -vE '^(crt0|minit)\.o$' | tr '\n' ' ')
echo "linking poe with $(echo $OBJS | wc -w) objects"
"$M/cross/bin/mips-dec-ultrix-ld" -o poe "$D/crt0.o" $OBJS \
    "$D/libthreads.a" "$D/libmach_sa.a"
ls -la poe
