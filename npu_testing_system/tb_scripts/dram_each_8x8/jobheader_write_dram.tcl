# TCL script generated for dram_jobs.bin
# Base DRAM Address: 0x5b8d800

create_hw_axi_txn wr_txn_0 [get_hw_axis hw_axi_1] -type write -address 0x05B8D800 -len 4 -size 32 -data {000000000000002dc6c0000200080001}
run_hw_axi [get_hw_axi_txns wr_txn_0]
create_hw_axi_txn wr_txn_1 [get_hw_axis hw_axi_1] -type write -address 0x05B8D810 -len 4 -size 32 -data {000200080001002dc9c0800500300003}
run_hw_axi [get_hw_axi_txns wr_txn_1]
