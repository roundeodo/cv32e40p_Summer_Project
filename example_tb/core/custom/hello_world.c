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
#ifdef RANDOM_MEM_STALL
    activate_random_stall(); // 启用 memory stall（可选）
#endif
    register int sum asm("t0");
    asm volatile (
        "li t0,0\n"
        "li t1,0\n"
        " 1: add t0, t0, 1\n"
        "    addi t1, t1, 1\n"
        "    csrrw t4, mcycle, x0\n"
        "    csrrw t5, minstret, x0\n"
        "    mul  t3, t0, t1\n"
        "    li   t2, 11\n"
        "    blt  t1, t2, 1b\n"

        : "=r"(sum)
    );
    printf("%d\n", sum);
    return EXIT_SUCCESS;
}



        // "   li t2,11\n"
        // "   blt t1, t2, 1b\n"