"""Checks the package: boots the system, types commands the way a person would
and verifies that the guest really runs them.

It is not enough for the emulator to talk: the output has to be something only
a program running inside the system could have produced.

   uso: check.py <gxemul> <kernel> <disco>
"""
import os
import pty
import re
import select
import sys
import time

GX, KERNEL, DISCO = sys.argv[1], sys.argv[2], sys.argv[3]

PARCHES = [
    "-c", "put w 0x800990e0, 0",
    "-c", "put w 0x80099144, 0",
    "-c", "put w 0x8004aae8, 0",
    "-c", "put w 0x800810fc, 0",
]

TOPE = 210.0          # generous: a virtual machine is slower than this one
ESPERA_ARRANQUE = 45.0
RITMO = 0.2           # one key every 200 ms, the speed a person types at
PAUSA = 6.0           # entre ordenes

ORDENES = ["echo abracadabra", "ls /"]


def arrancar():
    pid, fd = pty.fork()
    if pid == 0:
        os.chdir(os.path.dirname(os.path.abspath(GX)) or ".")
        os.dup2(os.open(os.devnull, os.O_WRONLY), 2)
        os.execv(GX, [GX] + PARCHES + ["-e", "3max", "-d", DISCO, KERNEL])
    return pid, fd


def sesion():
    pid, fd = arrancar()
    cola = []
    for orden in ORDENES:
        cola.extend([(c, RITMO) for c in orden.encode()])
        cola.append((13, PAUSA))

    salida = bytearray()
    t0 = time.time()
    i = 0
    prox = t0 + ESPERA_ARRANQUE

    while time.time() - t0 < TOPE:
        listos, _, _ = select.select([fd], [], [], 0.1)
        if listos:
            try:
                trozo = os.read(fd, 4096)
            except OSError:
                break
            if not trozo:
                break
            salida += trozo
        ahora = time.time()
        if i < len(cola) and ahora >= prox:
            tecla, pausa = cola[i]
            os.write(fd, bytes([tecla]))
            i += 1
            prox = ahora + pausa
        if i >= len(cola) and ahora - t0 > ESPERA_ARRANQUE + 40:
            break

    try:
        os.kill(pid, 9)
        os.waitpid(pid, 0)
    except Exception:
        pass
    return bytes(salida).replace(b"\r", b"").decode("latin-1")


def main():
    texto = sesion()

    fallos = []

    if "POE 10.1.0" not in texto:
        fallos.append("the POE server never started")

    # The tty echoes what is typed, so the word shows once from the echo.  A
    # second occurrence can only come from /bin/echo actually running.
    veces = len(re.findall(r"abracadabra", texto))
    if veces < 2:
        fallos.append(
            "/bin/echo produced no output (the word appears %d time(s), "
            "2 are needed: the tty echo and the program's)" % veces)

    if "mach_servers" not in texto:
        fallos.append("/bin/ls did not list the root disk")

    print("-" * 68)
    if fallos:
        print("VERIFICACION EN ROJO")
        for f in fallos:
            print("  - " + f)
        print("-" * 68)
        print("Last lines from the console:")
        for linea in texto.strip().split("\n")[-12:]:
            print("  | " + linea)
        return 1

    print("VERIFICACION EN VERDE")
    print("  - the Mach 3.0 microkernel boots and loads the POE 10.1.0 server")
    print("  - the shell takes commands typed at the serial console")
    print("  - /bin/echo and /bin/ls run and return their output")
    print("-" * 68)
    return 0


if __name__ == "__main__":
    sys.exit(main())
