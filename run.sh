#!/bin/sh
#
# CMU Mach 3.0 (MK83) on an emulated DECstation 5000/200.
#
#   ./run.sh            builds whatever is missing and opens a session
#   ./run.sh --check    automated check, no window, no interaction
#   ./run.sh --rebuild  rebuilds the emulator from scratch
#
set -eu

cd "$(dirname "$0")"
AQUI=$(pwd)

case "$AQUI" in
*[[:space:]]*)
    echo "ERROR: the path to this package contains a space:" >&2
    echo "  $AQUI" >&2
    echo "Move it somewhere without spaces and try again." >&2
    exit 1
    ;;
esac

GX="$AQUI/gxemul/gxemul-0.7.0/gxemul"
KERNEL="$AQUI/mach.boot.MK83.STD+ANY"
DISCO="$AQUI/mach3-pmax.img"

# The first three -c cancel the R3000 cache detection, which GXemul no longer
# emulates; the fourth cancels a calibrated delay loop that never ends at six
# hundred million instructions a second.  The kernel is already in memory at
# memoria cuando estos -c se ejecutan.
#
# They go through set -- rather than a variable: they contain spaces, and an
# unquoted variable would split into one argument per word.
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

# X11 is only needed to build: GXemul's configure looks for it even though no
# window is ever opened here.
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
            # it waits forever and not even the prompt shows.
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
    say "removing the built emulator"
    rm -rf "$AQUI/gxemul/gxemul-0.7.0"
fi

if [ ! -x "$GX" ]; then
    say "building GXemul 0.7.0 with the Mach patch"
    rm -rf "$AQUI/gxemul/gxemul-0.7.0"
    mkdir -p "$AQUI/gxemul"
    tar xzf "$AQUI/gxemul/gxemul-0.7.0.tar.gz" -C "$AQUI/gxemul" \
        || die "could not unpack the emulator"
    ( cd "$AQUI/gxemul/gxemul-0.7.0" \
      && patch -p1 --quiet < "$AQUI/gxemul/gxemul-mach3.patch" ) \
        || die "the patch did not apply"
    ( cd "$AQUI/gxemul/gxemul-0.7.0" \
      && CFLAGS="-O2 -fcommon -fgnu89-inline -w" ./configure >/dev/null \
      && make >/dev/null 2>&1 ) \
        || die "the emulator failed to build"
    [ -x "$GX" ] || die "the build produced no emulator"
    say "emulador listo"
else
    say "emulator already built (use --rebuild to redo it)"
fi

[ -f "$KERNEL" ] || die "missing kernel: $KERNEL"
[ -f "$DISCO" ]  || die "missing disk: $DISCO"

# ------------------------------------------------------------------ verificar
if [ "$MODO" = check ]; then
    command -v python3 >/dev/null 2>&1 \
        || die "--check needs python3 (the emulator requires a pty)"
    say "checking: a command is typed and its answer is verified"
    python3 "$AQUI/tools/check.py" "$GX" "$KERNEL" "$DISCO"
    exit $?
fi

# ----------------------------------------------------------------- interactivo
cat <<'TXT'

  CMU Mach 3.0 MK83 + servidor POE 10.1.0, userland de Ultrix RISC 4.5.
  Booting takes about forty seconds; the shell prints no prompt, so when the
  text stops coming, type a command and press Enter.

  Pruebalas:   echo hola      ls /      pwd      date      cat /etc/setup

  To leave:  Ctrl-C  and then  quit

TXT

parches_cpu -e 3max -d "$DISCO" "$KERNEL"
