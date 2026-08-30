# TCL script generated for dram_instructions.bin
# Base DRAM Address: 0x4c4b400

create_hw_axi_txn wr_txn_0 [get_hw_axis hw_axi_1] -type write -address 0x04C4B400 -len 4 -size 32 -data {00000000000000000006000400000000}
run_hw_axi [get_hw_axi_txns wr_txn_0]
create_hw_axi_txn wr_txn_1 [get_hw_axis hw_axi_1] -type write -address 0x04C4B410 -len 4 -size 32 -data {00030000000000206572000a20000000}
run_hw_axi [get_hw_axi_txns wr_txn_1]
create_hw_axi_txn wr_txn_2 [get_hw_axis hw_axi_1] -type write -address 0x04C4B420 -len 4 -size 32 -data {00000000000000000004000000000028}
run_hw_axi [get_hw_axi_txns wr_txn_2]
