import struct
import sys
import argparse

BYTES_PER_WORD = 16
LANES = 8

def compare_results(hw_bin_path: str = "hw_results.bin", golden_bin_path: str = "golden_result_sv.bin", max_mismatches: int = 20):
    print("=" * 70)
    print(" NPU HARDWARE vs. GOLDEN REFERENCE CHECKER")
    print("=" * 70)
    print(f"[INFO] Hardware Output File : {hw_bin_path}")
    print(f"[INFO] Golden Reference File: {golden_bin_path}")
    
    try:
        with open(hw_bin_path, "rb") as f:
            hw_bytes = f.read()
    except FileNotFoundError:
        print(f"[ERROR] Could not open hardware file '{hw_bin_path}'. Make sure readback completed.")
        return

    try:
        with open(golden_bin_path, "rb") as f:
            golden_bytes = f.read()
    except FileNotFoundError:
        print(f"[ERROR] Could not open golden file '{golden_bin_path}'. Run 'golden_builder.py' first.")
        return

    hw_words = len(hw_bytes) // BYTES_PER_WORD
    golden_words = len(golden_bytes) // BYTES_PER_WORD

    print(f"[INFO] File Sizes -> HW: {len(hw_bytes)} B ({hw_words} words) | Golden: {len(golden_bytes)} B ({golden_words} words)")

    if len(hw_bytes) != len(golden_bytes):
        print(f"\033[33m[WARNING] File size mismatch between HW and Golden files!\033[0m")

    total_words_to_check = min(hw_words, golden_words)
    total_mismatches = 0
    total_elements_checked = total_words_to_check * LANES

    print("-" * 70)

    for word_idx in range(total_words_to_check):
        hw_chunk = hw_bytes[word_idx * BYTES_PER_WORD : (word_idx + 1) * BYTES_PER_WORD]
        gold_chunk = golden_bytes[word_idx * BYTES_PER_WORD : (word_idx + 1) * BYTES_PER_WORD]

        if hw_chunk != gold_chunk:
            # Unpack 16-bit signed shorts (Little-Endian)
            hw_vals = struct.unpack("<8h", hw_chunk)
            gold_vals = struct.unpack("<8h", gold_chunk)

            for lane in range(LANES):
                if hw_vals[lane] != gold_vals[lane]:
                    total_mismatches += 1
                    if total_mismatches <= max_mismatches:
                        print(
                            f"\033[31m[MISMATCH]\033[0m Word {word_idx:4d} (Row {word_idx:4d}), Lane {lane}: "
                            f"HW = {hw_vals[lane]:6d} (0x{hw_vals[lane] & 0xFFFF:04X}) | "
                            f"GOLDEN = {gold_vals[lane]:6d} (0x{gold_vals[lane] & 0xFFFF:04X})"
                        )
                    elif total_mismatches == max_mismatches + 1:
                        print(f"\033[33m[INFO] Reached max error log limit ({max_mismatches}). Suppressing further mismatch logs...\033[0m")

    print("-" * 70)

    if total_mismatches == 0 and hw_words == golden_words:
        print(f"\033[32m[PASS] SUCCESS! All {total_elements_checked} values match Golden Reference perfectly!\033[0m")
    else:
        match_rate = ((total_elements_checked - total_mismatches) / total_elements_checked) * 100 if total_elements_checked > 0 else 0
        print(f"\033[31m[FAIL] Total Mismatches: {total_mismatches} / {total_elements_checked} elements ({match_rate:.2f}% match rate)\033[0m")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Compare HW result .bin against Golden reference .bin")
    parser.add_argument("--hw", type=str, default="hw_results.bin", help="Path to hardware result binary")
    parser.add_argument("--golden", type=str, default="golden_sv.bin", help="Path to golden reference binary")
    parser.add_argument("--max_errors", type=int, default=20, help="Max mismatches to display")
    args = parser.parse_args()

    compare_results(args.hw, args.golden, args.max_errors)