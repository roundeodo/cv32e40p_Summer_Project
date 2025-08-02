onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_top/wrapper_i/top_i/core_i/if_stage_i/prefetch_buffer_i/instruction_obi_i/clk
add wave -noupdate /tb_top/wrapper_i/top_i/core_i/if_stage_i/prefetch_buffer_i/instruction_obi_i/rst_n
add wave -noupdate /tb_top/wrapper_i/top_i/core_i/if_stage_i/prefetch_buffer_i/instruction_obi_i/trans_ready_o
add wave -noupdate /tb_top/wrapper_i/top_i/core_i/if_stage_i/prefetch_buffer_i/instruction_obi_i/trans_addr_i
add wave -noupdate /tb_top/wrapper_i/top_i/core_i/if_stage_i/prefetch_buffer_i/instruction_obi_i/trans_wdata_i
add wave -noupdate /tb_top/wrapper_i/top_i/core_i/if_stage_i/prefetch_buffer_i/instruction_obi_i/obi_req_o
add wave -noupdate /tb_top/wrapper_i/top_i/core_i/if_stage_i/prefetch_buffer_i/instruction_obi_i/obi_gnt_i
add wave -noupdate /tb_top/wrapper_i/top_i/core_i/if_stage_i/prefetch_buffer_i/instruction_obi_i/obi_addr_o
add wave -noupdate /tb_top/wrapper_i/top_i/core_i/if_stage_i/prefetch_buffer_i/instruction_obi_i/obi_wdata_o
add wave -noupdate /tb_top/wrapper_i/top_i/core_i/if_stage_i/prefetch_buffer_i/instruction_obi_i/obi_rdata_i
add wave -noupdate /tb_top/wrapper_i/top_i/core_i/if_stage_i/prefetch_buffer_i/instruction_obi_i/obi_rvalid_i
add wave -noupdate /tb_top/wrapper_i/top_i/core_i/ex_stage_i/alu_operator_i
add wave -noupdate /tb_top/wrapper_i/top_i/core_i/ex_stage_i/alu_operand_a_i
add wave -noupdate /tb_top/wrapper_i/top_i/core_i/ex_stage_i/alu_operand_b_i
add wave -noupdate /tb_top/wrapper_i/top_i/core_i/ex_stage_i/alu_operand_c_i
add wave -noupdate /tb_top/wrapper_i/top_i/core_i/ex_stage_i/alu_en_i
add wave -noupdate /tb_top/wrapper_i/top_i/core_i/ex_stage_i/mult_operator_i
add wave -noupdate /tb_top/wrapper_i/top_i/core_i/ex_stage_i/mult_operand_a_i
add wave -noupdate /tb_top/wrapper_i/top_i/core_i/ex_stage_i/mult_operand_b_i
add wave -noupdate /tb_top/wrapper_i/top_i/core_i/ex_stage_i/mult_operand_c_i
add wave -noupdate /tb_top/wrapper_i/top_i/core_i/ex_stage_i/mult_en_i
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {100 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 250
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {90 ns} {221 ns}
