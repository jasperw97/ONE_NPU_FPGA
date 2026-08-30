`timescale 1ns/1ps
`default_nettype none

// ============================================================
// mem_bank_1r1w
// ------------------------------------------------------------
// Single memory bank.
//
// Default mode:
//   FPGA / simulation mode using clean simple-dual-port BRAM style.
//
// Behavior:
//   - 1 read port
//   - 1 write port
//   - synchronous write
//   - synchronous read
//   - read latency = 1 cycle
//   - if read and write the same address in the same cycle,
//     rdata returns the OLD data.
//
// SRAM_MACRO mode:
//   Use the ARM sram_dp_hde 4096x16 true-dual-port SRAM macro.
// ============================================================

`ifdef SRAM_MACRO
`define MEM_BANK_1R1W_USE_SRAM_MACRO
`endif

module mem_bank_1r1w #(
    parameter integer DATA_WIDTH = 16,
    parameter integer ADDR_WIDTH = 12
)(
    input  wire                    clk,
    input  wire                    rst_n,

    // Read port
    input  wire                    ren,
    input  wire [ADDR_WIDTH-1:0]   raddr,
    output wire [DATA_WIDTH-1:0]   rdata,

    // Write port
    input  wire                    wen,
    input  wire [ADDR_WIDTH-1:0]   waddr,
    input  wire [DATA_WIDTH-1:0]   wdata
);

`ifdef MEM_BANK_1R1W_USE_SRAM_MACRO

    // ========================================================
    // SRAM macro mode
    // --------------------------------------------------------
    // sram_dp_hde is 4096x16, active-low CEN/WEN, 1-cycle read.
    // Port A is used as read-only; port B is used as write-only.
    //
    // NOTE:
    //   The macro model reports X on read/write contention to the
    //   same address. Controllers should avoid that case.
    // ========================================================

    localparam integer MACRO_DATA_WIDTH = 16;
    localparam integer MACRO_ADDR_WIDTH = 12;

    wire [MACRO_DATA_WIDTH-1:0] macro_qa;
    wire [MACRO_ADDR_WIDTH-1:0] macro_aa;
    wire [MACRO_ADDR_WIDTH-1:0] macro_ab;

    assign macro_aa = raddr[MACRO_ADDR_WIDTH-1:0];
    assign macro_ab = waddr[MACRO_ADDR_WIDTH-1:0];
    assign rdata    = macro_qa[DATA_WIDTH-1:0];

    // Normal-mode margin/test tie-offs. Confirm these with the
    // memory compiler datasheet before tapeout signoff.
    localparam [2:0] SRAM_EMA  = 3'b010;
    localparam [1:0] SRAM_EMAW = 2'b00;
    localparam       SRAM_EMAS = 1'b0;

    sram_dp_hde u_sram_dp_hde (
        .CENYA   (),
        .WENYA   (),
        .AYA     (),
        .DYA     (),
        .CENYB   (),
        .WENYB   (),
        .AYB     (),
        .DYB     (),
        .QA      (macro_qa),
        .QB      (),

        .CLKA    (clk),
        .CENA    (~ren),
        .WENA    (1'b1),
        .AA      (macro_aa),
        .DA      ({MACRO_DATA_WIDTH{1'b0}}),

        .CLKB    (clk),
        .CENB    (~wen),
        .WENB    (~wen),
        .AB      (macro_ab),
        .DB      (wdata[MACRO_DATA_WIDTH-1:0]),

        .EMAA    (SRAM_EMA),
        .EMAWA   (SRAM_EMAW),
        .EMASA   (SRAM_EMAS),
        .EMAB    (SRAM_EMA),
        .EMAWB   (SRAM_EMAW),
        .EMASB   (SRAM_EMAS),

        .TENA    (1'b1),
        .BENA    (1'b1),
        .TCENA   (1'b1),
        .TWENA   (1'b1),
        .TAA     ({MACRO_ADDR_WIDTH{1'b0}}),
        .TDA     ({MACRO_DATA_WIDTH{1'b0}}),
        .TQA     ({MACRO_DATA_WIDTH{1'b0}}),

        .TENB    (1'b1),
        .BENB    (1'b1),
        .TCENB   (1'b1),
        .TWENB   (1'b1),
        .TAB     ({MACRO_ADDR_WIDTH{1'b0}}),
        .TDB     ({MACRO_DATA_WIDTH{1'b0}}),
        .TQB     ({MACRO_DATA_WIDTH{1'b0}}),

        .RET1N   (1'b1),
        .STOVA   (1'b0),
        .STOVB   (1'b0),
        .COLLDISN(1'b1)
    );

`ifndef SYNTHESIS
    initial begin
        if (DATA_WIDTH != MACRO_DATA_WIDTH || ADDR_WIDTH != MACRO_ADDR_WIDTH) begin
            $error("mem_bank_1r1w SRAM_MACRO mode requires DATA_WIDTH=16 and ADDR_WIDTH=12.");
        end
    end

    always @(posedge clk) begin
        if (rst_n && ren && wen && (raddr == waddr)) begin
            $warning("[mem_bank_1r1w] SRAM macro read/write same-address contention at %0t addr=%0d", $time, raddr);
        end
    end
`endif

`else

    // ========================================================
    // FPGA / behavioral BRAM mode
    // --------------------------------------------------------
    // This is a clean simple-dual-port RAM coding style:
    //   - one write port
    //   - one read port
    //   - synchronous read
    //
    // Most FPGA tools can infer BRAM from this style if depth
    // and width are large enough.
    // ========================================================

    localparam integer DEPTH = (1 << ADDR_WIDTH);

    reg [DATA_WIDTH-1:0] rdata_q;
    assign rdata = rdata_q;

    // Xilinx Vivado hint: ram_style = "block"
    // Intel Quartus hint: ramstyle = "M20K"
    (* ram_style = "block", ramstyle = "M20K" *)
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    always @(posedge clk) begin
        if (wen) begin
            mem[waddr] <= wdata;
        end

        if (ren) begin
            rdata_q <= mem[raddr];
        end
    end

`endif

endmodule

`undef MEM_BANK_1R1W_USE_SRAM_MACRO
`default_nettype wire
