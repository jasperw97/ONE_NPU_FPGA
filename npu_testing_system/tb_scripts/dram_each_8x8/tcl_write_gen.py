import os

def bin_to_vivado_tcl(bin_path, output_tcl_path, base_address, hw_axi_node="hw_axi_1"):
    """
    Converts a .bin file containing 16-byte words into a Vivado TCL script 
    for JTAG to AXI Master DRAM writes.
    
    :param bin_path: Path to the input .bin file
    :param output_tcl_path: Path where the TCL script will be saved
    :param base_address: Starting DRAM address in hex (e.g., 0x80000000)
    :param hw_axi_node: Name of your hw_axi instance in Vivado (default: hw_axi_1)
    """
    if not os.path.exists(bin_path):
        print(f"Error: Input file '{bin_path}' not found.")
        return

    address = base_address

    with open(bin_path, "rb") as bin_file, open(output_tcl_path, "w") as tcl_file:
        tcl_file.write(f"# TCL script generated for {bin_path}\n")
        tcl_file.write(f"# Base DRAM Address: {hex(base_address)}\n\n")

        index = 0
        while True:
            # Read 16 bytes (128 bits) at a time
            chunk = bin_file.read(16)
            if not chunk:
                break  # Reached End-Of-File

            # Pad chunk with zeroes if the file size is not a multiple of 16 bytes
            if len(chunk) < 16:
                chunk = chunk.ljust(16, b'\x00')

            # Convert 16 bytes (Little-Endian) directly to a hex string
            # int.from_bytes with 'little' preserves byte-ordering to hex
            word_val = int.from_bytes(chunk, byteorder="little")
            data_hex = f"{word_val:032x}"

            txn_name = f"wr_txn_{index}"
            addr_hex = f"0x{address:08X}"

            # Write Vivado hw_axi TCL commands
            # 16 bytes = 128 bits (len = 1 for a single 128-bit transfer)
            tcl_file.write(
                f"create_hw_axi_txn {txn_name} [get_hw_axis {hw_axi_node}] "
                f"-type write -address {addr_hex} -len 4 -size 32 "
                f"-data {{{data_hex}}}\n"
            )
            tcl_file.write(f"run_hw_axi [get_hw_axi_txns {txn_name}]\n")

            address += 16
            index += 1

    print(f"Done! Generated {index} AXI transactions in '{output_tcl_path}'.")

# ==========================================
# Example Usage
# ==========================================
if __name__ == "__main__":
    # Specify your inputs here:
    BIN_FILE = "descriptors.bin"
    OUTPUT_TCL = "desc_write_dram.tcl"
    DRAM_BASE_ADDR = 0x06ACFC00  # Adjust to your DRAM base address
    HW_AXI_INSTANCE = "hw_axi_1"  # Default name in Vivado HW Manager

    bin_to_vivado_tcl(
        bin_path=BIN_FILE,
        output_tcl_path=OUTPUT_TCL,
        base_address=DRAM_BASE_ADDR,
        hw_axi_node=HW_AXI_INSTANCE
    )