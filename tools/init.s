/*
 * A minimal init for POE: opens the console, points descriptors 0, 1 and 2
 * at it and execs the shell.  The same thing minit.c does,
 * sin necesitar libc.
 */
	.text
	.globl	__start
	.ent	__start
__start:
	/*  fd = open("/dev/console", O_RDWR)  */
	la	$4, conspath
	li	$5, 2
	li	$2, 5
	syscall
	/*  dup(fd) dos veces: quedan 0,1,2 si fd salio 0  */
	move	$4, $2
	li	$2, 41
	syscall
	move	$4, $2
	li	$2, 41
	syscall
	/*  execve("/bin/sh", argv, envp)  */
	la	$4, shpath
	la	$5, argv
	la	$6, envp
	li	$2, 59
	syscall
	/*  si vuelve, exit(1)  */
	li	$4, 1
	li	$2, 1
	syscall
	.end	__start

	.data
conspath:	.asciiz	"/dev/console"
shpath:		.asciiz	"/bin/sh"
arg0:		.asciiz	"sh"
	.align	2
argv:		.word	arg0
		.word	0
envp:		.word	0
