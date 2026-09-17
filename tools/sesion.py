"""Arranca el sistema y teclea varias ordenes como lo haria una persona.

   uso: sesion.py <img> <log> <tope_s> <t_primera_s> <orden> [orden...]
"""
import os, pty, select, sys, time

img, log = sys.argv[1], sys.argv[2]
tope = float(sys.argv[3])
t_ini = float(sys.argv[4])
ordenes = sys.argv[5:]

HOME = os.path.expanduser("~")
M = HOME + "/machpmax"
cmd = [M + "/opt/usr/bin/gxemul",
       "-c", "put w 0x800990e0, 0", "-c", "put w 0x80099144, 0",
       "-c", "put w 0x8004aae8, 0", "-c", "put w 0x800810fc, 0",
       "-e", "3max", "-d", img,
       M + "/dist/pmax_mach/special/mach.boot.MK83.STD+ANY"]

pid, fd = pty.fork()
if pid == 0:
    os.chdir(M)
    ferr = os.open("/dev/null", os.O_WRONLY)
    os.dup2(ferr, 2)
    os.execv(cmd[0], cmd)

# una tecla cada 200 ms, 4 s de respiro entre ordenes
cola = []
for o in ordenes:
    cola.extend([(c, 0.2) for c in o.encode()])
    cola.append((13, 4.0))

sal = bytearray()
t0 = time.time()
i = 0
prox = t0 + t_ini

while time.time() - t0 < tope:
    r, _, _ = select.select([fd], [], [], 0.1)
    if r:
        try:
            d = os.read(fd, 4096)
        except OSError:
            break
        if not d:
            break
        sal += d
    ahora = time.time()
    if i < len(cola) and ahora >= prox:
        tecla, pausa = cola[i]
        os.write(fd, bytes([tecla]))
        i += 1
        prox = ahora + pausa

open(log, "wb").write(bytes(sal))
try:
    os.kill(pid, 9)
except Exception:
    pass
print("salida %d bytes, %d/%d teclas" % (len(sal), i, len(cola)))
