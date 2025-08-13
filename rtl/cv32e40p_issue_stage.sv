//I'm adding a new pipeline stage to the CV32E40P core
// This stage is the issue stage, which will handle instruction dispatching
//Now, I'll only retime the outputs of the id stage to the issue stage
// and the inputs of the ex stage to the issue stage
//so let's copy the outputs of the id stage to the issue stage as the inputs of the issue stage
// and register the outputs of the id stage as the outputs of the issue stage
//do it

module cv32e40p_issue_stage
  import cv32e40p_pkg::*;
  import cv32e40p_apu_core_pkg::*;
#(
    parameter COREV_PULP =  1,  // PULP ISA Extension (including PULP specific CSRs and hardware loop, excluding cv.elw)
    parameter COREV_CLUSTER = 0,
    parameter N_HWLP = 2,
    parameter N_HWLP_BITS = $clog2(N_HWLP),
    parameter PULP_SECURE = 0,
    parameter USE_PMP = 0,
    parameter A_EXTENSION = 0,
    parameter APU = 0,
    parameter FPU = 0,
    parameter FPU_ADDMUL_LAT = 0,
    parameter FPU_OTHERS_LAT = 0,
    parameter ZFINX = 0,
    parameter APU_NARGS_CPU = 3,
    parameter APU_WOP_CPU = 6,
    parameter APU_NDSFLAGS_CPU = 15,
    parameter APU_NUSFLAGS_CPU = 5,
    parameter DEBUG_TRIGGER_EN = 1
) (
    input logic clk,  // Gated clock
    input logic clk_ungated_i,  // Ungated clock
    input logic rst_n

);



endmodule