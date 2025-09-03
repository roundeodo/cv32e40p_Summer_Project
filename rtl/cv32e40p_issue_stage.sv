// ============================================================================
// cv32e40p_issue_stage
// 功能(Function): 将 ID stage 的所有输出打一拍（pipeline register）再输出，
//                 输出信号名保持与原 ID->EX 命名一致，方便无缝替换。
// 说明(Notes):
//   - 无 stall/flush/enable：纯寄存器穿透（one-cycle latency）。
//   - 复位(reset)时全部清零('0)。
//   - 中英双语术语：
//       * Issue Stage（指令发射阶段）
//       * Pipeline Register（流水线寄存器）
//       * Stall（停顿/阻塞）、Flush（刷新/清空）——此处未实现
// ============================================================================

module cv32e40p_issue_stage
  import cv32e40p_pkg::*;
  import cv32e40p_apu_core_pkg::*;
#(
    parameter COREV_PULP           = 1,
    parameter COREV_CLUSTER        = 0,
    parameter N_HWLP               = 2,
    parameter N_HWLP_BITS          = $clog2(N_HWLP),
    parameter PULP_SECURE          = 0,
    parameter USE_PMP              = 0,
    parameter A_EXTENSION          = 0,
    parameter APU                  = 0,
    parameter FPU                  = 0,
    parameter FPU_ADDMUL_LAT       = 0,
    parameter FPU_OTHERS_LAT       = 0,
    parameter ZFINX                = 0,
    parameter APU_NARGS_CPU        = 3,
    parameter APU_WOP_CPU          = 6,
    parameter APU_NDSFLAGS_CPU     = 15,
    parameter APU_NUSFLAGS_CPU     = 5,
    parameter DEBUG_TRIGGER_EN     = 1
) (
    input  logic clk,
    input  logic rst_n,
    input logic ex_ready_i, // from EX stage, to all ID/EX flops

    // ---------------- General / IF-Interface / Decode state ----------------
    input  logic        ctrl_busy_i,    //from ID stage, to sleep unit, not sure wether flop
    input  logic        is_decoding_i,  // from ID stage, to EX stage, not sure wether flop

    // Interface to IF stage
    input  logic        instr_req_i,    // to IF stage and PMP module, probably not flop

    // Jumps and branches
    input  logic        branch_in_ex_i, // from ID stage, to EX stage, flopped
    input  logic [31:0] jump_target_i,  //from ID stage, to IF stage, maybe not flop
    input  logic [ 1:0] ctrl_transfer_insn_in_dec_i,  // from ID stage, to EX stage, flopped

    // IF and ID stage signals
    input  logic       clear_instr_valid_i,   // from ID stage, to IF stage, maybe not flop
    input  logic       pc_set_i,         // from ID stage, to IF stage, maybe not flop
    input  logic [3:0] pc_mux_i,      //to IF
    input  logic [2:0] exc_pc_mux_i,  //to IF
    input  logic [1:0] trap_addr_mux_i, //to IF

    // Stalls / Handshake
    input  logic halt_if_i, //to IF, 
    input  logic id_ready_i, // to IF
    input  logic id_valid_i, // some logic operations in CORE

    // ------------------------ ID/EX pipeline bundle ------------------------
    input  logic [31:0] pc_ex_i,  // to CSR, need flop, there's also pc_if and pc_id signal to CSR

    // ALU operands to EX stage
    input  logic [31:0] alu_operand_a_ex_i,
    input  logic [31:0] alu_operand_b_ex_i,
    input  logic [31:0] alu_operand_c_ex_i,
    input  logic [ 4:0] bmask_a_ex_i,
    input  logic [ 4:0] bmask_b_ex_i,
    input  logic [ 1:0] imm_vec_ext_ex_i,
    input  logic [ 1:0] alu_vec_mode_ex_i,

    //input for operand forwarding
    // Forwarding
    input  logic        [       1:0] operand_a_fw_mux_sel_i,
    input  logic        [       1:0] operand_b_fw_mux_sel_i,
    input  logic        [       1:0] operand_c_fw_mux_sel_i,
    input  logic        [       2:0] alu_op_a_mux_sel_i,
    input  logic        [       2:0] alu_op_b_mux_sel_i,
    input  logic        [       1:0] alu_op_c_mux_sel_i,
    input  logic [31:0] regfile_alu_wdata_fw_i,
    input  logic [31:0] regfile_wdata_wb_i,


    input  logic [5:0] regfile_waddr_ex_i,
    input  logic       regfile_we_ex_i,

    input  logic [5:0] regfile_alu_waddr_ex_i,
    input  logic       regfile_alu_we_ex_i,

    // ALU
    input  logic              alu_en_ex_i,
    input  alu_opcode_e       alu_operator_ex_i,
    input  logic              alu_is_clpx_ex_i,
    input  logic              alu_is_subrot_ex_i,
    input  logic        [1:0] alu_clpx_shift_ex_i,

    // MUL
    input  mul_opcode_e        mult_operator_ex_i,
    input  logic        [31:0] mult_operand_a_ex_i,
    input  logic        [31:0] mult_operand_b_ex_i,
    input  logic        [31:0] mult_operand_c_ex_i,
    input  logic               mult_en_ex_i,
    input  logic               mult_sel_subword_ex_i,
    input  logic        [ 1:0] mult_signed_mode_ex_i,
    input  logic        [ 4:0] mult_imm_ex_i,

    input  logic [31:0] mult_dot_op_a_ex_i,
    input  logic [31:0] mult_dot_op_b_ex_i,
    input  logic [31:0] mult_dot_op_c_ex_i,
    input  logic [ 1:0] mult_dot_signed_ex_i,
    input  logic        mult_is_clpx_ex_i,
    input  logic [ 1:0] mult_clpx_shift_ex_i,
    input  logic        mult_clpx_img_ex_i,

    // APU
    input  logic                              apu_en_ex_i,
    input  logic [     APU_WOP_CPU-1:0]       apu_op_ex_i,
    input  logic [                 1:0]       apu_lat_ex_i,
    input  logic [   APU_NARGS_CPU-1:0][31:0] apu_operands_ex_i,
    input  logic [APU_NDSFLAGS_CPU-1:0]       apu_flags_ex_i,     // not to EX stage, to core output
    input  logic [                 5:0]       apu_waddr_ex_i,

    input  logic [2:0][5:0] apu_read_regs_i,
    input  logic [2:0]      apu_read_regs_valid_i,
    input  logic [1:0][5:0] apu_write_regs_i,
    input  logic [1:0]      apu_write_regs_valid_i,
    input  logic            apu_perf_dep_i,   // to CSR
    //还没看
    // CSR ID/EX
    input  logic              csr_access_ex_i,    //to EX stage, also a logic operation
    input  csr_opcode_e       csr_op_ex_i,    //assign csr_op = csr_op_ex; to CSR
    input  logic              csr_irq_sec_i,  //to CSR
    input  logic        [5:0] csr_cause_i,    //to CSR and issertion
    input  logic              csr_save_if_i,
    input  logic              csr_save_id_i,
    input  logic              csr_save_ex_i,
    input  logic              csr_restore_mret_id_i,
    input  logic              csr_restore_uret_id_i,
    input  logic              csr_restore_dret_id_i,
    input  logic              csr_save_cause_i,   //to CSR and issertion

    // hwloop signals
    input  logic [N_HWLP-1:0][31:0] hwlp_start_i,   //to CSR
    input  logic [N_HWLP-1:0][31:0] hwlp_end_i,     //to CSR
    input  logic [N_HWLP-1:0][31:0] hwlp_cnt_i,     //to CSR
    input  logic                    hwlp_jump_i,    //to IF stage, maybe not flop
    input  logic [      31:0]       hwlp_target_i,  // to IF stage, maybe not flop

    // Interface to load store unit
    input  logic       data_req_ex_i,     //to EX stage and LSU, flopped
    input  logic       data_we_ex_i,      //to LSU, flopped
    input  logic [1:0] data_type_ex_i,    //to LSU, flopped
    input  logic [1:0] data_sign_ext_ex_i,      // to LSU, flopped
    input  logic [1:0] data_reg_offset_ex_i,    // to LSU, flopped
    input  logic       data_load_event_ex_i,    // to LSU, flopped

    input  logic data_misaligned_ex_i,      //to EX stage and LSU, flopped

    input  logic prepost_useincr_ex_i,      //to LSU  addr_useincr_ex_i
    input  logic data_err_ack_i,        //to PMP, not sure if flop

    input  logic [5:0] atop_ex_i,     // to LSU, flopped

    // Interrupt / Debug / Wake
    input  logic [31:0] mip_i,      //to CSR, flopped
    input  logic        irq_ack_i,  //output of the CORE, not sure wether flop
    input  logic [ 4:0] irq_id_i,   //output of the CORE, not sure wether flop
    input  logic [ 4:0] exc_cause_i,  //some logic operations in CORE and the result to IF stage,
                                      // not sure wether flop

    input  logic       debug_mode_i,    //to CSR, flopped and some assertion
    input  logic [2:0] debug_cause_i,   //to CSR
    input  logic       debug_csr_save_i, //to CSR
    input  logic       debug_p_elw_no_sleep_i,    //to sleep unit, not sure wether flop
    input  logic       debug_havereset_i,           //to CORE output, not sure whether flop
    input  logic       debug_running_i,       //to CORE output, not sure whether flop
    input  logic       debug_halted_i,        //to CORE output, not sure whether flop

    input  logic wake_from_sleep_i,       //to sleep unit, not sure wether flop

    // Performance Counters
    input  logic mhpmevent_minstret_i,    // all to CSR
    input  logic mhpmevent_load_i,
    input  logic mhpmevent_store_i,
    input  logic mhpmevent_jump_i,
    input  logic mhpmevent_branch_i,
    input  logic mhpmevent_branch_taken_i,
    input  logic mhpmevent_compressed_i,
    input  logic mhpmevent_jr_stall_i,
    input  logic mhpmevent_imiss_i,
    input  logic mhpmevent_ld_stall_i,
    input  logic mhpmevent_pipe_stall_i,


    input logic [31:0] pc_if_i,
    input logic [31:0] pc_id_i,
    input logic csr_mtvec_init_i, // to CSR, flopped


    // ------------------------------- Outputs -------------------------------
    output logic        ctrl_busy_o,
    output logic        is_decoding_o,

    output logic        instr_req_o,

    output logic        branch_in_ex_o,
    output logic [31:0] jump_target_o,
    output logic [ 1:0] ctrl_transfer_insn_in_dec_o,

    output logic       clear_instr_valid_o,
    output logic       pc_set_o,
    output logic [3:0] pc_mux_o,
    output logic [2:0] exc_pc_mux_o,
    output logic [1:0] trap_addr_mux_o,

    output logic halt_if_o,
    output logic id_ready_o,
    output logic id_valid_o,

    output logic [31:0] pc_ex_o,

    output logic [31:0] alu_operand_a_ex_o,
    output logic [31:0] alu_operand_b_ex_o,
    output logic [31:0] alu_operand_c_ex_o,
    output logic [ 4:0] bmask_a_ex_o,
    output logic [ 4:0] bmask_b_ex_o,
    output logic [ 1:0] imm_vec_ext_ex_o,
    output logic [ 1:0] alu_vec_mode_ex_o,

    output logic [5:0] regfile_waddr_ex_o,
    output logic       regfile_we_ex_o,

    output logic [5:0] regfile_alu_waddr_ex_o,
    output logic       regfile_alu_we_ex_o,

    output logic              alu_en_ex_o,
    output alu_opcode_e       alu_operator_ex_o,
    output logic              alu_is_clpx_ex_o,
    output logic              alu_is_subrot_ex_o,
    output logic        [1:0] alu_clpx_shift_ex_o,

    output mul_opcode_e        mult_operator_ex_o,
    output logic        [31:0] mult_operand_a_ex_o,
    output logic        [31:0] mult_operand_b_ex_o,
    output logic        [31:0] mult_operand_c_ex_o,
    output logic               mult_en_ex_o,
    output logic               mult_sel_subword_ex_o,
    output logic        [ 1:0] mult_signed_mode_ex_o,
    output logic        [ 4:0] mult_imm_ex_o,

    output logic [31:0] mult_dot_op_a_ex_o,
    output logic [31:0] mult_dot_op_b_ex_o,
    output logic [31:0] mult_dot_op_c_ex_o,
    output logic [ 1:0] mult_dot_signed_ex_o,
    output logic        mult_is_clpx_ex_o,
    output logic [ 1:0] mult_clpx_shift_ex_o,
    output logic        mult_clpx_img_ex_o,

    output logic                              apu_en_ex_o,
    output logic [     APU_WOP_CPU-1:0]       apu_op_ex_o,
    output logic [                 1:0]       apu_lat_ex_o,
    output logic [   APU_NARGS_CPU-1:0][31:0] apu_operands_ex_o,
    output logic [APU_NDSFLAGS_CPU-1:0]       apu_flags_ex_o,
    output logic [                 5:0]       apu_waddr_ex_o,

    output logic [2:0][5:0] apu_read_regs_o,
    output logic [2:0]      apu_read_regs_valid_o,
    output logic [1:0][5:0] apu_write_regs_o,
    output logic [1:0]      apu_write_regs_valid_o,
    output logic            apu_perf_dep_o,

    output logic              csr_access_ex_o,
    output csr_opcode_e       csr_op_ex_o,
    output logic              csr_irq_sec_o,
    output logic        [5:0] csr_cause_o,
    output logic              csr_save_if_o,
    output logic              csr_save_id_o,
    output logic              csr_save_ex_o,
    output logic              csr_restore_mret_id_o,
    output logic              csr_restore_uret_id_o,
    output logic              csr_restore_dret_id_o,
    output logic              csr_save_cause_o,

    output logic [N_HWLP-1:0][31:0] hwlp_start_o,
    output logic [N_HWLP-1:0][31:0] hwlp_end_o,
    output logic [N_HWLP-1:0][31:0] hwlp_cnt_o,
    output logic                    hwlp_jump_o,
    output logic [      31:0]       hwlp_target_o,

    output logic       data_req_ex_o,
    output logic       data_we_ex_o,
    output logic [1:0] data_type_ex_o,
    output logic [1:0] data_sign_ext_ex_o,
    output logic [1:0] data_reg_offset_ex_o,
    output logic       data_load_event_ex_o,

    output logic data_misaligned_ex_o,

    output logic prepost_useincr_ex_o,
    output logic data_err_ack_o,

    output logic [5:0] atop_ex_o,

    output logic [31:0] mip_o,
    output logic        irq_ack_o,
    output logic [ 4:0] irq_id_o,
    output logic [ 4:0] exc_cause_o,

    output logic       debug_mode_o,
    output logic [2:0] debug_cause_o,
    output logic       debug_csr_save_o,
    output logic       debug_p_elw_no_sleep_o,
    output logic       debug_havereset_o,
    output logic       debug_running_o,
    output logic       debug_halted_o,

    output logic wake_from_sleep_o,

    output logic mhpmevent_minstret_o,
    output logic mhpmevent_load_o,
    output logic mhpmevent_store_o,
    output logic mhpmevent_jump_o,
    output logic mhpmevent_branch_o,
    output logic mhpmevent_branch_taken_o,
    output logic mhpmevent_compressed_o,
    output logic mhpmevent_jr_stall_o,
    output logic mhpmevent_imiss_o,
    output logic mhpmevent_ld_stall_o,
    output logic mhpmevent_pipe_stall_o,


    output logic [31:0] pc_if_o,
    output logic [31:0] pc_id_o,
    output logic csr_mtvec_init_o // to CSR, flopped
);

    logic [31:0] alu_operand_a;
    logic [31:0] alu_operand_b;
    logic [31:0] alu_operand_c;
  ////////////////////////////////////////////////////////
  //   ___                                 _      _     //
  //  / _ \ _ __   ___ _ __ __ _ _ __   __| |    / \    //
  // | | | | '_ \ / _ \ '__/ _` | '_ \ / _` |   / _ \   //
  // | |_| | |_) |  __/ | | (_| | | | | (_| |  / ___ \  //
  //  \___/| .__/ \___|_|  \__,_|_| |_|\__,_| /_/   \_\ //
  //       |_|                                          //
  ////////////////////////////////////////////////////////

  // // ALU_Op_a Mux
  // always_comb begin : alu_operand_a_mux_is
  //   case (alu_op_a_mux_sel_i)
  //     OP_A_REGA_OR_FWD: alu_operand_a = operand_a_fw_id;        // 0
  //     OP_A_REGB_OR_FWD: alu_operand_a = operand_b_fw_id;    // 11 
  //     OP_A_REGC_OR_FWD: alu_operand_a = operand_c_fw_id;
  //     OP_A_CURRPC:      alu_operand_a = alu_operand_a_ex_i;        //1
  //     OP_A_IMM:         alu_operand_a = alu_operand_a_ex_i;
  //     default:          alu_operand_a = operand_a_fw_id;
  //   endcase
  //   ;  // case (alu_op_a_mux_sel)
  // end

  // // Operand a forwarding mux
  // always_comb begin : operand_a_fw_mux_is
  //   case (operand_a_fw_mux_sel_i)
  //     SEL_FW_EX:   operand_a_fw_id = regfile_alu_wdata_fw_i;      //1
  //     SEL_FW_WB:   operand_a_fw_id = regfile_wdata_wb_i;        //2
  //     SEL_REGFILE: operand_a_fw_id = alu_operand_a_ex_i;        //0
  //     default:     operand_a_fw_id = alu_operand_a_ex_i;
  //   endcase
  //   ;  // case (operand_a_fw_mux_sel_i)
  // end

always_comb begin : alu_operand_a_mux_is
  casez ({alu_op_a_mux_sel_i, operand_a_fw_mux_sel_i})
    // ---- 只关心 alu_op_a_mux_sel 的情况 ----
    {OP_A_CURRPC,   2'b??}: alu_operand_a = alu_operand_a_ex_i;
    {OP_A_IMM,      2'b??}: alu_operand_a = alu_operand_a_ex_i;

    // ---- 只关心 operand_a_fw_mux_sel 的情况 ----
    {3'b???, SEL_REGFILE}: alu_operand_a = alu_operand_a_ex_i;

    // ---- 需要同时关心两个信号的情况 ----
    {OP_A_REGA_OR_FWD, SEL_FW_EX}: alu_operand_a = regfile_alu_wdata_fw_i;
    {OP_A_REGA_OR_FWD, SEL_FW_WB}: alu_operand_a = regfile_wdata_wb_i;
    {OP_A_REGB_OR_FWD, SEL_FW_EX}: alu_operand_a = regfile_alu_wdata_fw_i;
    {OP_A_REGB_OR_FWD, SEL_FW_WB}: alu_operand_a = regfile_wdata_wb_i;
    {OP_A_REGC_OR_FWD, SEL_FW_EX}: alu_operand_a = regfile_alu_wdata_fw_i;
    {OP_A_REGC_OR_FWD, SEL_FW_WB}: alu_operand_a = regfile_wdata_wb_i;

    // ---- 默认情况 ----
    default: alu_operand_a = alu_operand_a_ex_i;
  endcase
end




  //////////////////////////////////////////////////////
  //   ___                                 _   ____   //
  //  / _ \ _ __   ___ _ __ __ _ _ __   __| | | __ )  //
  // | | | | '_ \ / _ \ '__/ _` | '_ \ / _` | |  _ \  //
  // | |_| | |_) |  __/ | | (_| | | | | (_| | | |_) | //
  //  \___/| .__/ \___|_|  \__,_|_| |_|\__,_| |____/  //
  //       |_|                                        //
  //////////////////////////////////////////////////////

  //   // ALU_Op_b Mux
  // always_comb begin : alu_operand_b_mux
  //   case (alu_op_b_mux_sel)
  //     OP_B_REGA_OR_FWD: operand_b = operand_a_fw_id;
  //     OP_B_REGB_OR_FWD: operand_b = operand_b_fw_id;
  //     OP_B_REGC_OR_FWD: operand_b = operand_c_fw_id;
  //     OP_B_IMM:         operand_b = alu_operand_b_ex_i;
  //     OP_B_BMASK:       operand_b = $unsigned(operand_b_fw_id[4:0]);
  //     default:          operand_b = operand_b_fw_id;
  //   endcase  // case (alu_op_b_mux_sel)
  // end






  // 同步寄存(registered on clock), 异步低复位(active-low async reset)
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // General / IF / decode
      ctrl_busy_o                   <= '0;
      is_decoding_o                 <= '0;
      instr_req_o                   <= '0;
      branch_in_ex_o                <= '0;
      jump_target_o                 <= '0;
      ctrl_transfer_insn_in_dec_o   <= '0;

      clear_instr_valid_o           <= '0;
      pc_set_o                      <= '0;
      pc_mux_o                      <= '0;
      exc_pc_mux_o                  <= '0;
      trap_addr_mux_o               <= '0;

      halt_if_o                     <= '0;
      id_ready_o                    <= '0;
      id_valid_o                    <= '0;

      // ID/EX
      pc_ex_o                       <= '0;
      pc_if_o                     <= '0;
      pc_id_o                     <= '0;
      csr_mtvec_init_o             <= '0;

      alu_operand_a_ex_o            <= '0;
      alu_operand_b_ex_o            <= '0;
      alu_operand_c_ex_o            <= '0;
      bmask_a_ex_o                  <= '0;
      bmask_b_ex_o                  <= '0;
      imm_vec_ext_ex_o              <= '0;
      alu_vec_mode_ex_o             <= '0;

      regfile_waddr_ex_o            <= '0;
      regfile_we_ex_o               <= '0;

      regfile_alu_waddr_ex_o        <= '0;
      regfile_alu_we_ex_o           <= '0;

      alu_en_ex_o                   <= '0;
      alu_operator_ex_o             <= ALU_SLTU;
      alu_is_clpx_ex_o              <= '0;
      alu_is_subrot_ex_o            <= '0;
      alu_clpx_shift_ex_o           <= '0;

      mult_operator_ex_o            <= MUL_MAC32;
      mult_operand_a_ex_o           <= '0;
      mult_operand_b_ex_o           <= '0;
      mult_operand_c_ex_o           <= '0;
      mult_en_ex_o                  <= '0;
      mult_sel_subword_ex_o         <= '0;
      mult_signed_mode_ex_o         <= '0;
      mult_imm_ex_o                 <= '0;

      mult_dot_op_a_ex_o            <= '0;
      mult_dot_op_b_ex_o            <= '0;
      mult_dot_op_c_ex_o            <= '0;
      mult_dot_signed_ex_o          <= '0;
      mult_is_clpx_ex_o             <= '0;
      mult_clpx_shift_ex_o          <= '0;
      mult_clpx_img_ex_o            <= '0;

      apu_en_ex_o                   <= '0;
      apu_op_ex_o                   <= '0;
      apu_lat_ex_o                  <= '0;
      apu_operands_ex_o             <= '0;
      apu_flags_ex_o                <= '0;
      apu_waddr_ex_o                <= '0;

      apu_read_regs_o               <= '0;
      apu_read_regs_valid_o         <= '0;
      apu_write_regs_o              <= '0;
      apu_write_regs_valid_o        <= '0;
      apu_perf_dep_o                <= '0;

      csr_access_ex_o               <= '0;
      csr_op_ex_o                   <= CSR_OP_READ;
      csr_irq_sec_o                 <= '0;
      csr_cause_o                   <= '0;
      csr_save_if_o                 <= '0;
      csr_save_id_o                 <= '0;
      csr_save_ex_o                 <= '0;
      csr_restore_mret_id_o         <= '0;
      csr_restore_uret_id_o         <= '0;
      csr_restore_dret_id_o         <= '0;
      csr_save_cause_o              <= '0;

      hwlp_start_o                  <= '0;
      hwlp_end_o                    <= '0;
      hwlp_cnt_o                    <= '0;
      hwlp_jump_o                   <= '0;
      hwlp_target_o                 <= '0;

      data_req_ex_o                 <= '0;
      data_we_ex_o                  <= '0;
      data_type_ex_o                <= '0;
      data_sign_ext_ex_o            <= '0;
      data_reg_offset_ex_o          <= '0;
      data_load_event_ex_o          <= '0;

      data_misaligned_ex_o          <= '0;

      prepost_useincr_ex_o          <= '0;
      data_err_ack_o                <= '0;

      atop_ex_o                     <= '0;

      mip_o                         <= '0;
      irq_ack_o                     <= '0;
      irq_id_o                      <= '0;
      exc_cause_o                   <= '0;

      debug_mode_o                  <= '0;
      debug_cause_o                 <= '0;
      debug_csr_save_o              <= '0;
      debug_p_elw_no_sleep_o        <= '0;
      debug_havereset_o             <= '0;
      debug_running_o               <= '0;
      debug_halted_o                <= '0;

      wake_from_sleep_o             <= '0;

      mhpmevent_minstret_o          <= '0;
      mhpmevent_load_o              <= '0;
      mhpmevent_store_o             <= '0;
      mhpmevent_jump_o              <= '0;
      mhpmevent_branch_o            <= '0;
      mhpmevent_branch_taken_o      <= '0;
      mhpmevent_compressed_o        <= '0;
      mhpmevent_jr_stall_o          <= '0;
      mhpmevent_imiss_o             <= '0;
      mhpmevent_ld_stall_o          <= '0;
      mhpmevent_pipe_stall_o        <= '0;

    end else begin
    //   if (csr_access_ex_o) begin
    //   regfile_alu_we_ex_o <= 1'b0;
    // end
    // if (id_valid_i)begin
      // General / IF / decode
      ctrl_busy_o                   <= ctrl_busy_i;
      is_decoding_o                 <= is_decoding_i;
      instr_req_o                   <= instr_req_i;
      branch_in_ex_o                <= branch_in_ex_i;
      jump_target_o                 <= jump_target_i;
      ctrl_transfer_insn_in_dec_o   <= ctrl_transfer_insn_in_dec_i;

      clear_instr_valid_o           <= clear_instr_valid_i;
      pc_set_o                      <= pc_set_i;
      pc_mux_o                      <= pc_mux_i;
      exc_pc_mux_o                  <= exc_pc_mux_i;
      trap_addr_mux_o               <= trap_addr_mux_i;

      halt_if_o                     <= halt_if_i;
      id_ready_o                    <= id_ready_i;
      id_valid_o                    <= id_valid_i;

      // ID/EX
      pc_ex_o                       <= pc_ex_i;
      pc_if_o                     <= pc_if_i;
      pc_id_o                     <= pc_id_i;
      csr_mtvec_init_o             <= csr_mtvec_init_i;


      alu_operand_a_ex_o            <= alu_operand_a;
      alu_operand_b_ex_o            <= alu_operand_b_ex_i;
      alu_operand_c_ex_o            <= alu_operand_c_ex_i;
      bmask_a_ex_o                  <= bmask_a_ex_i;
      bmask_b_ex_o                  <= bmask_b_ex_i;
      imm_vec_ext_ex_o              <= imm_vec_ext_ex_i;
      alu_vec_mode_ex_o             <= alu_vec_mode_ex_i;

      regfile_waddr_ex_o            <= regfile_waddr_ex_i;
      regfile_we_ex_o               <= regfile_we_ex_i;

      regfile_alu_waddr_ex_o        <= regfile_alu_waddr_ex_i;
      regfile_alu_we_ex_o           <= regfile_alu_we_ex_i;

      alu_en_ex_o                   <= alu_en_ex_i;
      alu_operator_ex_o             <= alu_operator_ex_i;
      alu_is_clpx_ex_o              <= alu_is_clpx_ex_i;
      alu_is_subrot_ex_o            <= alu_is_subrot_ex_i;
      alu_clpx_shift_ex_o           <= alu_clpx_shift_ex_i;

      mult_operator_ex_o            <= mult_operator_ex_i;
      mult_operand_a_ex_o           <= mult_operand_a_ex_i;
      mult_operand_b_ex_o           <= mult_operand_b_ex_i;
      mult_operand_c_ex_o           <= mult_operand_c_ex_i;
      mult_en_ex_o                  <= mult_en_ex_i;
      mult_sel_subword_ex_o         <= mult_sel_subword_ex_i;
      mult_signed_mode_ex_o         <= mult_signed_mode_ex_i;
      mult_imm_ex_o                 <= mult_imm_ex_i;

      mult_dot_op_a_ex_o            <= mult_dot_op_a_ex_i;
      mult_dot_op_b_ex_o            <= mult_dot_op_b_ex_i;
      mult_dot_op_c_ex_o            <= mult_dot_op_c_ex_i;
      mult_dot_signed_ex_o          <= mult_dot_signed_ex_i;
      mult_is_clpx_ex_o             <= mult_is_clpx_ex_i;
      mult_clpx_shift_ex_o          <= mult_clpx_shift_ex_i;
      mult_clpx_img_ex_o            <= mult_clpx_img_ex_i;

      apu_en_ex_o                   <= apu_en_ex_i;
      apu_op_ex_o                   <= apu_op_ex_i;
      apu_lat_ex_o                  <= apu_lat_ex_i;
      apu_operands_ex_o             <= apu_operands_ex_i;
      apu_flags_ex_o                <= apu_flags_ex_i;
      apu_waddr_ex_o                <= apu_waddr_ex_i;

      apu_read_regs_o               <= apu_read_regs_i;
      apu_read_regs_valid_o         <= apu_read_regs_valid_i;
      apu_write_regs_o              <= apu_write_regs_i;
      apu_write_regs_valid_o        <= apu_write_regs_valid_i;
      apu_perf_dep_o                <= apu_perf_dep_i;

      csr_access_ex_o               <= csr_access_ex_i;
      csr_op_ex_o                   <= csr_op_ex_i;
      csr_irq_sec_o                 <= csr_irq_sec_i;
      csr_cause_o                   <= csr_cause_i;
      csr_save_if_o                 <= csr_save_if_i;
      csr_save_id_o                 <= csr_save_id_i;
      csr_save_ex_o                 <= csr_save_ex_i;
      csr_restore_mret_id_o         <= csr_restore_mret_id_i;
      csr_restore_uret_id_o         <= csr_restore_uret_id_i;
      csr_restore_dret_id_o         <= csr_restore_dret_id_i;
      csr_save_cause_o              <= csr_save_cause_i;

      hwlp_start_o                  <= hwlp_start_i;
      hwlp_end_o                    <= hwlp_end_i;
      hwlp_cnt_o                    <= hwlp_cnt_i;
      hwlp_jump_o                   <= hwlp_jump_i;
      hwlp_target_o                 <= hwlp_target_i;

      data_req_ex_o                 <= data_req_ex_i;
      data_we_ex_o                  <= data_we_ex_i;
      data_type_ex_o                <= data_type_ex_i;
      data_sign_ext_ex_o            <= data_sign_ext_ex_i;
      data_reg_offset_ex_o          <= data_reg_offset_ex_i;
      data_load_event_ex_o          <= data_load_event_ex_i;

      data_misaligned_ex_o          <= data_misaligned_ex_i;

      prepost_useincr_ex_o          <= prepost_useincr_ex_i;
      data_err_ack_o                <= data_err_ack_i;

      atop_ex_o                     <= atop_ex_i;

      mip_o                         <= mip_i;
      irq_ack_o                     <= irq_ack_i;
      irq_id_o                      <= irq_id_i;
      exc_cause_o                   <= exc_cause_i;

      debug_mode_o                  <= debug_mode_i;
      debug_cause_o                 <= debug_cause_i;
      debug_csr_save_o              <= debug_csr_save_i;
      debug_p_elw_no_sleep_o        <= debug_p_elw_no_sleep_i;
      debug_havereset_o             <= debug_havereset_i;
      debug_running_o               <= debug_running_i;
      debug_halted_o                <= debug_halted_i;

      wake_from_sleep_o             <= wake_from_sleep_i;

      mhpmevent_minstret_o          <= mhpmevent_minstret_i;
      mhpmevent_load_o              <= mhpmevent_load_i;
      mhpmevent_store_o             <= mhpmevent_store_i;
      mhpmevent_jump_o              <= mhpmevent_jump_i;
      mhpmevent_branch_o            <= mhpmevent_branch_i;
      mhpmevent_branch_taken_o      <= mhpmevent_branch_taken_i;
      mhpmevent_compressed_o        <= mhpmevent_compressed_i;
      mhpmevent_jr_stall_o          <= mhpmevent_jr_stall_i;
      mhpmevent_imiss_o             <= mhpmevent_imiss_i;
      mhpmevent_ld_stall_o          <= mhpmevent_ld_stall_i;
      mhpmevent_pipe_stall_o        <= mhpmevent_pipe_stall_i;
    // end
    // else if (!ex_ready_i) begin
    //           regfile_we_ex_o      <= 1'b0;

    //     regfile_alu_we_ex_o  <= 1'b0;

    //     csr_op_ex_o          <= CSR_OP_READ;

    //     data_req_ex_o        <= 1'b0;

    //     data_load_event_ex_o <= 1'b0;

    //     data_misaligned_ex_o <= 1'b0;

    //     branch_in_ex_o       <= 1'b0;

    //     apu_en_ex_o          <= 1'b0;

    //     alu_operator_ex_o    <= ALU_SLTU;

    //     mult_en_ex_o         <= 1'b0;

    //     alu_en_ex_o          <= 1'b1;
    // end
    // else if (csr_access_ex_o) begin
    //   regfile_alu_we_ex_o <= 1'b0;
    // end
  end
  end

endmodule
