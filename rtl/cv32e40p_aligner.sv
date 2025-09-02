// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

////////////////////////////////////////////////////////////////////////////////
// Engineer:       Pasquale Davide Schiavone - pschiavo@iis.ee.ethz.ch        //
//                                                                            //
// Additional contributions by:                                               //
//                 Igor Loi - igor.loi@greenwaves-technologies.com            //
//                                                                            //
// Design Name:    Instrctuon Aligner                                         //
// Project Name:   RI5CY                                                      //
// Language:       SystemVerilog                                              //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module cv32e40p_aligner (
    input logic clk,
    input logic rst_n,

    input  logic fetch_valid_i,
    output logic aligner_ready_o,  //prevents overwriting the fethced instruction

    input logic if_valid_i,

    input  logic [63:0] fetch_rdata_i,   //输入数据改为64bit
    output logic [31:0] instr_aligned_o,
    output logic        instr_valid_o,
    output logic [31:0] instr_aligned_1_o,
    output logic        instr_valid_1_o,

    input logic [31:0] branch_addr_i,
    input logic        branch_i,  // Asserted if we are branching/jumping now

    input logic [31:0] hwlp_addr_i,
    input logic        hwlp_update_pc_i,

    output logic [31:0] pc_o,
    output logic [31:0] pc_1_o  // slot1端口，输出slot1对应的指令地址 
);

  enum logic [3:0] {
    ALIGNED64,
    MISALIGNED64_16,
    MISALIGNED64_32,
    MISALIGNED64_48,
    BRANCH_MISALIGNED,
    WAIT_VALID_BRANCH
  }
      state_q, state_n;

  logic [47:0] residual_data_q;
  logic [47:0] residual_data_n; 
  logic [31:0] hwlp_addr_q;
  logic [31:0] pc_q, pc_n;
  logic [31:0] pc_1_q, pc_1_n; // kept for now, but slot1 PC is driven combinationally
  logic update_state;
  logic [31:0] pc_plus8, pc_plus6, pc_plus4, pc_plus2;
  // Combinational slot1 PC for current cycle
  logic [31:0] pc1_c;
  logic aligner_ready_q, hwlp_update_pc_q;


  assign pc_o     = pc_q;
  assign pc_1_o   = pc1_c;

  // Increments are relative to current slot0 PC (pc_q)
  assign pc_plus2 = pc_q + 32'd2;
  assign pc_plus4 = pc_q + 32'd4;
  assign pc_plus6 = pc_q + 32'd6;
  assign pc_plus8 = pc_q + 32'd8;

  always_ff @(posedge clk or negedge rst_n) begin : proc_SEQ_FSM
    if (~rst_n) begin
      state_q            <= ALIGNED64;
      residual_data_q  <= '0;
      hwlp_addr_q      <= '0;
  pc_q             <= '0;
  pc_1_q           <= '0;
      aligner_ready_q  <= 1'b0;
      hwlp_update_pc_q <= 1'b0;
    end else begin
      if (update_state) begin
  pc_q             <= pc_n;
  pc_1_q           <= pc_1_n;
        state_q          <= state_n;
        residual_data_q  <= residual_data_n;
        aligner_ready_q  <= aligner_ready_o;
        hwlp_update_pc_q <= 1'b0;
      end else begin
        if (hwlp_update_pc_i) begin
          hwlp_addr_q      <= hwlp_addr_i;  // Save the JUMP target address to keep pc_n up to date during the stall
          hwlp_update_pc_q <= 1'b1;
        end

      end
    end
  end

  always_comb begin

    //default outputs
  pc_n            = pc_q;
  pc_1_n          = pc_1_q;
    instr_valid_o   = fetch_valid_i; 
    instr_aligned_o = fetch_rdata_i[31:0];  //slot0的输出值设定  默认输出输入数据的低32bit
    instr_valid_1_o = fetch_valid_i; 
    instr_aligned_1_o = fetch_rdata_i[63:32];//slot1的输出值设定  默认输出输入数据的高32bit
    aligner_ready_o = 1'b1;
    update_state    = 1'b0;
    state_n         = state_q;
  pc1_c           = pc_q; // default; meaningful only when instr_valid_1_o is 1


  case (state_q)
  ALIGNED64: begin
    // 三类：1)留在ALIGNED64(32+32)  2)进MISALIGNED64_16(32+16+X 或 16+32+X)  3)进MISALIGNED64_32(16+16+X)
    if ( (fetch_rdata_i[1:0] == 2'b11) && (fetch_rdata_i[33:32] == 2'b11) ) begin
            // ========== 类1：保持 ALIGNED64（32+32） ==========
            instr_aligned_o   = fetch_rdata_i[31:0];
            instr_aligned_1_o = fetch_rdata_i[63:32];
            pc1_c             = pc_plus4;   // slot1 from pc+4
            pc_n              = pc_plus8;   // advance by 8 (32+32)
            residual_data_n   = '0;
            state_n           = ALIGNED64;
            
            if (hwlp_update_pc_i || hwlp_update_pc_q) 
              pc_n = hwlp_update_pc_i ? hwlp_addr_i : hwlp_addr_q;
    end 
    
    else if ( ((fetch_rdata_i[1:0] == 2'b11) && (fetch_rdata_i[33:32] != 2'b11)) ||
            ((fetch_rdata_i[1:0] != 2'b11) && (fetch_rdata_i[17:16] == 2'b11)) ) begin
            // ========== 类2：进入 MISALIGNED64_16 ==========
      if (fetch_rdata_i[1:0] == 2'b11) begin
        // 32 + 16 + X
        instr_aligned_o   = fetch_rdata_i[31:0];
        instr_aligned_1_o = {fetch_rdata_i[47:32], fetch_rdata_i[47:32]};
        pc1_c             = pc_plus4;       // slot1 from pc+4
        pc_n              = pc_plus6;       // 32 + 16
      end 

      else begin
        // 16 + 32 + X
        instr_aligned_o   = {fetch_rdata_i[15:0], fetch_rdata_i[15:0]};
        instr_aligned_1_o = fetch_rdata_i[47:16];
        pc1_c             = pc_plus2;       // slot1 from pc+2
        pc_n              = pc_plus6;       // 16 + 32
      end

      // 余量：两种都只剩高16位
      residual_data_n[15:0]  = fetch_rdata_i[63:48];
      residual_data_n[47:16] = '0;
      state_n = MISALIGNED64_16;
    end 

    else begin
      // ========== 类3：进入 MISALIGNED64_32（16+16+X） ==========
      instr_aligned_o   = {fetch_rdata_i[15:0], fetch_rdata_i[15:0]};
      instr_aligned_1_o = {fetch_rdata_i[31:16], fetch_rdata_i[31:16]};
  pc1_c             = pc_plus2;         // slot1 from pc+2
  pc_n              = pc_plus4;         // 16 + 16
      residual_data_n[31:0]  = fetch_rdata_i[63:32];
      residual_data_n[47:32] = '0;
      state_n = MISALIGNED64_32;
    end

    // 更新条件：需有有效取回且下游接受
    update_state = fetch_valid_i & if_valid_i;
  end

  MISALIGNED64_16: begin
    // 64b 窗口 = {新取回的低48b, 上拍残留16b}
    // 三类：1) s0=32 且 s1=32 -> 仍留 16b 残留，转 MISALIGNED64_16
    //      2) s0=32 且 s1=16 -> 留 32b 残留，转 MISALIGNED64_32
    //      3) s0=16           -> 留 48b 残留，转 MISALIGNED64_48
    // s0 是否 32bit：看残留16的低2位
    if (residual_data_q[1:0] == 2'b11) begin
      // s0 = 32（由 r16+f[15:0] 拼接）
      // 再判断 s1 是否 32：s1 的低2位在 win64[33:32] => f[17:16]
      if (fetch_rdata_i[17:16] == 2'b11) begin
        // 类1：32 + 32，下一状态 MISALIGNED64_16，残留高16b
        instr_aligned_o   = {fetch_rdata_i[15:0], residual_data_q[15:0]};
        instr_aligned_1_o = fetch_rdata_i[47:16];
        // slot1 从 pc+4 开始；总前进 8 字节
        pc1_c             = pc_plus4;
        pc_n              = pc_plus8;
        // 残留保存 f[63:48]
        residual_data_n[15:0]  = fetch_rdata_i[63:48];
        residual_data_n[47:16] = '0;
        state_n = MISALIGNED64_16;
      end 
      
      else begin
  // 类2：32 + 16，下一状态 MISALIGNED64_32，残留高32b
        instr_aligned_o   = {fetch_rdata_i[15:0], residual_data_q[15:0]};
        instr_aligned_1_o = {fetch_rdata_i[31:16], fetch_rdata_i[31:16]};
  // slot1 从 pc+4 开始；总前进 6 字节
  pc1_c             = pc_plus4;
  pc_n              = pc_plus6;
        // 残留保存 f[63:32]
        residual_data_n[31:0]  = fetch_rdata_i[63:32];
        residual_data_n[47:32] = '0;
        state_n = MISALIGNED64_32;
      end
    end 
    
    else begin
      // ========== 类3：s0 = 16 ==========
      // 残留16 本身是一条完整 16b 指令；根据 f[1:0] 决定 slot1 长度与残留类别
      instr_aligned_o = {residual_data_q[15:0], residual_data_q[15:0]};

      if (fetch_rdata_i[1:0] == 2'b11) begin
        // —— 16 + 32 + X：slot1 = f[31:0]；残留 = f[63:32]（32b），转 MISALIGNED64_32
  instr_aligned_1_o = fetch_rdata_i[31:0];
  pc1_c             = pc_plus2;
  pc_n              = pc_plus6; // 16 + 32
        residual_data_n[31:0]  = fetch_rdata_i[63:32];
        residual_data_n[47:32] = '0;
        state_n = MISALIGNED64_32;
      end 
      
      else begin
        // —— 16 + 16 + X：slot1 = f[15:0]；残留 = f[63:16]（48b），转 MISALIGNED64_48
  instr_aligned_1_o = {fetch_rdata_i[15:0], fetch_rdata_i[15:0]};
  pc1_c             = pc_plus2;
  pc_n              = pc_plus4; // 16 + 16
        residual_data_n   = fetch_rdata_i[63:16];
        state_n = MISALIGNED64_48;
      end
    end

    // 更新条件：需有有效取回且下游接受
    update_state = fetch_valid_i & if_valid_i;
  end

  MISALIGNED64_32: begin
    // 残留32：可能是 {32} 或 {16,16}
    // 判据：
    //   r_s0_len = (residual_data_q[1:0]==2'b11) ? 32 : 16
    //   若 r_s0_len==16，再看 r_s1_is_32half = (residual_data_q[17:16]==2'b11)
    //   f_s0_len = (fetch_rdata_i[1:0]==2'b11) ? 32 : 16

    if (residual_data_q[1:0] == 2'b11) begin
      // ========== 类1：r32 + f32 -> 仍留 32b，转 MISALIGNED64_32 ==========
      if (fetch_rdata_i[1:0] == 2'b11) begin
        instr_aligned_o   = residual_data_q[31:0];
        instr_aligned_1_o = fetch_rdata_i[31:0];
        pc1_c             = pc_plus4;
        pc_n              = pc_plus8; // 32 + 32
        residual_data_n[31:0]  = fetch_rdata_i[63:32];
        residual_data_n[47:32] = '0;
        state_n = MISALIGNED64_32;
        update_state = fetch_valid_i & if_valid_i;
        aligner_ready_o = 1'b1;
      end 
      
      else begin
        // ========== 类2A：r32 + f16 -> 留 48b，转 MISALIGNED64_48 ==========
        instr_aligned_o   = residual_data_q[31:0];
        instr_aligned_1_o = {fetch_rdata_i[15:0], fetch_rdata_i[15:0]};
        pc1_c             = pc_plus4;
        pc_n              = pc_plus6; // 32 + 16
        residual_data_n   = fetch_rdata_i[63:16];
        state_n           = MISALIGNED64_48;
        update_state      = fetch_valid_i & if_valid_i;
        aligner_ready_o   = 1'b1;
      end
    end 
    
    else begin
      // r_s0_len = 16
      if (residual_data_q[17:16] == 2'b11) begin
        // ========== 类2B：r16 + r32(half) + f16 -> 留 48b，转 MISALIGNED64_48 ==========
  instr_aligned_o   = {residual_data_q[15:0], residual_data_q[15:0]};
  instr_aligned_1_o = {fetch_rdata_i[15:0], residual_data_q[31:16]};
  pc1_c             = pc_plus2;
  pc_n              = pc_plus6; // 16 + 32
        residual_data_n   = fetch_rdata_i[63:16];
        state_n           = MISALIGNED64_48;
        update_state      = fetch_valid_i & if_valid_i;
        aligner_ready_o   = 1'b1;
      end 
      
      else begin
        // ========== 类3：r16 + r16 -> 仅用残留输出，回 ALIGNED64 ==========
  instr_aligned_o   = {residual_data_q[15:0], residual_data_q[15:0]};
  instr_aligned_1_o = {residual_data_q[31:16], residual_data_q[31:16]};
  pc1_c             = pc_plus2;
  pc_n              = pc_plus4; // 16 + 16
        residual_data_n   = '0;
        state_n           = ALIGNED64;
        // 不消耗新取回，反压以保住输入
        aligner_ready_o   = !fetch_valid_i;
        update_state      = if_valid_i;
      end
    end
  end

  MISALIGNED64_48: begin
    // 残留48：可能是 {32,16}，{16，32} 或 {32,32(half)} 或 {16,16,32(half)} 或 {16,16,16}
    // 判据位：
    //   r0_is32     = (residual_data_q[1:0]  == 2'b11)
    //   r1_is32low  = (residual_data_q[17:16]== 2'b11) // 在 bit16 处开始的 32 的低半字
    //   r2_is32low  = (residual_data_q[33:32]== 2'b11) // 在 bit32 处开始的 32 的低半字

    if (residual_data_q[1:0] == 2'b11) begin
      // 首条 = 32
      if (residual_data_q[33:32] == 2'b11) begin
        // ========== 类1A：r32 + r32(half) -> 需拼接，消耗 f16，仍留 48b，转 MISALIGNED64_48 ==========
  instr_aligned_o   = residual_data_q[31:0];
  instr_aligned_1_o = {fetch_rdata_i[15:0], residual_data_q[47:32]};
  pc1_c             = pc_plus4;
  pc_n              = pc_plus8; // 32 + 32
        residual_data_n   = fetch_rdata_i[63:16];
        state_n           = MISALIGNED64_48;
        update_state      = fetch_valid_i & if_valid_i;
        aligner_ready_o   = 1'b1;
      end 
      
      else begin
        // ========== 类3A：r32 + r16 -> 仅用残留输出，回 ALIGNED64 ==========
  instr_aligned_o   = residual_data_q[31:0];
  instr_aligned_1_o = {residual_data_q[47:32], residual_data_q[47:32]};
  pc1_c             = pc_plus4;
  pc_n              = pc_plus6; // 32 + 16
        residual_data_n   = '0;
        state_n           = ALIGNED64;
        // 不消耗新取回，反压以保住输入
        aligner_ready_o   = !fetch_valid_i;
        update_state      = if_valid_i;
      end
    end 
    
    else begin
      // 首条 = 16
      if (residual_data_q[17:16] == 2'b11) begin
        // ========== 类1B：r16 + r32 -> 仅用残留输出两条，回 ALIGNED64 ==========
  instr_aligned_o   = {residual_data_q[15:0], residual_data_q[15:0]};
  instr_aligned_1_o = residual_data_q[47:16];
  pc1_c             = pc_plus2;
  pc_n              = pc_plus6; // 16 + 32
        residual_data_n   = '0;
        state_n           = ALIGNED64;
        // 不消耗新取回，反压以保住输入
        aligner_ready_o   = !fetch_valid_i;
        update_state      = if_valid_i;
      end 
      
      else begin
        // 次条也是 16
        if (residual_data_q[33:32] == 2'b11) begin
          // ========== 类2A：r16 + r16 + r32(half) -> 仅用残留输出两条，余 16b，转 MISALIGNED64_16 ==========
          instr_aligned_o   = {residual_data_q[15:0], residual_data_q[15:0]};
          instr_aligned_1_o = {residual_data_q[31:16], residual_data_q[31:16]};
          pc1_c             = pc_plus2;
          pc_n              = pc_plus4; // 16 + 16
          // 保留最高 16b（第三个 half）为新的 16b 残留
          residual_data_n[15:0]  = residual_data_q[47:32];
          residual_data_n[47:16] = '0;
          state_n           = MISALIGNED64_16;
          // 不消耗新取回，反压
          aligner_ready_o   = !fetch_valid_i;
          update_state      = if_valid_i;
        end 
        
        else begin
          // ========== 类2B：r16 + r16 + r16 -> 仅用残留输出两条，余 16b，转 MISALIGNED64_16 ==========
          instr_aligned_o   = {residual_data_q[15:0], residual_data_q[15:0]};
          instr_aligned_1_o = {residual_data_q[31:16], residual_data_q[31:16]};
          pc1_c             = pc_plus2;
          pc_n              = pc_plus4; // 16 + 16
          residual_data_n[15:0]  = residual_data_q[47:32];
          residual_data_n[47:16] = '0;
          state_n           = MISALIGNED64_16;
          // 不消耗新取回，反压
          aligner_ready_o   = !fetch_valid_i;
          update_state      = if_valid_i;
        end
      end
    end
  end

      BRANCH_MISALIGNED: begin
        // 分支目标落在 64b 拍内的 16/32/48bit 偏移处；尽量多产出，并设置残留与下个状态
        // 使用 pc_q[2:0] 判断拍内偏移（单位字节）：000 对齐；010=+16b；100=+32b；110=+48b
        // 注意：本状态不会“仅残留输出”，因此一般消耗当前 fetch（除 offset=48 且 32(half) 无法输出时不产出）

        unique case (pc_q[2:0])
          3'b010: begin // +16b，有效窗口 f[63:16]（48b）
            if (fetch_rdata_i[17:16] == 2'b11) begin
              // s0=32 at 16；s1 位于 48
              if (fetch_rdata_i[49:48] == 2'b11) begin
                // 32 + 32(half)：本拍仅能产出一条32；余下 16b 残留
                instr_aligned_o   = fetch_rdata_i[47:16];
                instr_valid_o     = fetch_valid_i;
                instr_aligned_1_o = '0;
                instr_valid_1_o   = 1'b0;
                pc1_c             = 'b0; //本周期的slot0无效
                pc_n              = pc_plus4;
                residual_data_n[15:0]  = fetch_rdata_i[63:48];
                residual_data_n[47:16] = '0;
                state_n           = MISALIGNED64_16;
                update_state      = fetch_valid_i & if_valid_i;
                aligner_ready_o   = 1'b1;
              end 
              
              else begin
                // 32 + 16：两条齐
                instr_aligned_o   = fetch_rdata_i[47:16];
                instr_valid_o     = fetch_valid_i;
                instr_aligned_1_o = {fetch_rdata_i[63:48], fetch_rdata_i[63:48]};
                instr_valid_1_o   = fetch_valid_i;
                pc1_c             = pc_plus4;
                pc_n              = pc_plus6;
                residual_data_n   = '0;
                state_n           = ALIGNED64;
                update_state      = fetch_valid_i & if_valid_i;
                aligner_ready_o   = 1'b1;
              end
            end
            
            else begin
              // s0=16 at 16
              if (fetch_rdata_i[33:32] == 2'b11) begin
                // 16 + 32：两条齐
                instr_aligned_o   = {fetch_rdata_i[31:16], fetch_rdata_i[31:16]};
                instr_valid_o     = fetch_valid_i;
                instr_aligned_1_o = fetch_rdata_i[63:32];
                instr_valid_1_o   = fetch_valid_i;
                pc1_c             = pc_plus2;
                pc_n              = pc_plus6;
                residual_data_n   = '0;
                state_n           = ALIGNED64;
                update_state      = fetch_valid_i & if_valid_i;
                aligner_ready_o   = 1'b1;
              end 
              
              else begin
                // s1=16 at 32：无论后续是 16 还是 32(half)，本拍都产出两条16，并留下 16b 残留
                instr_aligned_o   = {fetch_rdata_i[31:16], fetch_rdata_i[31:16]};
                instr_valid_o     = fetch_valid_i;
                instr_aligned_1_o = {fetch_rdata_i[47:32], fetch_rdata_i[47:32]};
                instr_valid_1_o   = fetch_valid_i;
                pc1_c             = pc_plus2;
                pc_n              = pc_plus4;
                residual_data_n[15:0]  = fetch_rdata_i[63:48];
                residual_data_n[47:16] = '0;
                state_n           = MISALIGNED64_16;
                update_state      = fetch_valid_i & if_valid_i;
                aligner_ready_o   = 1'b1;
              end
            end
          end

          3'b100: begin // +32b，有效窗口 f[63:32]（32b）
            if (fetch_rdata_i[33:32] == 2'b11) begin
              // 32：仅一条
              instr_aligned_o   = fetch_rdata_i[63:32];
              instr_valid_o     = fetch_valid_i;
              instr_aligned_1_o = '0;
              instr_valid_1_o   = 1'b0;
              pc1_c             = 'b00; // 本周期slot1 无效
              pc_n              = pc_plus4;
              residual_data_n   = '0;
              state_n           = ALIGNED64;
              update_state      = fetch_valid_i & if_valid_i;
              aligner_ready_o   = 1'b1;
            end 
            
            else begin
              // 首条 16 at 32
              if (fetch_rdata_i[49:48] == 2'b11) begin
                // 16 + 32(half)：仅一条 16，余 16 残留
                instr_aligned_o   = {fetch_rdata_i[47:32], fetch_rdata_i[47:32]};
                instr_valid_o     = fetch_valid_i;
                instr_aligned_1_o = '0;
                instr_valid_1_o   = 1'b0;
                pc1_c             = 'b00; // 本周期slot1 无效
                pc_n              = pc_plus2;
                residual_data_n[15:0]  = fetch_rdata_i[63:48];
                residual_data_n[47:16] = '0;
                state_n           = MISALIGNED64_16;
                update_state      = fetch_valid_i & if_valid_i;
                aligner_ready_o   = 1'b1;
              end 
              
              else begin
                // 16 + 16：两条齐
                instr_aligned_o   = {fetch_rdata_i[47:32], fetch_rdata_i[47:32]};
                instr_valid_o     = fetch_valid_i;
                instr_aligned_1_o = {fetch_rdata_i[63:48], fetch_rdata_i[63:48]};
                instr_valid_1_o   = fetch_valid_i;
                pc1_c             = pc_plus2;
                pc_n              = pc_plus4;
                residual_data_n   = '0;
                state_n           = ALIGNED64;
                update_state      = fetch_valid_i & if_valid_i;
                aligner_ready_o   = 1'b1;
              end
            end
          end

          3'b110: begin // +48b，有效窗口 f[63:48]（16b）
            if (fetch_rdata_i[49:48] == 2'b11) begin
              // 32(half)：本拍无法产出，保存 16b 残留，转 MISALIGNED64_16
              instr_valid_o     = 1'b0;
              instr_valid_1_o   = 1'b0;
              instr_aligned_o   = '0;
              instr_aligned_1_o = '0;
              pc1_c             = 'b0; // 本周slot1无效
              pc_n              = pc_q;
              residual_data_n[15:0]  = fetch_rdata_i[63:48];
              residual_data_n[47:16] = '0;
              state_n           = MISALIGNED64_16;
              update_state      = fetch_valid_i & if_valid_i;
              aligner_ready_o   = 1'b1;
            end 
            
            else begin
              // 16：仅一条 16
              instr_aligned_o   = {fetch_rdata_i[63:48], fetch_rdata_i[63:48]};
              instr_valid_o     = fetch_valid_i;
              instr_aligned_1_o = '0;
              instr_valid_1_o   = 1'b0;
              pc1_c             = 'b0; // 本周期slot1 无效
              pc_n              = pc_plus2;
              residual_data_n   = '0;
              state_n           = ALIGNED64;
              update_state      = fetch_valid_i & if_valid_i;
              aligner_ready_o   = 1'b1;
            end
          end

          default: begin
            // 其它偏移（理论上不会出现，因为目标地址 16b 对齐），安全回退
            instr_valid_o     = 1'b0;
            instr_valid_1_o   = 1'b0;
            state_n           = ALIGNED64;
            update_state      = 1'b1;
          end
        endcase
      end

    endcase  // state


    // JUMP, BRANCH, SPECIAL JUMP control
    if (branch_i) begin
      update_state = 1'b1;
      pc_n         = branch_addr_i;
      pc_1_n       = branch_addr_i;
      state_n      = (branch_addr_i[2:0] == 3'b000) ? ALIGNED64 : BRANCH_MISALIGNED;
    end

  end

  /*
  When a branch is taken in EX, if_valid_i is asserted because the BRANCH is resolved also in
  case of stalls. This is because the branch information is stored in the IF stage (in the prefetcher)
  when branch_i is asserted. We introduced here an apparently unuseful  special case for
  the JUMPS for a cleaner and more robust HW: theoretically, we don't need to save the instruction
  after a taken branch in EX, thus we will not do it.
*/

  //////////////////////////////////////////////////////////////////////////////
  // Assertions
  //////////////////////////////////////////////////////////////////////////////

`ifdef CV32E40P_ASSERT_ON

  // Hardware Loop check
  property p_hwlp_update_pc;
    @(posedge clk) disable iff (!rst_n) (1'b1) |-> (!(hwlp_update_pc_i && hwlp_update_pc_q));
  endproperty

  a_hwlp_update_pc :
  assert property (p_hwlp_update_pc);

`endif

endmodule