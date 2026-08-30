# TCL script generated for dram_dma_tables.bin
# Base DRAM Address: 0x6c56600

create_hw_axi_txn wr_txn_0 [get_hw_axis hw_axi_1] -type write -address 0x06C56600 -len 4 -size 32 -data {0000000000000300006ddd0000000001}
run_hw_axi [get_hw_axi_txns wr_txn_0]
create_hw_axi_txn wr_txn_1 [get_hw_axis hw_axi_1] -type write -address 0x06C56610 -len 4 -size 32 -data {0000000000000300006de00000000002}
run_hw_axi [get_hw_axi_txns wr_txn_1]
create_hw_axi_txn wr_txn_2 [get_hw_axis hw_axi_1] -type write -address 0x06C56620 -len 4 -size 32 -data {0000000000000300006de30000000004}
run_hw_axi [get_hw_axi_txns wr_txn_2]
create_hw_axi_txn wr_txn_3 [get_hw_axis hw_axi_1] -type write -address 0x06C56630 -len 4 -size 32 -data {0000000000000006006de60000000003}
run_hw_axi [get_hw_axi_txns wr_txn_3]
create_hw_axi_txn wr_txn_4 [get_hw_axis hw_axi_1] -type write -address 0x06C56640 -len 4 -size 32 -data {0000000000000400006de60600000001}
run_hw_axi [get_hw_axi_txns wr_txn_4]
create_hw_axi_txn wr_txn_5 [get_hw_axis hw_axi_1] -type write -address 0x06C56650 -len 4 -size 32 -data {0000000000000001006dea0600000002}
run_hw_axi [get_hw_axi_txns wr_txn_5]
create_hw_axi_txn wr_txn_6 [get_hw_axis hw_axi_1] -type write -address 0x06C56660 -len 4 -size 32 -data {0000000000000400006dea0700000005}
run_hw_axi [get_hw_axi_txns wr_txn_6]
