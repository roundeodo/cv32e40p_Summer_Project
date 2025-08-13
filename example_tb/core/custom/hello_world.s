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
# 44 "custom/hello_world.c" 1
	li   t0, 4
li   t1, 5
li   t6, 10
add  t0, t0, t1
addi t1, t1, 1
div  t3, t0, t1
sw   t6, 4(t0)
sw   t6, 4(t0)
sw   t6, 18(t0)
lw   t2, 4(t0)
lw   t2, 4(t0)
lw  t2, 26(t0)
mul  t0, t0, t1
sw   t6, 2(t0)

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
