# CMU Mach 3.0 on an emulated DECstation 5000/200

Carnegie Mellon's Mach 3.0 microkernel, version MK83, with CMU's own POE 10.1.0
operating system server on top of it, running on a DECstation 5000/200 emulated
by GXemul. The userland is MIPS binaries from Ultrix RISC 4.5.

This is not a monolithic Unix. The kernel does not know what a file or a process
is. POE does, and POE is a user program, so every system call from every program
travels to it as a Mach message.

## Status

Boots to a working shell in about forty seconds. `echo`, `pwd`, `ls`, `cat` and
`date` work; the clock starts in 1972. There is no shell prompt, because Ultrix's
`/bin/sh` prints none when its input is not a terminal it recognises: when the
text stops, type.

Everything in `/bin` is on the disk but not all of it runs. The userland is
Ultrix and POE does not implement every call it makes.

**The machine is read only in practice.** Writes work inside a session, the file
appears and `ls` lists it, but POE keeps them in memory and never flushes them to
the device, so they are gone at the next boot. Its `/bin/sync` exists and does
nothing: in POE the call is defined as a no-op. Measured both ways, with md5: the
image comes out of the emulator byte for byte as it went in, after a read-only
session and after one that created a file. The good side of that is that it never
corrupts and never asks to be repaired, however you close it.

## What it takes to make it boot

**GXemul needs a terminal.** With its output redirected to a file it prints
nothing at all, not even its own banner, and hangs until the timeout. It has to
be given a pty: `script -qc "gxemul ..." out.log`. The same as SIMH over telnet
and MAME's serial console over a socket.

**The R3000 cache detection has to be skipped.** As it stands the kernel jumps to
address zero inside the cache sizing routine, which GXemul stopped emulating:
there used to be a configure option for it and it was dropped because only Mach
used it. `run.sh` zeroes four words before starting, which is the approach
GXemul's own documentation suggests:

    -c "put w 0x800990e0, 0" -c "put w 0x80099144, 0"
    -c "put w 0x8004aae8, 0" -c "put w 0x800810fc, 0"

**The serial device needs one patch**, in `patches/`. GXemul's `dev_dc7085.c`
returns early from its tick when the transmitter is ready, so keyboard input is
never processed; Mach 3.0 leaves TRDY set while it waits for RDONE, which means
the machine boots and then ignores everything typed at it.

The `memory READ: from non-existant paddr=...` and `Invalid ROM width` lines
during boot are the probe of empty TURBOchannel slots, not a fault.

## Mach steals an instruction, and that one is worth knowing

`mach/mips/mips_instruction.h` in CMU's distribution says it plainly:

    /* 0xe..0xf reserved, but Mach steals one: */
    #define op_tas          0xf

Mach takes a reserved MIPS I encoding for its test and set. The user space
emulator uses it raw, as `.word op_tas`, in the loop that takes the stack lock in
`emul_vector.s`. On a real R3000 that raises a reserved instruction exception,
which the kernel catches and emulates, returning the previous value of the lock
in `a0`.

GXemul instead executes `0x0000000f` as `SYNC`, which it implements as a no-op.
`a0` never changes, the loop never exits, and the emulator spins forever: the
system looks alive and is completely mute, with no call reaching the server.
`SYNC` does not exist in MIPS I. It arrived with MIPS II, so what Mach expects is
the correct reading.

## The disk

Two things are needed and neither is obvious.

**A DEC disk label.** `kernel/scsi/rz_labels.h` puts it at
`(2*8192) - sizeof(scsi_dec_label_t)`, that is 72 bytes at **offset 16312**,
sector 31, byte 440, at the end of the 4.3 superblock area where it is out of the
way. `rz_dec_label()` only checks the magic, 0x032957, and copies the eight
partition pairs. Partition `a` is index 0; with offset 0 and the whole disk as
its size the kernel finds `/dev/rz0a`.

**The directories have to be converted from 4.4 to 4.3 layout.** That is what
`tools/dir44to43.py` does, and it was the part that took longest to find. The
image is built with `makefs`, which writes 4.4 style directory entries;
`tools/devspec.mtree` is the device specification it needs, and without `uid` and
`gid` in it `makefs` complains that the group was not provided.

`tools/ffs.py` reads the resulting filesystem from the host, which is how the
image gets checked without booting anything.

## Look at the graphical console, not the serial line

This cost hours. Over the serial line the output arrives truncated in the middle
of a word, at a point that moves, and it looks like a random hang. With `-X`,
which WSLg provides, the kernel uses the graphical console and everything shows,
including the real point of failure.

## Layout

    run.sh                              builds the emulator if needed and boots
    patches/gxemul-dc7085-mach3.patch   the serial fix, against GXemul 0.7.0
    tools/check.py                      automated verification, no window
    tools/ffs.py                        reads the 4.3 filesystem from the host
    tools/dir44to43.py                  converts directories from 4.4 to 4.3
    tools/devspec.mtree                 the device nodes for makefs
    tools/init.s                        a minimal init: open the console, dup, exec sh
    tools/ddb.py                        drives the kernel debugger
    tools/teclear.py, tools/sesion.py   type at the guest at human speed

## What is not here

No CMU software and no Ultrix binaries. The kernel image
`mach.boot.MK83.STD+ANY`, the POE server and the disk image are not
redistributed. GXemul itself is not here either; it is in Ubuntu's archive and
`apt-get download gxemul` fetches it without root, or its source builds with the
patch above.

## License

BSD-3-Clause. See LICENSE.
