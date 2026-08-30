vlib modelsim_lib/work
vlib modelsim_lib/msim

vlib modelsim_lib/msim/xilinx_vip
vlib modelsim_lib/msim/xpm
vlib modelsim_lib/msim/microblaze_v11_0_16
vlib modelsim_lib/msim/xil_defaultlib
vlib modelsim_lib/msim/proc_sys_reset_v5_0_17
vlib modelsim_lib/msim/lmb_v10_v3_0_16
vlib modelsim_lib/msim/lmb_bram_if_cntlr_v4_0_27
vlib modelsim_lib/msim/blk_mem_gen_v8_4_12
vlib modelsim_lib/msim/iomodule_v3_1_13
vlib modelsim_lib/msim/jtag_axi
vlib modelsim_lib/msim/smartconnect_v1_0
vlib modelsim_lib/msim/axi_infrastructure_v1_1_0
vlib modelsim_lib/msim/axi_register_slice_v2_1_36
vlib modelsim_lib/msim/axi_vip_v1_1_22
vlib modelsim_lib/msim/util_vector_logic_v2_0_5

vmap xilinx_vip modelsim_lib/msim/xilinx_vip
vmap xpm modelsim_lib/msim/xpm
vmap microblaze_v11_0_16 modelsim_lib/msim/microblaze_v11_0_16
vmap xil_defaultlib modelsim_lib/msim/xil_defaultlib
vmap proc_sys_reset_v5_0_17 modelsim_lib/msim/proc_sys_reset_v5_0_17
vmap lmb_v10_v3_0_16 modelsim_lib/msim/lmb_v10_v3_0_16
vmap lmb_bram_if_cntlr_v4_0_27 modelsim_lib/msim/lmb_bram_if_cntlr_v4_0_27
vmap blk_mem_gen_v8_4_12 modelsim_lib/msim/blk_mem_gen_v8_4_12
vmap iomodule_v3_1_13 modelsim_lib/msim/iomodule_v3_1_13
vmap jtag_axi modelsim_lib/msim/jtag_axi
vmap smartconnect_v1_0 modelsim_lib/msim/smartconnect_v1_0
vmap axi_infrastructure_v1_1_0 modelsim_lib/msim/axi_infrastructure_v1_1_0
vmap axi_register_slice_v2_1_36 modelsim_lib/msim/axi_register_slice_v2_1_36
vmap axi_vip_v1_1_22 modelsim_lib/msim/axi_vip_v1_1_22
vmap util_vector_logic_v2_0_5 modelsim_lib/msim/util_vector_logic_v2_0_5

vlog -work xilinx_vip -64 -incr -mfcu  -sv -L smartconnect_v1_0 -L axi_vip_v1_1_22 -L xilinx_vip "+incdir+/opt/Xilinx/2025.2/data/xilinx_vip/include" \
"/opt/Xilinx/2025.2/data/xilinx_vip/hdl/axi4stream_vip_axi4streampc.sv" \
"/opt/Xilinx/2025.2/data/xilinx_vip/hdl/axi_vip_axi4pc.sv" \
"/opt/Xilinx/2025.2/data/xilinx_vip/hdl/xil_common_vip_pkg.sv" \
"/opt/Xilinx/2025.2/data/xilinx_vip/hdl/axi4stream_vip_pkg.sv" \
"/opt/Xilinx/2025.2/data/xilinx_vip/hdl/axi_vip_pkg.sv" \
"/opt/Xilinx/2025.2/data/xilinx_vip/hdl/axi4stream_vip_if.sv" \
"/opt/Xilinx/2025.2/data/xilinx_vip/hdl/axi_vip_if.sv" \
"/opt/Xilinx/2025.2/data/xilinx_vip/hdl/clk_vip_if.sv" \
"/opt/Xilinx/2025.2/data/xilinx_vip/hdl/rst_vip_if.sv" \

vlog -work xpm -64 -incr -mfcu  -sv -L smartconnect_v1_0 -L axi_vip_v1_1_22 -L xilinx_vip "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/map" "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/ip_top" "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/cal" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../bd/design_1/ipshared/1150/src" "+incdir+../../../../../../../../../opt/Xilinx/2025.2/data/rsb/busdef" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/map" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/rtl/ip_top" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/rtl/cal" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/5431/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/4e08/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/0de9/hdl" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/1150/src" "+incdir+/opt/Xilinx/2025.2/data/xilinx_vip/include" \
"/opt/Xilinx/2025.2/data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv" \
"/opt/Xilinx/2025.2/data/ip/xpm/xpm_fifo/hdl/xpm_fifo.sv" \
"/opt/Xilinx/2025.2/data/ip/xpm/xpm_memory/hdl/xpm_memory.sv" \

vcom -work xpm -64 -93  \
"/opt/Xilinx/2025.2/data/ip/xpm/xpm_VCOMP.vhd" \

vcom -work microblaze_v11_0_16 -64 -93  \
"../../../../npu_32.gen/sources_1/bd/design_1/ipshared/c957/hdl/microblaze_v11_0_vh_rfs.vhd" \

vcom -work xil_defaultlib -64 -93  \
"../../../bd/design_1/ip/design_1_ddr4_0_2/bd_0/ip/ip_0/sim/bd_be6b_microblaze_I_0.vhd" \

vcom -work proc_sys_reset_v5_0_17 -64 -93  \
"../../../../npu_32.gen/sources_1/bd/design_1/ipshared/9438/hdl/proc_sys_reset_v5_0_vh_rfs.vhd" \

vcom -work xil_defaultlib -64 -93  \
"../../../bd/design_1/ip/design_1_ddr4_0_2/bd_0/ip/ip_1/sim/bd_be6b_rst_0_0.vhd" \

vcom -work lmb_v10_v3_0_16 -64 -93  \
"../../../../npu_32.gen/sources_1/bd/design_1/ipshared/dac4/hdl/lmb_v10_v3_0_vh_rfs.vhd" \

vcom -work xil_defaultlib -64 -93  \
"../../../bd/design_1/ip/design_1_ddr4_0_2/bd_0/ip/ip_2/sim/bd_be6b_ilmb_0.vhd" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/bd_0/ip/ip_3/sim/bd_be6b_dlmb_0.vhd" \

vcom -work lmb_bram_if_cntlr_v4_0_27 -64 -93  \
"../../../../npu_32.gen/sources_1/bd/design_1/ipshared/7cd0/hdl/lmb_bram_if_cntlr_v4_0_vh_rfs.vhd" \

vcom -work xil_defaultlib -64 -93  \
"../../../bd/design_1/ip/design_1_ddr4_0_2/bd_0/ip/ip_4/sim/bd_be6b_dlmb_cntlr_0.vhd" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/bd_0/ip/ip_5/sim/bd_be6b_ilmb_cntlr_0.vhd" \

vlog -work blk_mem_gen_v8_4_12 -64 -incr -mfcu  "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/map" "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/ip_top" "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/cal" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../bd/design_1/ipshared/1150/src" "+incdir+../../../../../../../../../opt/Xilinx/2025.2/data/rsb/busdef" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/map" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/rtl/ip_top" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/rtl/cal" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/5431/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/4e08/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/0de9/hdl" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/1150/src" "+incdir+/opt/Xilinx/2025.2/data/xilinx_vip/include" \
"../../../../npu_32.gen/sources_1/bd/design_1/ipshared/42f3/simulation/blk_mem_gen_v8_4.v" \

vlog -work xil_defaultlib -64 -incr -mfcu  "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/map" "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/ip_top" "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/cal" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../bd/design_1/ipshared/1150/src" "+incdir+../../../../../../../../../opt/Xilinx/2025.2/data/rsb/busdef" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/map" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/rtl/ip_top" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/rtl/cal" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/5431/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/4e08/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/0de9/hdl" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/1150/src" "+incdir+/opt/Xilinx/2025.2/data/xilinx_vip/include" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/bd_0/ip/ip_6/sim/bd_be6b_lmb_bram_I_0.v" \

vcom -work xil_defaultlib -64 -93  \
"../../../bd/design_1/ip/design_1_ddr4_0_2/bd_0/ip/ip_7/sim/bd_be6b_second_dlmb_cntlr_0.vhd" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/bd_0/ip/ip_8/sim/bd_be6b_second_ilmb_cntlr_0.vhd" \

vlog -work xil_defaultlib -64 -incr -mfcu  "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/map" "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/ip_top" "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/cal" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../bd/design_1/ipshared/1150/src" "+incdir+../../../../../../../../../opt/Xilinx/2025.2/data/rsb/busdef" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/map" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/rtl/ip_top" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/rtl/cal" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/5431/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/4e08/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/0de9/hdl" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/1150/src" "+incdir+/opt/Xilinx/2025.2/data/xilinx_vip/include" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/bd_0/ip/ip_9/sim/bd_be6b_second_lmb_bram_I_0.v" \

vcom -work iomodule_v3_1_13 -64 -93  \
"../../../../npu_32.gen/sources_1/bd/design_1/ipshared/e11b/hdl/iomodule_v3_1_vh_rfs.vhd" \

vcom -work xil_defaultlib -64 -93  \
"../../../bd/design_1/ip/design_1_ddr4_0_2/bd_0/ip/ip_10/sim/bd_be6b_iomodule_0_0.vhd" \

vlog -work xil_defaultlib -64 -incr -mfcu  "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/map" "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/ip_top" "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/cal" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../bd/design_1/ipshared/1150/src" "+incdir+../../../../../../../../../opt/Xilinx/2025.2/data/rsb/busdef" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/map" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/rtl/ip_top" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/rtl/cal" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/5431/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/4e08/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/0de9/hdl" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/1150/src" "+incdir+/opt/Xilinx/2025.2/data/xilinx_vip/include" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/bd_0/sim/bd_be6b.v" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/ip_0/sim/design_1_ddr4_0_2_microblaze_mcs.v" \

vlog -work xil_defaultlib -64 -incr -mfcu  -sv -L smartconnect_v1_0 -L axi_vip_v1_1_22 -L xilinx_vip "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/map" "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/ip_top" "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/cal" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../bd/design_1/ipshared/1150/src" "+incdir+../../../../../../../../../opt/Xilinx/2025.2/data/rsb/busdef" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/map" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/rtl/ip_top" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/rtl/cal" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/5431/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/4e08/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/0de9/hdl" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/1150/src" "+incdir+/opt/Xilinx/2025.2/data/xilinx_vip/include" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/phy/design_1_ddr4_0_2_phy_ddr4.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/phy/ddr4_phy_v2_2_xiphy_behav.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/phy/ddr4_phy_v2_2_xiphy.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/iob/ddr4_phy_v2_2_iob_byte.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/iob/ddr4_phy_v2_2_iob.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/clocking/ddr4_phy_v2_2_pll.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/xiphy_files/ddr4_phy_v2_2_xiphy_tristate_wrapper.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/xiphy_files/ddr4_phy_v2_2_xiphy_riuor_wrapper.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/xiphy_files/ddr4_phy_v2_2_xiphy_control_wrapper.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/xiphy_files/ddr4_phy_v2_2_xiphy_byte_wrapper.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/xiphy_files/ddr4_phy_v2_2_xiphy_bitslice_wrapper.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/ip_top/design_1_ddr4_0_2_phy.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/controller/ddr4_v2_2_mc_wtr.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/controller/ddr4_v2_2_mc_ref.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/controller/ddr4_v2_2_mc_rd_wr.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/controller/ddr4_v2_2_mc_periodic.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/controller/ddr4_v2_2_mc_group.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/controller/ddr4_v2_2_mc_ecc_merge_enc.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/controller/ddr4_v2_2_mc_ecc_gen.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/controller/ddr4_v2_2_mc_ecc_fi_xor.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/controller/ddr4_v2_2_mc_ecc_dec_fix.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/controller/ddr4_v2_2_mc_ecc_buf.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/controller/ddr4_v2_2_mc_ecc.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/controller/ddr4_v2_2_mc_ctl.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/controller/ddr4_v2_2_mc_cmd_mux_c.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/controller/ddr4_v2_2_mc_cmd_mux_ap.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/controller/ddr4_v2_2_mc_arb_p.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/controller/ddr4_v2_2_mc_arb_mux_p.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/controller/ddr4_v2_2_mc_arb_c.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/controller/ddr4_v2_2_mc_arb_a.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/controller/ddr4_v2_2_mc_act_timer.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/controller/ddr4_v2_2_mc_act_rank.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/controller/ddr4_v2_2_mc.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/ui/ddr4_v2_2_ui_wr_data.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/ui/ddr4_v2_2_ui_rd_data.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/ui/ddr4_v2_2_ui_cmd.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/ui/ddr4_v2_2_ui.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/axi/ddr4_v2_2_axi_ar_channel.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/axi/ddr4_v2_2_axi_aw_channel.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/axi/ddr4_v2_2_axi_b_channel.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/axi/ddr4_v2_2_axi_cmd_arbiter.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/axi/ddr4_v2_2_axi_cmd_fsm.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/axi/ddr4_v2_2_axi_cmd_translator.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/axi/ddr4_v2_2_axi_fifo.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/axi/ddr4_v2_2_axi_incr_cmd.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/axi/ddr4_v2_2_axi_r_channel.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/axi/ddr4_v2_2_axi_w_channel.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/axi/ddr4_v2_2_axi_wr_cmd_fsm.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/axi/ddr4_v2_2_axi_wrap_cmd.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/axi/ddr4_v2_2_a_upsizer.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/axi/ddr4_v2_2_axi.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/axi/ddr4_v2_2_axi_register_slice.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/axi/ddr4_v2_2_axi_upsizer.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/axi/ddr4_v2_2_axic_register_slice.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/axi/ddr4_v2_2_carry_and.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/axi/ddr4_v2_2_carry_latch_and.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/axi/ddr4_v2_2_carry_latch_or.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/axi/ddr4_v2_2_carry_or.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/axi/ddr4_v2_2_command_fifo.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/axi/ddr4_v2_2_comparator.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/axi/ddr4_v2_2_comparator_sel.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/axi/ddr4_v2_2_comparator_sel_static.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/axi/ddr4_v2_2_r_upsizer.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/axi/ddr4_v2_2_w_upsizer.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/axi_ctrl/ddr4_v2_2_axi_ctrl_addr_decode.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/axi_ctrl/ddr4_v2_2_axi_ctrl_read.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/axi_ctrl/ddr4_v2_2_axi_ctrl_reg_bank.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/axi_ctrl/ddr4_v2_2_axi_ctrl_reg.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/axi_ctrl/ddr4_v2_2_axi_ctrl_top.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/axi_ctrl/ddr4_v2_2_axi_ctrl_write.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/clocking/ddr4_v2_2_infrastructure.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/cal/ddr4_v2_2_cal_xsdb_bram.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/cal/ddr4_v2_2_cal_write.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/cal/ddr4_v2_2_cal_wr_byte.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/cal/ddr4_v2_2_cal_wr_bit.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/cal/ddr4_v2_2_cal_sync.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/cal/ddr4_v2_2_cal_read.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/cal/ddr4_v2_2_cal_rd_en.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/cal/ddr4_v2_2_cal_pi.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/cal/ddr4_v2_2_cal_mc_odt.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/cal/ddr4_v2_2_cal_debug_microblaze.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/cal/ddr4_v2_2_cal_cplx_data.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/cal/ddr4_v2_2_cal_cplx.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/cal/ddr4_v2_2_cal_config_rom.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/cal/ddr4_v2_2_cal_addr_decode.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/cal/ddr4_v2_2_cal_top.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/cal/ddr4_v2_2_cal_xsdb_arbiter.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/cal/ddr4_v2_2_cal.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/cal/ddr4_v2_2_chipscope_xsdb_slave.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/cal/ddr4_v2_2_dp_AB9.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/ip_top/design_1_ddr4_0_2_ddr4.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/ip_top/design_1_ddr4_0_2_ddr4_mem_intfc.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/cal/design_1_ddr4_0_2_ddr4_cal_riu.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/ip_top/design_1_ddr4_0_2.sv" \
"../../../bd/design_1/ip/design_1_ddr4_0_2/tb/design_1_ddr4_0_2_microblaze_mcs_0.sv" \

vlog -work jtag_axi -64 -incr -mfcu  "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/map" "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/ip_top" "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/cal" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../bd/design_1/ipshared/1150/src" "+incdir+../../../../../../../../../opt/Xilinx/2025.2/data/rsb/busdef" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/map" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/rtl/ip_top" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/rtl/cal" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/5431/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/4e08/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/0de9/hdl" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/1150/src" "+incdir+/opt/Xilinx/2025.2/data/xilinx_vip/include" \
"../../../../npu_32.gen/sources_1/bd/design_1/ipshared/7f86/hdl/jtag_axi_v1_2_rfs.v" \

vlog -work xil_defaultlib -64 -incr -mfcu  "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/map" "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/ip_top" "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/cal" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../bd/design_1/ipshared/1150/src" "+incdir+../../../../../../../../../opt/Xilinx/2025.2/data/rsb/busdef" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/map" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/rtl/ip_top" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/rtl/cal" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/5431/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/4e08/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/0de9/hdl" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/1150/src" "+incdir+/opt/Xilinx/2025.2/data/xilinx_vip/include" \
"../../../bd/design_1/ip/design_1_jtag_axi_0_0/sim/design_1_jtag_axi_0_0.v" \
"../../../bd/design_1/ip/design_1_vio_0_0/sim/design_1_vio_0_0.v" \
"../../../bd/design_1/ip/design_1_smartconnect_0_0/bd_0/sim/bd_48ac.v" \

vcom -work xil_defaultlib -64 -93  \
"../../../bd/design_1/ip/design_1_smartconnect_0_0/bd_0/ip/ip_1/sim/bd_48ac_psr_aclk_0.vhd" \

vlog -work smartconnect_v1_0 -64 -incr -mfcu  -sv -L smartconnect_v1_0 -L axi_vip_v1_1_22 -L xilinx_vip "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/map" "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/ip_top" "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/cal" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../bd/design_1/ipshared/1150/src" "+incdir+../../../../../../../../../opt/Xilinx/2025.2/data/rsb/busdef" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/map" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/rtl/ip_top" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/rtl/cal" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/5431/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/4e08/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/0de9/hdl" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/1150/src" "+incdir+/opt/Xilinx/2025.2/data/xilinx_vip/include" \
"../../../../npu_32.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/sc_util_v1_0_vl_rfs.sv" \
"../../../../npu_32.gen/sources_1/bd/design_1/ipshared/0848/hdl/sc_switchboard_v1_0_vl_rfs.sv" \

vlog -work xil_defaultlib -64 -incr -mfcu  -sv -L smartconnect_v1_0 -L axi_vip_v1_1_22 -L xilinx_vip "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/map" "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/ip_top" "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/cal" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../bd/design_1/ipshared/1150/src" "+incdir+../../../../../../../../../opt/Xilinx/2025.2/data/rsb/busdef" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/map" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/rtl/ip_top" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/rtl/cal" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/5431/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/4e08/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/0de9/hdl" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/1150/src" "+incdir+/opt/Xilinx/2025.2/data/xilinx_vip/include" \
"../../../bd/design_1/ip/design_1_smartconnect_0_0/bd_0/ip/ip_2/sim/bd_48ac_arsw_0.sv" \
"../../../bd/design_1/ip/design_1_smartconnect_0_0/bd_0/ip/ip_3/sim/bd_48ac_rsw_0.sv" \
"../../../bd/design_1/ip/design_1_smartconnect_0_0/bd_0/ip/ip_4/sim/bd_48ac_awsw_0.sv" \
"../../../bd/design_1/ip/design_1_smartconnect_0_0/bd_0/ip/ip_5/sim/bd_48ac_wsw_0.sv" \
"../../../bd/design_1/ip/design_1_smartconnect_0_0/bd_0/ip/ip_6/sim/bd_48ac_bsw_0.sv" \

vlog -work smartconnect_v1_0 -64 -incr -mfcu  -sv -L smartconnect_v1_0 -L axi_vip_v1_1_22 -L xilinx_vip "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/map" "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/ip_top" "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/cal" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../bd/design_1/ipshared/1150/src" "+incdir+../../../../../../../../../opt/Xilinx/2025.2/data/rsb/busdef" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/map" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/rtl/ip_top" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/rtl/cal" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/5431/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/4e08/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/0de9/hdl" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/1150/src" "+incdir+/opt/Xilinx/2025.2/data/xilinx_vip/include" \
"../../../../npu_32.gen/sources_1/bd/design_1/ipshared/3d9a/hdl/sc_mmu_v1_0_vl_rfs.sv" \

vlog -work xil_defaultlib -64 -incr -mfcu  -sv -L smartconnect_v1_0 -L axi_vip_v1_1_22 -L xilinx_vip "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/map" "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/ip_top" "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/cal" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../bd/design_1/ipshared/1150/src" "+incdir+../../../../../../../../../opt/Xilinx/2025.2/data/rsb/busdef" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/map" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/rtl/ip_top" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/rtl/cal" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/5431/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/4e08/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/0de9/hdl" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/1150/src" "+incdir+/opt/Xilinx/2025.2/data/xilinx_vip/include" \
"../../../bd/design_1/ip/design_1_smartconnect_0_0/bd_0/ip/ip_7/sim/bd_48ac_s00mmu_0.sv" \

vlog -work smartconnect_v1_0 -64 -incr -mfcu  -sv -L smartconnect_v1_0 -L axi_vip_v1_1_22 -L xilinx_vip "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/map" "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/ip_top" "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/cal" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../bd/design_1/ipshared/1150/src" "+incdir+../../../../../../../../../opt/Xilinx/2025.2/data/rsb/busdef" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/map" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/rtl/ip_top" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/rtl/cal" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/5431/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/4e08/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/0de9/hdl" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/1150/src" "+incdir+/opt/Xilinx/2025.2/data/xilinx_vip/include" \
"../../../../npu_32.gen/sources_1/bd/design_1/ipshared/7785/hdl/sc_transaction_regulator_v1_0_vl_rfs.sv" \

vlog -work xil_defaultlib -64 -incr -mfcu  -sv -L smartconnect_v1_0 -L axi_vip_v1_1_22 -L xilinx_vip "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/map" "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/ip_top" "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/cal" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../bd/design_1/ipshared/1150/src" "+incdir+../../../../../../../../../opt/Xilinx/2025.2/data/rsb/busdef" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/map" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/rtl/ip_top" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/rtl/cal" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/5431/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/4e08/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/0de9/hdl" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/1150/src" "+incdir+/opt/Xilinx/2025.2/data/xilinx_vip/include" \
"../../../bd/design_1/ip/design_1_smartconnect_0_0/bd_0/ip/ip_8/sim/bd_48ac_s00tr_0.sv" \

vlog -work smartconnect_v1_0 -64 -incr -mfcu  -sv -L smartconnect_v1_0 -L axi_vip_v1_1_22 -L xilinx_vip "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/map" "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/ip_top" "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/cal" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../bd/design_1/ipshared/1150/src" "+incdir+../../../../../../../../../opt/Xilinx/2025.2/data/rsb/busdef" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/map" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/rtl/ip_top" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/rtl/cal" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/5431/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/4e08/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/0de9/hdl" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/1150/src" "+incdir+/opt/Xilinx/2025.2/data/xilinx_vip/include" \
"../../../../npu_32.gen/sources_1/bd/design_1/ipshared/3051/hdl/sc_si_converter_v1_0_vl_rfs.sv" \

vlog -work xil_defaultlib -64 -incr -mfcu  -sv -L smartconnect_v1_0 -L axi_vip_v1_1_22 -L xilinx_vip "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/map" "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/ip_top" "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/cal" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../bd/design_1/ipshared/1150/src" "+incdir+../../../../../../../../../opt/Xilinx/2025.2/data/rsb/busdef" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/map" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/rtl/ip_top" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/rtl/cal" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/5431/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/4e08/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/0de9/hdl" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/1150/src" "+incdir+/opt/Xilinx/2025.2/data/xilinx_vip/include" \
"../../../bd/design_1/ip/design_1_smartconnect_0_0/bd_0/ip/ip_9/sim/bd_48ac_s00sic_0.sv" \

vlog -work smartconnect_v1_0 -64 -incr -mfcu  -sv -L smartconnect_v1_0 -L axi_vip_v1_1_22 -L xilinx_vip "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/map" "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/ip_top" "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/cal" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../bd/design_1/ipshared/1150/src" "+incdir+../../../../../../../../../opt/Xilinx/2025.2/data/rsb/busdef" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/map" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/rtl/ip_top" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/rtl/cal" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/5431/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/4e08/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/0de9/hdl" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/1150/src" "+incdir+/opt/Xilinx/2025.2/data/xilinx_vip/include" \
"../../../../npu_32.gen/sources_1/bd/design_1/ipshared/852f/hdl/sc_axi2sc_v1_0_vl_rfs.sv" \

vlog -work xil_defaultlib -64 -incr -mfcu  -sv -L smartconnect_v1_0 -L axi_vip_v1_1_22 -L xilinx_vip "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/map" "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/ip_top" "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/cal" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../bd/design_1/ipshared/1150/src" "+incdir+../../../../../../../../../opt/Xilinx/2025.2/data/rsb/busdef" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/map" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/rtl/ip_top" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/rtl/cal" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/5431/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/4e08/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/0de9/hdl" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/1150/src" "+incdir+/opt/Xilinx/2025.2/data/xilinx_vip/include" \
"../../../bd/design_1/ip/design_1_smartconnect_0_0/bd_0/ip/ip_10/sim/bd_48ac_s00a2s_0.sv" \

vlog -work smartconnect_v1_0 -64 -incr -mfcu  -sv -L smartconnect_v1_0 -L axi_vip_v1_1_22 -L xilinx_vip "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/map" "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/ip_top" "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/cal" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../bd/design_1/ipshared/1150/src" "+incdir+../../../../../../../../../opt/Xilinx/2025.2/data/rsb/busdef" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/map" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/rtl/ip_top" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/rtl/cal" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/5431/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/4e08/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/0de9/hdl" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/1150/src" "+incdir+/opt/Xilinx/2025.2/data/xilinx_vip/include" \
"../../../../npu_32.gen/sources_1/bd/design_1/ipshared/00fe/hdl/sc_node_v1_0_vl_rfs.sv" \

vlog -work xil_defaultlib -64 -incr -mfcu  -sv -L smartconnect_v1_0 -L axi_vip_v1_1_22 -L xilinx_vip "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/map" "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/ip_top" "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/cal" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../bd/design_1/ipshared/1150/src" "+incdir+../../../../../../../../../opt/Xilinx/2025.2/data/rsb/busdef" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/map" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/rtl/ip_top" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/rtl/cal" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/5431/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/4e08/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/0de9/hdl" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/1150/src" "+incdir+/opt/Xilinx/2025.2/data/xilinx_vip/include" \
"../../../bd/design_1/ip/design_1_smartconnect_0_0/bd_0/ip/ip_11/sim/bd_48ac_sarn_0.sv" \
"../../../bd/design_1/ip/design_1_smartconnect_0_0/bd_0/ip/ip_12/sim/bd_48ac_srn_0.sv" \
"../../../bd/design_1/ip/design_1_smartconnect_0_0/bd_0/ip/ip_13/sim/bd_48ac_sawn_0.sv" \
"../../../bd/design_1/ip/design_1_smartconnect_0_0/bd_0/ip/ip_14/sim/bd_48ac_swn_0.sv" \
"../../../bd/design_1/ip/design_1_smartconnect_0_0/bd_0/ip/ip_15/sim/bd_48ac_sbn_0.sv" \
"../../../bd/design_1/ip/design_1_smartconnect_0_0/bd_0/ip/ip_16/sim/bd_48ac_s01mmu_0.sv" \
"../../../bd/design_1/ip/design_1_smartconnect_0_0/bd_0/ip/ip_17/sim/bd_48ac_s01tr_0.sv" \
"../../../bd/design_1/ip/design_1_smartconnect_0_0/bd_0/ip/ip_18/sim/bd_48ac_s01sic_0.sv" \
"../../../bd/design_1/ip/design_1_smartconnect_0_0/bd_0/ip/ip_19/sim/bd_48ac_s01a2s_0.sv" \
"../../../bd/design_1/ip/design_1_smartconnect_0_0/bd_0/ip/ip_20/sim/bd_48ac_sarn_1.sv" \
"../../../bd/design_1/ip/design_1_smartconnect_0_0/bd_0/ip/ip_21/sim/bd_48ac_srn_1.sv" \
"../../../bd/design_1/ip/design_1_smartconnect_0_0/bd_0/ip/ip_22/sim/bd_48ac_sawn_1.sv" \
"../../../bd/design_1/ip/design_1_smartconnect_0_0/bd_0/ip/ip_23/sim/bd_48ac_swn_1.sv" \
"../../../bd/design_1/ip/design_1_smartconnect_0_0/bd_0/ip/ip_24/sim/bd_48ac_sbn_1.sv" \

vlog -work smartconnect_v1_0 -64 -incr -mfcu  -sv -L smartconnect_v1_0 -L axi_vip_v1_1_22 -L xilinx_vip "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/map" "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/ip_top" "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/cal" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../bd/design_1/ipshared/1150/src" "+incdir+../../../../../../../../../opt/Xilinx/2025.2/data/rsb/busdef" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/map" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/rtl/ip_top" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/rtl/cal" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/5431/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/4e08/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/0de9/hdl" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/1150/src" "+incdir+/opt/Xilinx/2025.2/data/xilinx_vip/include" \
"../../../../npu_32.gen/sources_1/bd/design_1/ipshared/fca9/hdl/sc_sc2axi_v1_0_vl_rfs.sv" \

vlog -work xil_defaultlib -64 -incr -mfcu  -sv -L smartconnect_v1_0 -L axi_vip_v1_1_22 -L xilinx_vip "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/map" "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/ip_top" "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/cal" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../bd/design_1/ipshared/1150/src" "+incdir+../../../../../../../../../opt/Xilinx/2025.2/data/rsb/busdef" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/map" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/rtl/ip_top" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/rtl/cal" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/5431/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/4e08/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/0de9/hdl" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/1150/src" "+incdir+/opt/Xilinx/2025.2/data/xilinx_vip/include" \
"../../../bd/design_1/ip/design_1_smartconnect_0_0/bd_0/ip/ip_25/sim/bd_48ac_m00s2a_0.sv" \
"../../../bd/design_1/ip/design_1_smartconnect_0_0/bd_0/ip/ip_26/sim/bd_48ac_m00arn_0.sv" \
"../../../bd/design_1/ip/design_1_smartconnect_0_0/bd_0/ip/ip_27/sim/bd_48ac_m00rn_0.sv" \
"../../../bd/design_1/ip/design_1_smartconnect_0_0/bd_0/ip/ip_28/sim/bd_48ac_m00awn_0.sv" \
"../../../bd/design_1/ip/design_1_smartconnect_0_0/bd_0/ip/ip_29/sim/bd_48ac_m00wn_0.sv" \
"../../../bd/design_1/ip/design_1_smartconnect_0_0/bd_0/ip/ip_30/sim/bd_48ac_m00bn_0.sv" \

vlog -work smartconnect_v1_0 -64 -incr -mfcu  -sv -L smartconnect_v1_0 -L axi_vip_v1_1_22 -L xilinx_vip "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/map" "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/ip_top" "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/cal" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../bd/design_1/ipshared/1150/src" "+incdir+../../../../../../../../../opt/Xilinx/2025.2/data/rsb/busdef" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/map" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/rtl/ip_top" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/rtl/cal" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/5431/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/4e08/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/0de9/hdl" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/1150/src" "+incdir+/opt/Xilinx/2025.2/data/xilinx_vip/include" \
"../../../../npu_32.gen/sources_1/bd/design_1/ipshared/e44a/hdl/sc_exit_v1_0_vl_rfs.sv" \

vlog -work xil_defaultlib -64 -incr -mfcu  -sv -L smartconnect_v1_0 -L axi_vip_v1_1_22 -L xilinx_vip "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/map" "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/ip_top" "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/cal" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../bd/design_1/ipshared/1150/src" "+incdir+../../../../../../../../../opt/Xilinx/2025.2/data/rsb/busdef" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/map" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/rtl/ip_top" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/rtl/cal" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/5431/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/4e08/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/0de9/hdl" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/1150/src" "+incdir+/opt/Xilinx/2025.2/data/xilinx_vip/include" \
"../../../bd/design_1/ip/design_1_smartconnect_0_0/bd_0/ip/ip_31/sim/bd_48ac_m00e_0.sv" \

vcom -work smartconnect_v1_0 -64 -93  \
"../../../../npu_32.gen/sources_1/bd/design_1/ipshared/cb42/hdl/sc_ultralite_v1_0_rfs.vhd" \

vlog -work smartconnect_v1_0 -64 -incr -mfcu  -sv -L smartconnect_v1_0 -L axi_vip_v1_1_22 -L xilinx_vip "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/map" "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/ip_top" "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/cal" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../bd/design_1/ipshared/1150/src" "+incdir+../../../../../../../../../opt/Xilinx/2025.2/data/rsb/busdef" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/map" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/rtl/ip_top" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/rtl/cal" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/5431/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/4e08/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/0de9/hdl" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/1150/src" "+incdir+/opt/Xilinx/2025.2/data/xilinx_vip/include" \
"../../../../npu_32.gen/sources_1/bd/design_1/ipshared/cb42/hdl/sc_ultralite_v1_0_rfs.sv" \

vlog -work axi_infrastructure_v1_1_0 -64 -incr -mfcu  "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/map" "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/ip_top" "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/cal" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../bd/design_1/ipshared/1150/src" "+incdir+../../../../../../../../../opt/Xilinx/2025.2/data/rsb/busdef" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/map" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/rtl/ip_top" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/rtl/cal" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/5431/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/4e08/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/0de9/hdl" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/1150/src" "+incdir+/opt/Xilinx/2025.2/data/xilinx_vip/include" \
"../../../../npu_32.gen/sources_1/bd/design_1/ipshared/ec67/hdl/axi_infrastructure_v1_1_vl_rfs.v" \

vlog -work axi_register_slice_v2_1_36 -64 -incr -mfcu  "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/map" "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/ip_top" "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/cal" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../bd/design_1/ipshared/1150/src" "+incdir+../../../../../../../../../opt/Xilinx/2025.2/data/rsb/busdef" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/map" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/rtl/ip_top" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/rtl/cal" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/5431/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/4e08/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/0de9/hdl" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/1150/src" "+incdir+/opt/Xilinx/2025.2/data/xilinx_vip/include" \
"../../../../npu_32.gen/sources_1/bd/design_1/ipshared/bc4b/hdl/axi_register_slice_v2_1_vl_rfs.v" \

vlog -work axi_vip_v1_1_22 -64 -incr -mfcu  -sv -L smartconnect_v1_0 -L axi_vip_v1_1_22 -L xilinx_vip "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/map" "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/ip_top" "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/cal" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../bd/design_1/ipshared/1150/src" "+incdir+../../../../../../../../../opt/Xilinx/2025.2/data/rsb/busdef" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/map" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/rtl/ip_top" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/rtl/cal" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/5431/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/4e08/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/0de9/hdl" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/1150/src" "+incdir+/opt/Xilinx/2025.2/data/xilinx_vip/include" \
"../../../../npu_32.gen/sources_1/bd/design_1/ipshared/b16a/hdl/axi_vip_v1_1_vl_rfs.sv" \

vlog -work xil_defaultlib -64 -incr -mfcu  -sv -L smartconnect_v1_0 -L axi_vip_v1_1_22 -L xilinx_vip "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/map" "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/ip_top" "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/cal" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../bd/design_1/ipshared/1150/src" "+incdir+../../../../../../../../../opt/Xilinx/2025.2/data/rsb/busdef" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/map" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/rtl/ip_top" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/rtl/cal" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/5431/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/4e08/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/0de9/hdl" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/1150/src" "+incdir+/opt/Xilinx/2025.2/data/xilinx_vip/include" \
"../../../bd/design_1/ip/design_1_smartconnect_0_0/sim/design_1_smartconnect_0_0.sv" \

vcom -work xil_defaultlib -64 -93  \
"../../../bd/design_1/ip/design_1_rst_ddr4_0_187M_0/sim/design_1_rst_ddr4_0_187M_0.vhd" \

vlog -work util_vector_logic_v2_0_5 -64 -incr -mfcu  "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/map" "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/ip_top" "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/cal" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../bd/design_1/ipshared/1150/src" "+incdir+../../../../../../../../../opt/Xilinx/2025.2/data/rsb/busdef" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/map" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/rtl/ip_top" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/rtl/cal" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/5431/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/4e08/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/0de9/hdl" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/1150/src" "+incdir+/opt/Xilinx/2025.2/data/xilinx_vip/include" \
"../../../../npu_32.gen/sources_1/bd/design_1/ipshared/e056/hdl/util_vector_logic_v2_0_vl_rfs.v" \

vlog -work xil_defaultlib -64 -incr -mfcu  "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/map" "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/ip_top" "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/cal" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../bd/design_1/ipshared/1150/src" "+incdir+../../../../../../../../../opt/Xilinx/2025.2/data/rsb/busdef" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/map" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/rtl/ip_top" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/rtl/cal" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/5431/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/4e08/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/0de9/hdl" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/1150/src" "+incdir+/opt/Xilinx/2025.2/data/xilinx_vip/include" \
"../../../bd/design_1/ip/design_1_util_vector_logic_0_0/sim/design_1_util_vector_logic_0_0.v" \
"../../../bd/design_1/ipshared/1150/src/ADD.v" \
"../../../bd/design_1/ipshared/1150/src/ADD_Element.v" \
"../../../bd/design_1/ipshared/1150/src/MUL.v" \
"../../../bd/design_1/ipshared/1150/src/MUL_Element.v" \
"../../../bd/design_1/ipshared/1150/src/MultiplyByQuantizedMultiplier.v" \
"../../../bd/design_1/ipshared/1150/src/MultiplyByQuantizedMultiplierSmallerThanOneExp.v" \
"../../../bd/design_1/ipshared/1150/src/SUB.v" \
"../../../bd/design_1/ipshared/1150/src/SUB_Element.v" \

vlog -work xil_defaultlib -64 -incr -mfcu  -sv -L smartconnect_v1_0 -L axi_vip_v1_1_22 -L xilinx_vip "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/map" "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/ip_top" "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/cal" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../bd/design_1/ipshared/1150/src" "+incdir+../../../../../../../../../opt/Xilinx/2025.2/data/rsb/busdef" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/map" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/rtl/ip_top" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/rtl/cal" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/5431/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/4e08/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/0de9/hdl" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/1150/src" "+incdir+/opt/Xilinx/2025.2/data/xilinx_vip/include" \
"../../../bd/design_1/ipshared/1150/src/LSU.sv" \
"../../../bd/design_1/ipshared/1150/src/PE_INT8_OS.sv" \
"../../../bd/design_1/ipshared/1150/src/SystolicArray_OS_INT8_requant_sram.sv" \
"../../../bd/design_1/ipshared/1150/src/banked_mem_1r1w.sv" \
"../../../bd/design_1/ipshared/1150/src/controller.sv" \
"../../../bd/design_1/ipshared/1150/src/desc_decoder.sv" \
"../../../bd/design_1/ipshared/1150/src/element_wise_LUT.sv" \
"../../../bd/design_1/ipshared/1150/src/fifo.sv" \
"../../../bd/design_1/ipshared/1150/src/lut_lane_mem.sv" \
"../../../bd/design_1/ipshared/1150/src/lut_vec_tflite.sv" \
"../../../bd/design_1/ipshared/1150/src/mem_bank_1r1w.sv" \
"../../../bd/design_1/ipshared/1150/src/mult_pipe.sv" \
"../../../bd/design_1/ipshared/1150/src/npu_int16.sv" \
"../../../bd/design_1/ipshared/1150/src/op_decoder.sv" \
"../../../bd/design_1/ipshared/1150/src/sram.sv" \

vlog -work xil_defaultlib -64 -incr -mfcu  "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/map" "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/ip_top" "+incdir+../../../bd/design_1/ip/design_1_ddr4_0_2/rtl/cal" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../bd/design_1/ipshared/1150/src" "+incdir+../../../../../../../../../opt/Xilinx/2025.2/data/rsb/busdef" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/ip_1/rtl/map" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/rtl/ip_top" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ip/design_1_ddr4_0_2/rtl/cal" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/5431/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/4e08/hdl/verilog" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/0de9/hdl" "+incdir+../../../../npu_32.gen/sources_1/bd/design_1/ipshared/1150/src" "+incdir+/opt/Xilinx/2025.2/data/xilinx_vip/include" \
"../../../bd/design_1/ipshared/1150/src/npu_axi_full.v" \
"../../../bd/design_1/ip/design_1_npu_axi_full_0_0/sim/design_1_npu_axi_full_0_0.v" \
"../../../bd/design_1/sim/design_1.v" \

vlog -work xil_defaultlib \
"glbl.v"

