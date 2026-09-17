import os, pty, select, sys, time
img = sys.argv[1]; log = sys.argv[2]; tope = float(sys.argv[3])
HOME = os.path.expanduser('~')
cmd = [HOME+'/machpmax/opt/usr/bin/gxemul',
       '-c','put w 0x800990e0, 0', '-c','put w 0x80099144, 0',
       '-c','put w 0x8004aae8, 0', '-c','put w 0x800810fc, 0',
       '-e','3max','-d',img,
       HOME+'/machpmax/dist/pmax_mach/special/mach.boot.MK83.STD+ANY']
pid, fd = pty.fork()
if pid == 0:
    os.chdir(HOME+'/machpmax'); os.execv(cmd[0], cmd)
sal = bytearray(); t0 = time.time(); ultimo_envio = 0
while time.time() - t0 < tope:
    r,_,_ = select.select([fd],[],[],0.3)
    if r:
        try: d = os.read(fd, 4096)
        except OSError: break
        if not d: break
        sal += d
    if time.time() - ultimo_envio > 1.0:
        os.write(fd, b'\r')          # one key a second, from the start
        ultimo_envio = time.time()
open(log,'wb').write(bytes(sal))
try: os.kill(pid,9)
except Exception: pass
print('capturado', len(sal))
