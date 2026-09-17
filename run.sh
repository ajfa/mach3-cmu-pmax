#!/bin/sh
#
# CMU Mach 3.0 (MK83) sobre una DECstation 5000/200 emulada.
#
#   ./run.sh            construye lo que falte y abre una sesion interactiva
#   ./run.sh --check    verificacion automatica, sin ventana, sin interaccion
#   ./run.sh --rebuild  recompila el emulador desde cero
#
set -eu

cd "$(dirname "$0")"
AQUI=$(pwd)

case "$AQUI" in
*[[:space:]]*)
    echo "ERROR: la ruta de este paquete lleva un espacio:" >&2
    echo "  $AQUI" >&2
    echo "Muevelo a una ruta sin espacios y vuelve a intentarlo." >&2
    exit 1
    ;;
esac

GX="$AQUI/gxemul/gxemul-0.7.0/gxemul"
KERNEL="$AQUI/mach.boot.MK83.STD+ANY"
DISCO="$AQUI/mach3-pmax.img"

# Los tres primeros -c anulan la deteccion de cache del R3000, que GXemul ya
# no emula; el cuarto anula un bucle de retardo calibrado que a 600 millones
# de instrucciones por segundo no termina nunca.  El kernel ya esta cargado en
# memoria cuando estos -c se ejecutan.
#
# Van con set -- y no en una variable: llevan espacios, y una variable sin
# comillas se partiria en un argumento por palabra.
parches_cpu() {
    set -- -c "put w 0x800990e0, 0" \
           -c "put w 0x80099144, 0" \
           -c "put w 0x8004aae8, 0" \
           -c "put w 0x800810fc, 0" "$@"
    "$GX" "$@"
}

say()  { echo "==> $*"; }
die()  { echo "ERROR: $*" >&2; exit 1; }

MODO=interactivo
case "${1:-}" in
    --check)    MODO=check ;;
    --rebuild)  MODO=rebuild ;;
    "")         ;;
    *)          die "opcion desconocida: $1 (usa --check o --rebuild)" ;;
esac

# ---------------------------------------------------------------- dependencias
faltan=""
for t in cc make tar patch python3; do
    command -v "$t" >/dev/null 2>&1 || faltan="$faltan $t"
done

# X11 solo se necesita para compilar: el configure de GXemul la busca aunque
# aqui nunca se abra una ventana.
if [ ! -f /usr/include/X11/Xlib.h ]; then
    faltan="$faltan libx11-dev"
fi

if [ -n "$faltan" ] && [ ! -x "$GX" ]; then
    say "faltan:$faltan"
    puesto=no
    if command -v apt-get >/dev/null 2>&1; then
        if [ "$(id -u)" -eq 0 ]; then
            DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
                build-essential libx11-dev python3 >/dev/null 2>&1 && puesto=si
        elif sudo -n true 2>/dev/null; then
            # sudo -n y no sudo a secas: sin contrasena cacheada, sudo se
            # queda esperando para siempre y no se ve ni el prompt.
            DEBIAN_FRONTEND=noninteractive sudo -n apt-get install -y -qq \
                build-essential libx11-dev python3 >/dev/null 2>&1 && puesto=si
        fi
    fi
    if [ "$puesto" != si ]; then
        echo "" >&2
        echo "No pude instalarlas yo. Instalalas a mano y vuelve a lanzarme:" >&2
        echo "" >&2
        echo "    sudo apt-get install build-essential libx11-dev python3" >&2
        echo "" >&2
        exit 1
    fi
    say "dependencias instaladas"
fi

# ------------------------------------------------------------------- construir
if [ "$MODO" = rebuild ]; then
    say "borrando el emulador construido"
    rm -rf "$AQUI/gxemul/gxemul-0.7.0"
fi

if [ ! -x "$GX" ]; then
    say "construyendo GXemul 0.7.0 con el parche de Mach"
    rm -rf "$AQUI/gxemul/gxemul-0.7.0"
    mkdir -p "$AQUI/gxemul"
    tar xzf "$AQUI/gxemul/gxemul-0.7.0.tar.gz" -C "$AQUI/gxemul" \
        || die "no pude descomprimir el emulador"
    ( cd "$AQUI/gxemul/gxemul-0.7.0" \
      && patch -p1 --quiet < "$AQUI/gxemul/gxemul-mach3.patch" ) \
        || die "el parche no aplico"
    ( cd "$AQUI/gxemul/gxemul-0.7.0" \
      && CFLAGS="-O2 -fcommon -fgnu89-inline -w" ./configure >/dev/null \
      && make >/dev/null 2>&1 ) \
        || die "la compilacion del emulador fallo"
    [ -x "$GX" ] || die "el emulador no salio del build"
    say "emulador listo"
else
    say "emulador ya construido (usa --rebuild para rehacerlo)"
fi

[ -f "$KERNEL" ] || die "falta el kernel: $KERNEL"
[ -f "$DISCO" ]  || die "falta el disco: $DISCO"

# ------------------------------------------------------------------ verificar
if [ "$MODO" = check ]; then
    command -v python3 >/dev/null 2>&1 \
        || die "--check necesita python3 (el emulador exige un pty)"
    say "verificando: se teclea una orden y se comprueba su respuesta"
    python3 "$AQUI/tools/check.py" "$GX" "$KERNEL" "$DISCO"
    exit $?
fi

# ----------------------------------------------------------------- interactivo
cat <<'TXT'

  CMU Mach 3.0 MK83 + servidor POE 10.1.0, userland de Ultrix RISC 4.5.
  El arranque tarda alrededor de 40 segundos; el indicador del shell no se
  imprime, asi que cuando deje de salir texto teclea una orden y pulsa Enter.

  Pruebalas:   echo hola      ls /      pwd      date      cat /etc/setup

  Para salir:  Ctrl-C  y luego  quit

TXT

parches_cpu -e 3max -d "$DISCO" "$KERNEL"
