#!/bin/bash
# Builds the Mach/POE disk image: FFS v1 little endian, a DEC label, and
# directories converted from 4.4 to 4.3.
#   usage: build-disk.sh <image> [program init should exec]
set -e
M=$HOME/machpmax
IMG=${1:-mach3-pmax.img}
TARGET=${2:-/bin/sh}

cd "$M/build-init"
python3 - "$TARGET" <<'PYEOF'
import re, sys
target = sys.argv[1]
s = open("init.s").read()
s = re.sub(r'shpath:\t*\.asciiz\t"[^"]*"',
           'shpath:\t\t.asciiz\t"%s"' % target, s)
open("init.s", "w").write(s)
PYEOF
grep -n "shpath:" init.s
"$M/cross/bin/mips-dec-ultrix-as" -o init.o init.s
"$M/cross/bin/mips-dec-ultrix-ld" -o poe_init -Ttext 0x00400140 -Tdata 0x10000000 init.o

cd "$M"
cp build-init/poe_init  root2/mach_servers/poe_init
cp build-poe/poe        root2/mach_servers/startup
./mkfs/usr/sbin/makefs -t ffs -B le -o version=1 -s 96m -F devspec.mtree "$IMG" root2/ >/dev/null

python3 - "$IMG" <<'PYEOF'
import struct, sys
img = sys.argv[1]
f = open(img, "r+b")
t = (96 * 1024 * 1024) // 512
f.seek(2 * 8192 - 72)
f.write(struct.pack("<ii", 0x032957, 1) + struct.pack("<II", t, 0) + b"\0" * 56)
f.close()
PYEOF

python3 dir44to43.py "$IMG" >/dev/null
ls -la "$IMG"
echo "image $IMG ready (init execs $TARGET)"
