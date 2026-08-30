vlib modelsim_lib/work
vlib modelsim_lib/msim

vlib modelsim_lib/msim/xilinx_vip
vlib modelsim_lib/msim/xpm
vlib modelsim_lib/msim/xil_defaultlib
vlib modelsim_lib/msim/axi_infrastructure_v1_1_0
vlib modelsim_lib/msim/axi_vip_v1_1_19
vlib modelsim_lib/msim/xlconstant_v1_1_9
vlib modelsim_lib/msim/lib_cdc_v1_0_3
vlib modelsim_lib/msim/proc_sys_reset_v5_0_16
vlib modelsim_lib/msim/smartconnect_v1_0
vlib modelsim_lib/msim/axi_register_slice_v2_1_33

vmap xilinx_vip modelsim_lib/msim/xilinx_vip
vmap xpm modelsim_lib/msim/xpm
vmap xil_defaultlib modelsim_lib/msim/xil_defaultlib
vmap axi_infrastructure_v1_1_0 modelsim_lib/msim/axi_infrastructure_v1_1_0
vmap axi_vip_v1_1_19 modelsim_lib/msim/axi_vip_v1_1_19
vmap xlconstant_v1_1_9 modelsim_lib/msim/xlconstant_v1_1_9
vmap lib_cdc_v1_0_3 modelsim_lib/msim/lib_cdc_v1_0_3
vmap proc_sys_reset_v5_0_16 modelsim_lib/msim/proc_sys_reset_v5_0_16
vmap smartconnect_v1_0 modelsim_lib/msim/smartconnect_v1_0
vmap axi_register_slice_v2_1_33 modelsim_lib/msim/axi_register_slice_v2_1_33

vlog -work xilinx_vip -64 -incr -mfcu  -sv -L axi_vip_v1_1_19 -L smartconnect_v1_0 -L xilinx_vip "+incdir+/tools/Xilinx/Vivado/2024.2/data/xilinx_vip/include" \
"/tools/Xilinx/Vivado/2024.2/data/xilinx_vip/hdl/axi4stream_vip_axi4streampc.sv" \
"/tools/Xilinx/Vivado/2024.2/data/xilinx_vip/hdl/axi_vip_axi4pc.sv" \
"/tools/Xilinx/Vivado/2024.2/data/xilinx_vip/hdl/xil_common_vip_pkg.sv" \
"/tools/Xilinx/Vivado/2024.2/data/xilinx_vip/hdl/axi4stream_vip_pkg.sv" \
"/tools/Xilinx/Vivado/2024.2/data/xilinx_vip/hdl/axi_vip_pkg.sv" \
"/tools/Xilinx/Vivado/2024.2/data/xilinx_vip/hdl/axi4stream_vip_if.sv" \
"/tools/Xilinx/Vivado/2024.2/data/xilinx_vip/hdl/axi_vip_if.sv" \
"/tools/Xilinx/Vivado/2024.2/data/xilinx_vip/hdl/clk_vip_if.sv" \
"/tools/Xilinx/Vivado/2024.2/data/xilinx_vip/hdl/rst_vip_if.sv" \

vlog -work xpm -64 -incr -mfcu  -sv -L axi_vip_v1_1_19 -L smartconnect_v1_0 -L xilinx_vip "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/ec67/hdl" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/f0b6/hdl/verilog" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/0127/hdl/verilog" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/3cbc" "+incdir+/tools/Xilinx/Vivado/2024.2/data/xilinx_vip/include" \
"/tools/Xilinx/Vivado/2024.2/data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv" \
"/tools/Xilinx/Vivado/2024.2/data/ip/xpm/xpm_fifo/hdl/xpm_fifo.sv" \
"/tools/Xilinx/Vivado/2024.2/data/ip/xpm/xpm_memory/hdl/xpm_memory.sv" \

vcom -work xpm -64 -93  \
"/tools/Xilinx/Vivado/2024.2/data/ip/xpm/xpm_VCOMP.vhd" \

vlog -work xil_defaultlib -64 -incr -mfcu  "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/ec67/hdl" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/f0b6/hdl/verilog" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/0127/hdl/verilog" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/3cbc" "+incdir+/tools/Xilinx/Vivado/2024.2/data/xilinx_vip/include" \
"../../../bd/tb_design/ipshared/f568/hdl/adder_master_full_v1_0_M00_AXI.v" \
"../../../bd/tb_design/ipshared/f568/hdl/adder.v" \
"../../../bd/tb_design/ip/tb_design_adder_0_3/sim/tb_design_adder_0_3.v" \

vlog -work axi_infrastructure_v1_1_0 -64 -incr -mfcu  "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/ec67/hdl" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/f0b6/hdl/verilog" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/0127/hdl/verilog" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/3cbc" "+incdir+/tools/Xilinx/Vivado/2024.2/data/xilinx_vip/include" \
"../../../../adder.gen/sources_1/bd/tb_design/ipshared/ec67/hdl/axi_infrastructure_v1_1_vl_rfs.v" \

vlog -work xil_defaultlib -64 -incr -mfcu  -sv -L axi_vip_v1_1_19 -L smartconnect_v1_0 -L xilinx_vip "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/ec67/hdl" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/f0b6/hdl/verilog" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/0127/hdl/verilog" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/3cbc" "+incdir+/tools/Xilinx/Vivado/2024.2/data/xilinx_vip/include" \
"../../../bd/tb_design/ip/tb_design_axi_vip_0_0/sim/tb_design_axi_vip_0_0_pkg.sv" \

vlog -work axi_vip_v1_1_19 -64 -incr -mfcu  -sv -L axi_vip_v1_1_19 -L smartconnect_v1_0 -L xilinx_vip "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/ec67/hdl" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/f0b6/hdl/verilog" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/0127/hdl/verilog" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/3cbc" "+incdir+/tools/Xilinx/Vivado/2024.2/data/xilinx_vip/include" \
"../../../../adder.gen/sources_1/bd/tb_design/ipshared/8c45/hdl/axi_vip_v1_1_vl_rfs.sv" \

vlog -work xil_defaultlib -64 -incr -mfcu  -sv -L axi_vip_v1_1_19 -L smartconnect_v1_0 -L xilinx_vip "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/ec67/hdl" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/f0b6/hdl/verilog" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/0127/hdl/verilog" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/3cbc" "+incdir+/tools/Xilinx/Vivado/2024.2/data/xilinx_vip/include" \
"../../../bd/tb_design/ip/tb_design_axi_vip_0_0/sim/tb_design_axi_vip_0_0.sv" \

vlog -work xil_defaultlib -64 -incr -mfcu  "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/ec67/hdl" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/f0b6/hdl/verilog" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/0127/hdl/verilog" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/3cbc" "+incdir+/tools/Xilinx/Vivado/2024.2/data/xilinx_vip/include" \
"../../../bd/tb_design/ip/tb_design_axi_smc_0/bd_0/sim/bd_5276.v" \

vlog -work xlconstant_v1_1_9 -64 -incr -mfcu  "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/ec67/hdl" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/f0b6/hdl/verilog" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/0127/hdl/verilog" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/3cbc" "+incdir+/tools/Xilinx/Vivado/2024.2/data/xilinx_vip/include" \
"../../../../adder.gen/sources_1/bd/tb_design/ipshared/e2d2/hdl/xlconstant_v1_1_vl_rfs.v" \

vlog -work xil_defaultlib -64 -incr -mfcu  "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/ec67/hdl" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/f0b6/hdl/verilog" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/0127/hdl/verilog" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/3cbc" "+incdir+/tools/Xilinx/Vivado/2024.2/data/xilinx_vip/include" \
"../../../bd/tb_design/ip/tb_design_axi_smc_0/bd_0/ip/ip_0/sim/bd_5276_one_0.v" \

vcom -work lib_cdc_v1_0_3 -64 -93  \
"../../../../adder.gen/sources_1/bd/tb_design/ipshared/2a4f/hdl/lib_cdc_v1_0_rfs.vhd" \

vcom -work proc_sys_reset_v5_0_16 -64 -93  \
"../../../../adder.gen/sources_1/bd/tb_design/ipshared/0831/hdl/proc_sys_reset_v5_0_vh_rfs.vhd" \

vcom -work xil_defaultlib -64 -93  \
"../../../bd/tb_design/ip/tb_design_axi_smc_0/bd_0/ip/ip_1/sim/bd_5276_psr_aclk_0.vhd" \

vlog -work smartconnect_v1_0 -64 -incr -mfcu  -sv -L axi_vip_v1_1_19 -L smartconnect_v1_0 -L xilinx_vip "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/ec67/hdl" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/f0b6/hdl/verilog" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/0127/hdl/verilog" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/3cbc" "+incdir+/tools/Xilinx/Vivado/2024.2/data/xilinx_vip/include" \
"../../../../adder.gen/sources_1/bd/tb_design/ipshared/f0b6/hdl/sc_util_v1_0_vl_rfs.sv" \
"../../../../adder.gen/sources_1/bd/tb_design/ipshared/f49a/hdl/sc_mmu_v1_0_vl_rfs.sv" \

vlog -work xil_defaultlib -64 -incr -mfcu  -sv -L axi_vip_v1_1_19 -L smartconnect_v1_0 -L xilinx_vip "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/ec67/hdl" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/f0b6/hdl/verilog" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/0127/hdl/verilog" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/3cbc" "+incdir+/tools/Xilinx/Vivado/2024.2/data/xilinx_vip/include" \
"../../../bd/tb_design/ip/tb_design_axi_smc_0/bd_0/ip/ip_2/sim/bd_5276_s00mmu_0.sv" \

vlog -work smartconnect_v1_0 -64 -incr -mfcu  -sv -L axi_vip_v1_1_19 -L smartconnect_v1_0 -L xilinx_vip "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/ec67/hdl" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/f0b6/hdl/verilog" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/0127/hdl/verilog" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/3cbc" "+incdir+/tools/Xilinx/Vivado/2024.2/data/xilinx_vip/include" \
"../../../../adder.gen/sources_1/bd/tb_design/ipshared/2da8/hdl/sc_transaction_regulator_v1_0_vl_rfs.sv" \

vlog -work xil_defaultlib -64 -incr -mfcu  -sv -L axi_vip_v1_1_19 -L smartconnect_v1_0 -L xilinx_vip "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/ec67/hdl" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/f0b6/hdl/verilog" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/0127/hdl/verilog" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/3cbc" "+incdir+/tools/Xilinx/Vivado/2024.2/data/xilinx_vip/include" \
"../../../bd/tb_design/ip/tb_design_axi_smc_0/bd_0/ip/ip_3/sim/bd_5276_s00tr_0.sv" \

vlog -work smartconnect_v1_0 -64 -incr -mfcu  -sv -L axi_vip_v1_1_19 -L smartconnect_v1_0 -L xilinx_vip "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/ec67/hdl" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/f0b6/hdl/verilog" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/0127/hdl/verilog" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/3cbc" "+incdir+/tools/Xilinx/Vivado/2024.2/data/xilinx_vip/include" \
"../../../../adder.gen/sources_1/bd/tb_design/ipshared/63ed/hdl/sc_si_converter_v1_0_vl_rfs.sv" \

vlog -work xil_defaultlib -64 -incr -mfcu  -sv -L axi_vip_v1_1_19 -L smartconnect_v1_0 -L xilinx_vip "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/ec67/hdl" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/f0b6/hdl/verilog" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/0127/hdl/verilog" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/3cbc" "+incdir+/tools/Xilinx/Vivado/2024.2/data/xilinx_vip/include" \
"../../../bd/tb_design/ip/tb_design_axi_smc_0/bd_0/ip/ip_4/sim/bd_5276_s00sic_0.sv" \

vlog -work smartconnect_v1_0 -64 -incr -mfcu  -sv -L axi_vip_v1_1_19 -L smartconnect_v1_0 -L xilinx_vip "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/ec67/hdl" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/f0b6/hdl/verilog" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/0127/hdl/verilog" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/3cbc" "+incdir+/tools/Xilinx/Vivado/2024.2/data/xilinx_vip/include" \
"../../../../adder.gen/sources_1/bd/tb_design/ipshared/cef3/hdl/sc_axi2sc_v1_0_vl_rfs.sv" \

vlog -work xil_defaultlib -64 -incr -mfcu  -sv -L axi_vip_v1_1_19 -L smartconnect_v1_0 -L xilinx_vip "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/ec67/hdl" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/f0b6/hdl/verilog" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/0127/hdl/verilog" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/3cbc" "+incdir+/tools/Xilinx/Vivado/2024.2/data/xilinx_vip/include" \
"../../../bd/tb_design/ip/tb_design_axi_smc_0/bd_0/ip/ip_5/sim/bd_5276_s00a2s_0.sv" \

vlog -work smartconnect_v1_0 -64 -incr -mfcu  -sv -L axi_vip_v1_1_19 -L smartconnect_v1_0 -L xilinx_vip "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/ec67/hdl" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/f0b6/hdl/verilog" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/0127/hdl/verilog" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/3cbc" "+incdir+/tools/Xilinx/Vivado/2024.2/data/xilinx_vip/include" \
"../../../../adder.gen/sources_1/bd/tb_design/ipshared/0127/hdl/sc_node_v1_0_vl_rfs.sv" \

vlog -work xil_defaultlib -64 -incr -mfcu  -sv -L axi_vip_v1_1_19 -L smartconnect_v1_0 -L xilinx_vip "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/ec67/hdl" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/f0b6/hdl/verilog" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/0127/hdl/verilog" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/3cbc" "+incdir+/tools/Xilinx/Vivado/2024.2/data/xilinx_vip/include" \
"../../../bd/tb_design/ip/tb_design_axi_smc_0/bd_0/ip/ip_6/sim/bd_5276_sarn_0.sv" \
"../../../bd/tb_design/ip/tb_design_axi_smc_0/bd_0/ip/ip_7/sim/bd_5276_srn_0.sv" \
"../../../bd/tb_design/ip/tb_design_axi_smc_0/bd_0/ip/ip_8/sim/bd_5276_sawn_0.sv" \
"../../../bd/tb_design/ip/tb_design_axi_smc_0/bd_0/ip/ip_9/sim/bd_5276_swn_0.sv" \
"../../../bd/tb_design/ip/tb_design_axi_smc_0/bd_0/ip/ip_10/sim/bd_5276_sbn_0.sv" \

vlog -work smartconnect_v1_0 -64 -incr -mfcu  -sv -L axi_vip_v1_1_19 -L smartconnect_v1_0 -L xilinx_vip "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/ec67/hdl" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/f0b6/hdl/verilog" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/0127/hdl/verilog" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/3cbc" "+incdir+/tools/Xilinx/Vivado/2024.2/data/xilinx_vip/include" \
"../../../../adder.gen/sources_1/bd/tb_design/ipshared/7f4f/hdl/sc_sc2axi_v1_0_vl_rfs.sv" \

vlog -work xil_defaultlib -64 -incr -mfcu  -sv -L axi_vip_v1_1_19 -L smartconnect_v1_0 -L xilinx_vip "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/ec67/hdl" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/f0b6/hdl/verilog" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/0127/hdl/verilog" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/3cbc" "+incdir+/tools/Xilinx/Vivado/2024.2/data/xilinx_vip/include" \
"../../../bd/tb_design/ip/tb_design_axi_smc_0/bd_0/ip/ip_11/sim/bd_5276_m00s2a_0.sv" \

vlog -work smartconnect_v1_0 -64 -incr -mfcu  -sv -L axi_vip_v1_1_19 -L smartconnect_v1_0 -L xilinx_vip "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/ec67/hdl" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/f0b6/hdl/verilog" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/0127/hdl/verilog" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/3cbc" "+incdir+/tools/Xilinx/Vivado/2024.2/data/xilinx_vip/include" \
"../../../../adder.gen/sources_1/bd/tb_design/ipshared/37bc/hdl/sc_exit_v1_0_vl_rfs.sv" \

vlog -work xil_defaultlib -64 -incr -mfcu  -sv -L axi_vip_v1_1_19 -L smartconnect_v1_0 -L xilinx_vip "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/ec67/hdl" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/f0b6/hdl/verilog" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/0127/hdl/verilog" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/3cbc" "+incdir+/tools/Xilinx/Vivado/2024.2/data/xilinx_vip/include" \
"../../../bd/tb_design/ip/tb_design_axi_smc_0/bd_0/ip/ip_12/sim/bd_5276_m00e_0.sv" \

vlog -work smartconnect_v1_0 -64 -incr -mfcu  -sv -L axi_vip_v1_1_19 -L smartconnect_v1_0 -L xilinx_vip "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/ec67/hdl" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/f0b6/hdl/verilog" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/0127/hdl/verilog" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/3cbc" "+incdir+/tools/Xilinx/Vivado/2024.2/data/xilinx_vip/include" \
"../../../../adder.gen/sources_1/bd/tb_design/ipshared/3718/hdl/sc_switchboard_v1_0_vl_rfs.sv" \

vlog -work axi_register_slice_v2_1_33 -64 -incr -mfcu  "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/ec67/hdl" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/f0b6/hdl/verilog" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/0127/hdl/verilog" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/3cbc" "+incdir+/tools/Xilinx/Vivado/2024.2/data/xilinx_vip/include" \
"../../../../adder.gen/sources_1/bd/tb_design/ipshared/3ee4/hdl/axi_register_slice_v2_1_vl_rfs.v" \

vlog -work xil_defaultlib -64 -incr -mfcu  "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/ec67/hdl" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/f0b6/hdl/verilog" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/0127/hdl/verilog" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/3cbc" "+incdir+/tools/Xilinx/Vivado/2024.2/data/xilinx_vip/include" \
"../../../bd/tb_design/ip/tb_design_axi_smc_0/sim/tb_design_axi_smc_0.v" \
"../../../bd/tb_design/ip/tb_design_clk_wiz_0/tb_design_clk_wiz_0_clk_wiz.v" \
"../../../bd/tb_design/ip/tb_design_clk_wiz_0/tb_design_clk_wiz_0.v" \

vcom -work xil_defaultlib -64 -93  \
"../../../bd/tb_design/ip/tb_design_rst_clk_wiz_100M_0/sim/tb_design_rst_clk_wiz_100M_0.vhd" \

vlog -work xil_defaultlib -64 -incr -mfcu  "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/ec67/hdl" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/f0b6/hdl/verilog" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/0127/hdl/verilog" "+incdir+../../../../adder.gen/sources_1/bd/tb_design/ipshared/3cbc" "+incdir+/tools/Xilinx/Vivado/2024.2/data/xilinx_vip/include" \
"../../../bd/tb_design/sim/tb_design.v" \

vlog -work xil_defaultlib \
"glbl.v"

