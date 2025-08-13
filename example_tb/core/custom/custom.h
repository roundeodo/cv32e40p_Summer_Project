#define TEST0 asm volatile ("
                                  addi x1, x1, 1\n\t\
                                  addi x1, x1, 2\n\t\
                                  addi x1, x1, 3\n\t\
                                  addi x2, x2, 4\n\t\
                                  div  x3, x2, x1\n\t
                                  mul x1, x1, x2" \
                                 : : : "x1", "x2", "x3")