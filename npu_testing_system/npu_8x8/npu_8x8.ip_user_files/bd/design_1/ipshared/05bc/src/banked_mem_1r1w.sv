`timescale 1ns/1ps
`default_nettype none

// ============================================================
// banked_mem_1r1w
// ------------------------------------------------------------
// Banked memory wrapper.
//
// External view:
//   one wide memory word, e.g.
//   64 lanes x 16-bit = 1024-bit
//
// Internal structure:
//   LANES independent 1R1W memory banks.
//   Each bank stores one LANE_WIDTH slice.
//
// Behavior:
//   - common read address for all banks
//   - common write address for all banks
//   - per-lane write enable
//   - synchronous read
//   - read latency = 1 cycle
//
// This file is implementation-neutral:
//   - FPGA mode is handled inside mem_bank_1r1w
//   - ASIC SRAM mode is handled inside mem_bank_1r1w
// ============================================================

module banked_mem_1r1w #(
    parameter integer LANES      = 64,
    parameter integer LANE_WIDTH = 16,
    parameter integer ADDR_WIDTH = 10
)(
    input  wire                             clk,
    input  wire                             rst_n,

    // Read port
    input  wire                             ren,
    input  wire [ADDR_WIDTH-1:0]            raddr,
    output wire [LANES*LANE_WIDTH-1:0]      rdata,

    // Write port
    input  wire                             wen,
    input  wire [LANES-1:0]                 lane_wen,
    input  wire [ADDR_WIDTH-1:0]            waddr,
    input  wire [LANES*LANE_WIDTH-1:0]      wdata
);

    genvar b;

    generate
        for (b = 0; b < LANES; b = b + 1) begin : GEN_BANK
            mem_bank_1r1w #(
                .DATA_WIDTH (LANE_WIDTH),
                .ADDR_WIDTH (ADDR_WIDTH)
            ) u_mem_bank (
                .clk   (clk),
                .rst_n (rst_n),

                .ren   (ren),
                .raddr (raddr),
                .rdata (rdata[b*LANE_WIDTH +: LANE_WIDTH]),

                .wen   (wen & lane_wen[b]),
                .waddr (waddr),
                .wdata (wdata[b*LANE_WIDTH +: LANE_WIDTH])
            );
        end
    endgenerate

endmodule

`default_nettype wire