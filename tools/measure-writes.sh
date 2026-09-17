#!/bin/bash
# Measures the two claims the README makes about writes:
#   1. a read only session leaves the image untouched
#   2. a file written inside a session does not survive it
set -u
M=$HOME/machpmax
P=$HOME/pack/mach3-pmax
cd "$M"

cp "$P/mach3-pmax.img" /tmp/prueba.img
A=$(md5sum /tmp/prueba.img | cut -d" " -f1)
echo "md5 before: $A"

echo "--- session 1: read only (ls, pwd) ---"
timeout 170 python3 session.py /tmp/prueba.img /tmp/ap1.log 150 45 "ls /" "pwd" >/dev/null 2>&1

B=$(md5sum /tmp/prueba.img | cut -d" " -f1)
echo "md5 after:  $B"
if [ "$A" = "$B" ]; then
    echo "RESULT 1: the image does NOT change in a read only session"
else
    echo "RESULT 1: the image DOES change even when only read"
fi

echo "--- session 2: write a file and kill the emulator ---"
timeout 170 python3 session.py /tmp/prueba.img /tmp/ap2.log 150 45 \
    "echo marcaDePrueba > /testigo" "ls /" >/dev/null 2>&1
echo "  what came back while writing:"
tr -d "\r" < /tmp/ap2.log | sed -n "/init_path/,\$p" | tail -16 | sed "s|^|    |"

echo "--- session 3: fresh boot, read the file back ---"
timeout 170 python3 session.py /tmp/prueba.img /tmp/ap3.log 150 45 \
    "cat /testigo" "ls /" >/dev/null 2>&1
echo "  what came back while reading:"
tr -d "\r" < /tmp/ap3.log | sed -n "/init_path/,\$p" | tail -20 | sed "s|^|    |"
