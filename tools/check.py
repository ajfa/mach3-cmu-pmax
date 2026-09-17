"""Verificacion del pack: arranca el sistema, teclea ordenes como una persona
y comprueba que el huesped las ejecuta de verdad.

No basta con que el emulador hable: hay que ver salida que solo pueda haber
producido un programa corriendo dentro del sistema.

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

TOPE = 210.0          # margen amplio: la VM del usuario es mas lenta que WSL
ESPERA_ARRANQUE = 45.0
RITMO = 0.2           # una tecla cada 200 ms, como teclea una persona
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
        fallos.append("el servidor POE no llego a arrancar")

    # El tty hace eco de lo tecleado, asi que la palabra aparece una vez por el
    # eco.  Una segunda aparicion solo puede venir de /bin/echo ejecutandose.
    veces = len(re.findall(r"abracadabra", texto))
    if veces < 2:
        fallos.append(
            "/bin/echo no produjo salida (la palabra aparece %d vez/veces, "
            "hacen falta 2: el eco del tty y la del programa)" % veces)

    if "mach_servers" not in texto:
        fallos.append("/bin/ls no listo el disco raiz")

    print("-" * 68)
    if fallos:
        print("VERIFICACION EN ROJO")
        for f in fallos:
            print("  - " + f)
        print("-" * 68)
        print("Ultimas lineas de la consola:")
        for linea in texto.strip().split("\n")[-12:]:
            print("  | " + linea)
        return 1

    print("VERIFICACION EN VERDE")
    print("  - el microkernel Mach 3.0 arranca y carga el servidor POE 10.1.0")
    print("  - el shell acepta ordenes tecleadas por la consola serie")
    print("  - /bin/echo y /bin/ls se ejecutan y devuelven su salida")
    print("-" * 68)
    return 0


if __name__ == "__main__":
    sys.exit(main())
