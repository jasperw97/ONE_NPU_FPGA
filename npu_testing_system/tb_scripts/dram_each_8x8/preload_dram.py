from tcl_write_gen import bin_to_vivado_tcl

##Descriptors
BIN_FILE = "dram_descriptors.bin"
OUTPUT_TCL = "desc_write_dram.tcl"
DRAM_BASE_ADDR = 0x06ACFC00  # Adjust to your DRAM base address
HW_AXI_INSTANCE = "hw_axi_1"  # Default name in Vivado HW Manager

bin_to_vivado_tcl(
    bin_path=BIN_FILE,
    output_tcl_path=OUTPUT_TCL,
    base_address=DRAM_BASE_ADDR,
    hw_axi_node=HW_AXI_INSTANCE
)

##Instructions
BIN_FILE = "dram_instructions.bin"
OUTPUT_TCL = "inst_write_dram.tcl"
DRAM_BASE_ADDR = 0x4C4B400  # Adjust to your DRAM base address
HW_AXI_INSTANCE = "hw_axi_1"  # Default name in Vivado HW Manager
bin_to_vivado_tcl(
    bin_path=BIN_FILE,
    output_tcl_path=OUTPUT_TCL,
    base_address=DRAM_BASE_ADDR,
    hw_axi_node=HW_AXI_INSTANCE
)


##dma table
BIN_FILE = "dram_dma_tables.bin"
OUTPUT_TCL = "dmatable_write_dram.tcl"
DRAM_BASE_ADDR = 0x6C56600  # Adjust to your DRAM base address
HW_AXI_INSTANCE = "hw_axi_1"  # Default name in Vivado HW Manager

bin_to_vivado_tcl(
    bin_path=BIN_FILE,
    output_tcl_path=OUTPUT_TCL,
    base_address=DRAM_BASE_ADDR,
    hw_axi_node=HW_AXI_INSTANCE
)
##tensors
BIN_FILE = "dram_tensor_payloads.bin"
OUTPUT_TCL = "tensor_write_dram.tcl"
DRAM_BASE_ADDR = 0x6DDD000  # Adjust to your DRAM base address
HW_AXI_INSTANCE = "hw_axi_1"  # Default name in Vivado HW Manager

bin_to_vivado_tcl(
    bin_path=BIN_FILE,
    output_tcl_path=OUTPUT_TCL,
    base_address=DRAM_BASE_ADDR,
    hw_axi_node=HW_AXI_INSTANCE
)
##job header
BIN_FILE = "dram_jobs.bin"
OUTPUT_TCL = "jobheader_write_dram.tcl"
DRAM_BASE_ADDR = 0x5B8D800  # Adjust to your DRAM base address
HW_AXI_INSTANCE = "hw_axi_1"  # Default name in Vivado HW Manager

bin_to_vivado_tcl(
    bin_path=BIN_FILE,
    output_tcl_path=OUTPUT_TCL,
    base_address=DRAM_BASE_ADDR,
    hw_axi_node=HW_AXI_INSTANCE
)

##luts
BIN_FILE = "dram_luts.bin"
OUTPUT_TCL = "luts_write_dram.tcl"
DRAM_BASE_ADDR = 0x1E84800  # Adjust to your DRAM base address
HW_AXI_INSTANCE = "hw_axi_1"  # Default name in Vivado HW Manager

bin_to_vivado_tcl(
    bin_path=BIN_FILE,
    output_tcl_path=OUTPUT_TCL,
    base_address=DRAM_BASE_ADDR,
    hw_axi_node=HW_AXI_INSTANCE
)