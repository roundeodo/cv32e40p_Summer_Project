/*
 * Copyright 2020 ETH Zurich
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * Author: Robert Balas <balasr@iis.ee.ethz.ch>
 */

// #include <stdio.h>
// #include <stdlib.h>

// #include "mem_stall.h"

// int main(int argc, char *argv[])
// {
// #ifdef RANDOM_MEM_STALL
//     activate_random_stall();
// #endif
//     /* write something to stdout */
//     printf("hello world!\n");
//     return EXIT_SUCCESS;
// }


#include <stdio.h>
#include <stdlib.h>

#include "mem_stall.h"


int main(int argc, char *argv[])
{
    register int sum asm("t0");
    asm volatile (
        "li   t0, 4\n"       /* t0 = 0                       */
        "li   t1, 5\n"       /* t1 = 0                       */
        "li   t6, 10\n"       /* t2 = 0                       */
        /* ———— 单次执行的指令序列 ———— */
        "add  t0, t0, t1\n"  /* add：寄存器加法 (Add)       */
        "addi t1, t1, 1\n"   /* addi：立即数加法 (Add Immediate) */
        "div  t3, t0, t1\n"  /* div：除法 (Divide)           */
        "sw   t6, 4(t0)\n" /* sw：存储字 (Store Word)       */
        "sw   t6, 4(t0)\n" /* sw：存储字 (Store Word)       */
        "sw   t6, 18(t0)\n" /* sw：存储字 (Store Word)       */
        "lw   t2, 4(t0)\n" /* lw：加载字 (Load Word)       */  
        "lw   t2, 4(t0)\n" /* lw：加载字 (Load Word)       */ 
        "lw  t2, 26(t0)\n" /* lw：加载字 (Load Word)       */
        "mul  t0, t0, t1\n"  /* mul：乘法 (Multiply)         */
        "sw   t6, 2(t0)\n" /* sw：存储字 (Store Word)       */
        /* 不再有 blt/branch，就只走到这里 */
        : "=r"(sum)          /* 输出约束 (Output Constraint) */
        :                    /* 无输入约束 (No Inputs)       */
        : "t1", "t3", "t2", "t6"         /* 破坏列表 (Clobber List)      */
    );
    printf("%d\n", sum);
    return EXIT_SUCCESS;
}
