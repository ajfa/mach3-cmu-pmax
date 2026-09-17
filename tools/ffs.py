#!/usr/bin/env python3
"""Lector mínimo de FFS v1 little-endian: listar y extraer."""
import struct, sys, os

class FFS:
    def __init__(self, path, base=0):
        self.f = open(path, "rb"); self.base = base
        self.f.seek(base + 8192); sb = self.f.read(2048)
        u = lambda o: struct.unpack_from("<I", sb, o)[0]
        if u(1372) != 0x11954: raise SystemExit("no hay FFS v1 en ese offset")
        (self.iblkno, self.ncg, self.bsize, self.fsize, self.frag,
         self.inopb, self.ipg, self.fpg) = (u(16), u(44), u(48), u(52), u(56),
                                            u(120), u(184), u(188))
        self.cgoffset, self.cgmask = u(24), u(28)
    def dinode(self, ino):
        cg = ino // self.ipg
        cgstart = self.fpg*cg + self.cgoffset*(cg & ((~self.cgmask) & 0xffffffff))
        blk = cgstart + self.iblkno + ((ino % self.ipg)//self.inopb)*self.frag
        self.f.seek(self.base + blk*self.fsize + (ino % self.inopb)*128)
        return self.f.read(128)
    def datos(self, ino):
        di = self.dinode(ino)
        size, = struct.unpack_from("<I", di, 8)
        db = struct.unpack_from("<12I", di, 40)
        ib = struct.unpack_from("<3I", di, 88)
        out = bytearray(); falta = size
        bloques = list(db)
        if ib[0]:                                   # un nivel de indirección
            self.f.seek(self.base + ib[0]*self.fsize)
            raw = self.f.read(self.bsize); bloques += list(struct.unpack("<%dI" % (len(raw)//4), raw))
        for b in bloques:
            if falta <= 0: break
            if b == 0: out += b"\0"*min(self.bsize, falta); falta -= min(self.bsize, falta); continue
            n = min(self.bsize, falta)
            self.f.seek(self.base + b*self.fsize); out += self.f.read(n); falta -= n
        return bytes(out), size
    def modo(self, ino):
        return struct.unpack_from("<H", self.dinode(ino), 0)[0]
    def listar(self, ino):
        d,_ = self.datos(ino); o = 0; res = []
        while o + 8 <= len(d):
            i, reclen = struct.unpack_from("<IH", d, o)
            if reclen < 12: break
            namlen = d[o+7] if d[o+6] else d[o+6] | (d[o+7] << 8)
            if d[o+6] and d[o+7] == 0: namlen = d[o+6]
            namlen = max(d[o+6], d[o+7])            # vale para 4.3 y 4.4
            nombre = d[o+8:o+8+namlen].decode("latin1")
            if i: res.append((nombre, i))
            o += reclen
        return res
    def buscar(self, ruta):
        ino = 2
        for parte in ruta.strip("/").split("/"):
            if not parte: continue
            hijos = dict(self.listar(ino))
            if parte not in hijos: return None
            ino = hijos[parte]
        return ino

if __name__ == "__main__":
    fs = FFS(sys.argv[1])
    ruta = sys.argv[2] if len(sys.argv) > 2 else "/"
    ino = fs.buscar(ruta)
    if ino is None: raise SystemExit("no existe: " + ruta)
    if (fs.modo(ino) & 0xF000) == 0x4000:
        for n,i in sorted(fs.listar(ino)):
            m = fs.modo(i); t = "d" if (m & 0xF000)==0x4000 else ("l" if (m&0xF000)==0xa000 else "-")
            _,sz = fs.datos(i) if t == "-" else (b"",0)
            print("%s %8d  %s" % (t, sz, n))
    else:
        d,sz = fs.datos(ino)
        if len(sys.argv) > 3: open(sys.argv[3],"wb").write(d); print("extraido", sz, "bytes")
        else: print("fichero de", sz, "bytes")
