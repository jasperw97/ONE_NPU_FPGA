import argparse
import sys

BYTES_PER_WORD = 16

def generate_readback_tcl(
    base_address_word: int,
    total_words: int,
    tcl_output_path: str = "dump_hw_result.tcl",
    bin_output_name: str = "hw_result.bin",
):
    if total_words <= 0:
        print("[ERROR] Total words must be greater than 0.")
        sys.exit(1)

    base_address_byte = base_address_word * BYTES_PER_WORD
    total_bytes = total_words * BYTES_PER_WORD

    print(f"[READBACK GEN] Target Base (Word): {base_address_word} -> Byte Address: 0x{base_address_byte:08X}")
    print(f"[READBACK GEN] Target Size: {total_words} words ({total_bytes} bytes).")

    # Write explicit line-by-line Tcl transactions
    with open(tcl_output_path, "w") as f:
        f.write("# ==================================================================\n")
        f.write("# Auto-generated Vivado Tcl Script: Line-by-Line Hardware Readback\n")
        f.write(f"# Base Address: 0x{base_address_byte:08X} (Word Base: {base_address_word})\n")
        f.write(f"# Total Words: {total_words} 128-bit words ({total_bytes} bytes)\n")
        f.write("# ==================================================================\n\n")

        f.write("set jtag_axi [get_hw_axis hw_axi_1]\n")
        f.write(f'set fp [open "{bin_output_name}" w]\n')
        f.write("fconfigure $fp -translation binary\n\n")
        
        f.write(f'puts "\\[INFO\\] Reading {total_words} words from DDR starting at 0x{base_address_byte:08X}..."\n\n')

        curr_addr = base_address_byte
        for i in range(total_words):
            txn_name = f"txn_rd_{curr_addr:08X}"
            addr_hex = f"{curr_addr:08X}"

            f.write(f"# --- Word {i} / {total_words - 1} @ 0x{addr_hex} ---\n")
            f.write(f"create_hw_axi_txn -force {txn_name} $jtag_axi -address 0x{addr_hex} -len 4 -type read\n")
            f.write(f"run_hw_axi {txn_name}\n")
            
            # Fetch read data
            f.write(f"set raw_hex [get_property DATA [get_hw_axi_txns {txn_name}]]\n")
            
            f.write(f'puts "\\[READBACK\\] Addr 0x{addr_hex} = 0x$raw_hex"\n')
            
            # Reverses 32 hex characters (16 bytes) for Little-Endian .bin format
            f.write('set rev_hex ""\n')
            f.write("for {set b 30} {$b >= 0} {incr b -2} {\n")
            f.write("    append rev_hex [string range $raw_hex $b [expr {$b + 1}]]\n")
            f.write("}\n")
            f.write("puts -nonewline $fp [binary format H* $rev_hex]\n\n")

            curr_addr += BYTES_PER_WORD

        f.write("close $fp\n")
        f.write(f'puts "\\[SUCCESS\\] Readback complete! Wrote {total_bytes} bytes to {bin_output_name}"\n')

    print(f"[SUCCESS] Generated line-by-line readback Tcl script at '{tcl_output_path}'.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate Vivado Tcl script to read AXI DRAM.")
    
    # Set your default starting word address here (3,000,000)
    parser.add_argument("--base", type=int, default=3000000, help="Starting word address in DRAM.")
    parser.add_argument("--words", type=int, required=True, help="Total number of 128-bit words to read.")
    parser.add_argument("--out_tcl", type=str, default="dump_hw_result.tcl", help="Output Tcl script name.")
    parser.add_argument("--out_bin", type=str, default="hw_result.bin", help="Target binary file name.")

    args = parser.parse_args()

    generate_readback_tcl(
        base_address_word=args.base,
        total_words=args.words,
        tcl_output_path=args.out_tcl,
        bin_output_name=args.out_bin
    )