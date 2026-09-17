#!/bin/bash
# Boots with an X11 window and captures the emulated screen. The graphical
# console shows what the serial line truncates.
#   usage: screenshot.sh <image> <seconds> <png>
M=$HOME/machpmax
IMG=$1
WAIT=${2:-70}
PNG=${3:-/tmp/pantalla.png}

cd "$M"
"$M/opt/usr/bin/gxemul" -X \
    -c "put w 0x800990e0, 0" -c "put w 0x80099144, 0" \
    -c "put w 0x8004aae8, 0" -c "put w 0x800810fc, 0" \
    -e 3max -d "$IMG" \
    "$M/dist/pmax_mach/special/mach.boot.MK83.STD+ANY" \
    > /tmp/mirar.out 2> /tmp/mirar.err < /dev/null &
GXPID=$!

sleep "$WAIT"

WIN=$(xdotool search --name "GXemul" 2>/dev/null | tail -1)
if [ -z "$WIN" ]; then
    echo "no GXemul window found"
    xdotool search --name "." getwindowname %@ 2>/dev/null | head -20
else
    import -window "$WIN" "$PNG" 2>/dev/null && echo "captured to $PNG"
fi

kill -9 $GXPID 2>/dev/null
wait $GXPID 2>/dev/null
ls -la "$PNG" 2>/dev/null
