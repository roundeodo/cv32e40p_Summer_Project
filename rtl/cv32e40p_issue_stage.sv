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
    input logic rst_n,

    // handshake signals
    input  logic id2is_valid_i,
    output logic is2ex_valid_o,

    //outputs from the id stage
    input alu_opcode_e        alu_operator_i,
    input logic        [31:0] alu_operand_a_i,
    input logic        [31:0] alu_operand_b_i,
    input logic        [31:0] alu_operand_c_i,
    input logic               alu_en_i,
    input logic        [ 4:0] bmask_a_i,
    input logic        [ 4:0] bmask_b_i,
    input logic        [ 1:0] imm_vec_ext_i,
    input logic        [ 1:0] alu_vec_mode_i,
    input logic               alu_is_clpx_i,
    input logic               alu_is_subrot_i,
    input logic        [ 1:0] alu_clpx_shift_i,

    //outputs to the ex stage
    output logic        [31:0] alu_operand_a_o,
    output logic        [31:0] alu_operand_b_o,
    output logic        [31:0] alu_operand_c_o,
    output alu_opcode_e        alu_operator_o,
    output logic               alu_en_o,
    output logic        [ 4:0] bmask_a_o,
    output logic        [ 4:0] bmask_b_o,
    output logic        [ 1:0] imm_vec_ext_o,
    output logic        [ 1:0] alu_vec_mode_o,
    output logic               alu_is_clpx_o,
    output logic               alu_is_subrot_o,
    output logic        [ 1:0] alu_clpx_shift_o,



    // Interface to load store unit(input from id stage, output to ex stage)

    input logic       data_misaligned_ex_i,

    output logic      data_misaligned_ex_o,


    input logic [1:0] ctrl_transfer_insn_in_dec_i,
    output logic [1:0] ctrl_transfer_insn_in_dec_o,

    input logic        data_req_is_i,

    output logic       data_req_is_o,

    // Multiplier signals
    input mul_opcode_e        mult_operator_i,
    input logic        [31:0] mult_operand_a_i,
    input logic        [31:0] mult_operand_b_i,
    input logic        [31:0] mult_operand_c_i,
    input logic               mult_en_i,
    input logic               mult_sel_subword_i,
    input logic        [ 1:0] mult_signed_mode_i,
    input logic        [ 4:0] mult_imm_i,

    input logic [31:0] mult_dot_op_a_i,
    input logic [31:0] mult_dot_op_b_i,
    input logic [31:0] mult_dot_op_c_i,
    input logic [ 1:0] mult_dot_signed_i,
    input logic        mult_is_clpx_i,
    input logic [ 1:0] mult_clpx_shift_i,
    input logic        mult_clpx_img_i,

    output logic        [31:0] mult_operand_a_o,
    output logic        [31:0] mult_operand_b_o,
    output logic        [31:0] mult_operand_c_o,
    output mul_opcode_e        mult_operator_o,
    output logic               mult_en_o,
    output logic               mult_sel_subword_o,
    output logic        [ 1:0] mult_signed_mode_o,
    output logic        [ 4:0] mult_imm_o,

    output logic        [31:0] mult_dot_op_a_o,
    output logic        [31:0] mult_dot_op_b_o,
    output logic        [31:0] mult_dot_op_c_o,
    output logic        [ 1:0] mult_dot_signed_o,
    output logic               mult_is_clpx_o,
    output logic        [ 1:0] mult_clpx_shift_o,
    output logic               mult_clpx_img_o,

    // APU signals
    input logic                              apu_en_i,
    input logic [     APU_WOP_CPU-1:0]       apu_op_i,
    input logic [                 1:0]       apu_lat_i,
    input logic [   APU_NARGS_CPU-1:0][31:0] apu_operands_i,
    input logic [                 5:0]       apu_waddr_i,

    input  logic [2:0][5:0] apu_read_regs_i,
    input  logic [2:0]      apu_read_regs_valid_i,
    input  logic [1:0][5:0] apu_write_regs_i,
    input  logic [1:0]      apu_write_regs_valid_i,

    output logic                              apu_en_o,
    output logic [     APU_WOP_CPU-1:0]       apu_op_o,
    output logic [                 1:0]       apu_lat_o,
    output logic [   APU_NARGS_CPU-1:0][31:0] apu_operands_o,
    output logic [                 5:0]       apu_waddr_o,

    output logic [2:0][5:0] apu_read_regs_o,
    output logic [2:0]      apu_read_regs_valid_o,
    output logic [1:0][5:0] apu_write_regs_o,
    output logic [1:0]      apu_write_regs_valid_o,

    // input from ID stage
    input logic       branch_in_is_i,
    input logic [5:0] regfile_alu_waddr_i,
    input logic       regfile_alu_we_i,
    // directly passed through to WB stage, not used in EX
    input logic       regfile_we_i,
    input logic [5:0] regfile_waddr_i,

    // output to EX stage
    output logic       branch_in_is_o,
    output logic [5:0] regfile_alu_waddr_o,
    output logic       regfile_alu_we_o,
    // directly passed through to WB stage, not used in EX
    output logic       regfile_we_o,
    output logic [5:0] regfile_waddr_o,

    // CSR access
    input logic        csr_access_i,

    output logic        csr_access_o,



    input logic is_decoding_i,
    output logic is_decoding_o





);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      alu_operand_a_o <= 32'b0;
      alu_operand_b_o <= 32'b0;
      alu_operand_c_o <= 32'b0;
      alu_operator_o <= ALU_SLTU;
      alu_en_o <= 1'b0;
      bmask_a_o <= 5'b0;
      bmask_b_o <= 5'b0;
      imm_vec_ext_o <= 2'b0;
      alu_vec_mode_o <= 2'b0;
      alu_is_clpx_o <= 1'b0;
      alu_is_subrot_o <= 1'b0;
      alu_clpx_shift_o <= 2'b0;

      data_misaligned_ex_o <= 1'b0;

      ctrl_transfer_insn_in_dec_o <= 2'b0;

      data_req_is_o <= 1'b0;

      mult_operand_a_o <= 32'b0;
      mult_operand_b_o <= 32'b0;
      mult_operand_c_o <= 32'b0;
      mult_operator_o <= MUL_I;
      mult_en_o <= 1'b0;
      mult_sel_subword_o <= 1'b0;
      mult_signed_mode_o <= 2'b0;
      mult_imm_o <= 5'b0;

      mult_dot_op_a_o <= 32'b0;
      mult_dot_op_b_o <= 32'b0;
      mult_dot_op_c_o <= 32'b0;
      mult_dot_signed_o <= 2'b0;
      mult_is_clpx_o <= 1'b0;
      mult_clpx_shift_o <= 2'b0;
      mult_clpx_img_o <= 1'b0;

      apu_en_o <= 1'b0;
      apu_op_o <= 'b0;
      apu_lat_o <= 'b0;
      apu_operands_o = 'b0; // Initialize to zero
      apu_waddr_o = 'b0; // Initialize to zero

      apu_read_regs_valid_o = 'b0; // Initialize to zero
      apu_write_regs_valid_o = 'b0; // Initialize to zero
    end else begin
          alu_operand_a_o   <= alu_operand_a_i   ;
          alu_operand_b_o   <= alu_operand_b_i   ;
          alu_operand_c_o   <= alu_operand_c_i   ;
          alu_operator_o    <= alu_operator_i    ;  
          alu_en_o          <= alu_en_i          ;
          bmask_a_o         <= bmask_a_i         ;
          bmask_b_o         <= bmask_b_i         ;
          imm_vec_ext_o     <= imm_vec_ext_i     ;
          alu_vec_mode_o    <= alu_vec_mode_i    ;
          alu_is_clpx_o     <= alu_is_clpx_i     ;
          alu_is_subrot_o   <= alu_is_subrot_i   ;
          alu_clpx_shift_o  <= alu_clpx_shift_i  ;
          data_misaligned_ex_o <= data_misaligned_ex_i;
          ctrl_transfer_insn_in_dec_o <= ctrl_transfer_insn_in_dec_i;
          data_req_is_o     <= data_req_is_i     ;
          mult_operand_a_o  <= mult_operand_a_i  ;
          mult_operand_b_o  <= mult_operand_b_i  ;
          mult_operand_c_o  <= mult_operand_c_i  ;
          mult_operator_o   <= mult_operator_i   ;
          mult_en_o         <= mult_en_i         ;
          mult_sel_subword_o <= mult_sel_subword_i;
          mult_signed_mode_o <= mult_signed_mode_i;
          mult_imm_o        <= mult_imm_i        ;
          mult_dot_op_a_o   <= mult_dot_op_a_i   ;
          mult_dot_op_b_o   <= mult_dot_op_b_i   ;
          mult_dot_op_c_o   <= mult_dot_op_c_i   ;
          mult_dot_signed_o <= mult_dot_signed_i ;
          mult_is_clpx_o    <= mult_is_clpx_i    ;
          mult_clpx_shift_o <= mult_clpx_shift_i ;
          mult_clpx_img_o   <= mult_clpx_img_i   ;
          apu_en_o          <= apu_en_i         ;
          apu_op_o          <= apu_op_i         ;
          apu_lat_o         <= apu_lat_i        ;
          apu_operands_o    <= apu_operands_i    ;
          apu_waddr_o       <= apu_waddr_i       ;
          apu_read_regs_o   <= apu_read_regs_i   ;
          apu_read_regs_valid_o <= apu_read_regs_valid_i;
          apu_write_regs_o  <= apu_write_regs_i  ;
          apu_write_regs_valid_o <= apu_write_regs_valid_i;
          branch_in_is_o    <= branch_in_is_i    ;
          regfile_alu_waddr_o <= regfile_alu_waddr_i;
          regfile_alu_we_o  <= regfile_alu_we_i  ;
          regfile_we_o      <= regfile_we_i      ;
          regfile_waddr_o   <= regfile_waddr_i   ;
          csr_access_o      <= csr_access_i      ;
          is_decoding_o     <= is_decoding_i     ;
        end 
    end



endmodule