"""Convierte las entradas de directorio de una imagen FFS v1 del formato 4.4
(d_type + d_namlen de 8 bits) al de 4.3 (d_namlen de 16 bits), que es el que
sabe leer el bootstrap de Mach 3.0."""
import struct, sys

img = sys.argv[1]
f = open(img, "r+b")
f.seek(8192); sb = f.read(2048)
u32 = lambda o: struct.unpack_from("<I", sb, o)[0]
iblkno, ncg, bsize, fsize, frag, inopb, ipg, fpg = (
    u32(16), u32(44), u32(48), u32(52), u32(56), u32(120), u32(184), u32(188))
assert u32(1372) == 0x11954, "no es un FFS v1"

def inode_offset(ino):
    cg = ino // ipg
    cgstart = fpg * cg
    blk = cgstart + iblkno + ((ino % ipg) // inopb) * frag
    return blk * fsize + (ino % inopb) * 128

dirs = arreglos = 0
for ino in range(2, ncg * ipg):
    f.seek(inode_offset(ino)); di = f.read(128)
    mode, = struct.unpack_from("<H", di, 0)
    if (mode & 0xF000) != 0x4000:
        continue
    dirs += 1
    size, = struct.unpack_from("<I", di, 8)
    db = struct.unpack_from("<12I", di, 40)
    restante = size
    for b in db:
        if b == 0 or restante <= 0:
            break
        n = min(bsize, restante)
        base = b * fsize
        f.seek(base); blk = bytearray(f.read(n))
        o = 0
        while o + 8 <= len(blk):
            d_ino, reclen = struct.unpack_from("<IH", blk, o)
            if reclen < 12 or o + reclen > len(blk):
                break
            tipo, namlen = blk[o+6], blk[o+7]
            if d_ino != 0 and tipo != 0:
                blk[o+6], blk[o+7] = namlen, 0
                arreglos += 1
            o += reclen
        f.seek(base); f.write(blk)
        restante -= n
f.close()
print("directorios: %d   entradas convertidas: %d" % (dirs, arreglos))
