	.file	"hello_world.c"
	.option nopic
	.section	.text.startup,"ax",@progbits
	.align	1
	.globl	main
	.type	main, @function
main:
	add	sp,sp,-16
	sw	ra,12(sp)
 #APP
# 46 "custom/hello_world.c" 1
	li t0,0
li t1,0
 1: add t0, t0, 1
    addi t1, t1, 1
    csrrw t4, mcycle, x0
    csrrw t5, minstret, x0
    mul  t3, t0, t1
    li   t2, 11
    blt  t1, t2, 1b

# 0 "" 2
 #NO_APP
	lui	a0,%hi(.LC0)
	mv	a1,t0
	addi	a0,a0,%lo(.LC0)
	call	printf
	lw	ra,12(sp)
	li	a0,0
	add	sp,sp,16
	jr	ra
	.size	main, .-main
	.section	.rodata.str1.4,"aMS",@progbits,1
	.align	2
.LC0:
	.string	"%d\n"
	.ident	"GCC: (GNU) 7.1.1 20170509"
