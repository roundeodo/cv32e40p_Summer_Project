	.file	"hello_world.c"
	.option nopic
	.section	.text.startup,"ax",@progbits
	.align	1
	.globl	main
	.type	main, @function
main:
	lui	a0,%hi(.LC0)
	add	sp,sp,-16
	addi	a0,a0,%lo(.LC0)
	sw	ra,12(sp)
	call	puts
	lw	ra,12(sp)
	li	a0,0
	add	sp,sp,16
	jr	ra
	.size	main, .-main
	.section	.rodata.str1.4,"aMS",@progbits,1
	.align	2
.LC0:
	.string	"hello world!"
	.ident	"GCC: (GNU) 7.1.1 20170509"
