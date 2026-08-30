`timescale 1ns/1ps
`default_nettype none
`include "params.vh"

// ============================================================
// sram_unit
// ------------------------------------------------------------
// Tensor SRAM banks use generic bank-selected ports:
//   read port 0: src0, primary source / previous result / LSU store
//   read port 1: src1, secondary source, currently SA weight
//   write port : dst, LSU tensor load or compute result destination
//
// LUT storage remains separate because EXP/RCP need independent
// table read ports. Descriptor and instruction storage are also
// separate targets, not part of src/dst tensor bank ids.
// ============================================================

module sram_unit #(
    parameter integer ADDR_WIDTH = 12,
    parameter integer NUM_SRAM_BANKS = 8,
    parameter integer BANK_ID_WIDTH = 3
)(
    input  wire                                clk,
    input  wire                                rst_n,

    // Generic tensor read port 0
    input  wire [BANK_ID_WIDTH-1:0]            src0_bank,
    input  wire                                src0_ren,
    input  wire [ADDR_WIDTH-1:0]               src0_addr,
    output wire [`SRAM_WIDTH_O-1:0]            src0_o,

    // Generic tensor read port 1
    input  wire [BANK_ID_WIDTH-1:0]            src1_bank,
    input  wire                                src1_ren,
    input  wire [ADDR_WIDTH-1:0]               src1_addr,
    output wire [`SRAM_WIDTH_O-1:0]            src1_o,

    // Generic tensor write port
    input  wire [BANK_ID_WIDTH-1:0]            dst_bank,
    input  wire [ADDR_WIDTH-1:0]               dst_waddr,
    input  wire [`SRAM_WIDTH_O-1:0]            dst_data_i,
    input  wire                                dst_we,
    //Tensor Write Port with replicated signals to reduce fanout
    // input  wire [BANK_ID_WIDTH-1:0]            dst_bank_a,
    // input  wire [BANK_ID_WIDTH-1:0]            dst_bank_b,
    // input  wire [BANK_ID_WIDTH-1:0]            dst_bank_c,
    // input  wire [BANK_ID_WIDTH-1:0]            dst_bank_d,
    // input  wire [ADDR_WIDTH-1:0]               dst_waddr_a,
    // input  wire [ADDR_WIDTH-1:0]               dst_waddr_b,
    // input  wire [ADDR_WIDTH-1:0]               dst_waddr_c,
    // input  wire [ADDR_WIDTH-1:0]               dst_waddr_d,
    // input  wire                                dst_we_a,
    // input  wire                                dst_we_b,
    // input  wire                                dst_we_c,
    // input  wire                                dst_we_d,

    // LUT preload port
    input  wire [ADDR_WIDTH-1:0]               pre_lut_addr,
    input  wire [`SRAM_WIDTH_O-1:0]            pre_lut_data,
    input  wire                                pre_lut_we,

    // EXP LUT read port
    output wire [`SRAM_WIDTH_O-1:0]            exp_lut_sram_data_o,
    input  wire                                exp_lut_sram_en,
    input  wire [ADDR_WIDTH-1:0]               exp_lut_data_addr,

    // Reciprocal LUT read port
    output wire [`SRAM_WIDTH_O-1:0]            reciprocal_lut_sram_data_o,
    input  wire                                reciprocal_lut_sram_en,
    input  wire [ADDR_WIDTH-1:0]               reciprocal_lut_data_addr,

    // Instruction SRAM preload/read port
    input  wire [ADDR_WIDTH-1:0]               pre_inst_addr,
    input  wire [`SRAM_WIDTH_O-1:0]            pre_inst_data,
    input  wire                                pre_inst_we,
    output wire [`SRAM_WIDTH_O-1:0]            inst_sram_data_o,
    input  wire                                inst_sram_en,
    input  wire [ADDR_WIDTH-1:0]               inst_sram_addr,

    // Quant descriptor SRAM preload/read port
    input  wire [ADDR_WIDTH-1:0]               pre_desc_addr,
    input  wire [`SRAM_WIDTH_O-1:0]            pre_desc_data,
    input  wire                                pre_desc_we,
    output wire [`SRAM_WIDTH_O-1:0]            desc_sram_data_o,
    input  wire                                desc_sram_en,
    input  wire [ADDR_WIDTH-1:0]               desc_sram_addr

);

    localparam integer LANE_WIDTH = `INT16_SIZE;
    localparam integer LANES      = `LANES;
    localparam int QUARTER = NUM_SRAM_BANKS / 4;

    wire [LANES-1:0] all_lane_wen;
    assign all_lane_wen = {LANES{1'b1}};

    logic [NUM_SRAM_BANKS-1:0] bank_wen;
    logic [NUM_SRAM_BANKS-1:0] bank_ren;
    logic [ADDR_WIDTH-1:0]    bank_waddr [0:NUM_SRAM_BANKS-1];
    logic [ADDR_WIDTH-1:0]    bank_raddr [0:NUM_SRAM_BANKS-1];
    logic [`SRAM_WIDTH_O-1:0] bank_wdata [0:NUM_SRAM_BANKS-1];

    wire [`SRAM_WIDTH_O-1:0] bank_rdata [0:NUM_SRAM_BANKS-1];

    logic [BANK_ID_WIDTH-1:0] src0_read_bank_q;
    logic [BANK_ID_WIDTH-1:0] src1_read_bank_q;


    integer bi;
    always_comb begin
        for (bi = 0; bi < NUM_SRAM_BANKS; bi = bi + 1) begin
            bank_wen[bi]   = 1'b0;
            bank_ren[bi]   = 1'b0;
            bank_waddr[bi] = '0;
            bank_raddr[bi] = '0;
            bank_wdata[bi] = '0;

            if (src0_ren && (src0_bank == bi)) begin
                bank_ren[bi]   = 1'b1;
                bank_raddr[bi] = src0_addr;
            end else if (src1_ren && (src1_bank == bi)) begin
                bank_ren[bi]   = 1'b1;
                bank_raddr[bi] = src1_addr;
            end

            if (dst_we && (dst_bank == bi)) begin
                bank_wen[bi]   = 1'b1;
                bank_waddr[bi] = dst_waddr;
                bank_wdata[bi] = dst_data_i;
            end
        end
        // // REGION A: 01
        // for (int bi = 0; bi < QUARTER; bi = bi + 1) begin
        //     if (dst_we_a && (dst_bank_a == bi)) begin
        //         bank_wen[bi]   = 1'b1;
        //         bank_waddr[bi] = dst_waddr_a;
        //         bank_wdata[bi] = dst_data_i;
        //     end
        // end

        // // REGION B: 23
        // for (int bi = QUARTER; bi < QUARTER*2; bi = bi + 1) begin
        //     if (dst_we_b && (dst_bank_b == bi)) begin
        //         bank_wen[bi]   = 1'b1;
        //         bank_waddr[bi] = dst_waddr_b;
        //         bank_wdata[bi] = dst_data_i;
        //     end
        // end

        // // REGION C: 45
        // for (int bi = QUARTER*2; bi < QUARTER*3; bi = bi + 1) begin
        //     if (dst_we_c && (dst_bank_c == bi)) begin
        //         bank_wen[bi]   = 1'b1;
        //         bank_waddr[bi] = dst_waddr_c;
        //         bank_wdata[bi] = dst_data_i;
        //     end
        // end

        // // REGION D: 67
        // for (int bi = QUARTER*3; bi < NUM_SRAM_BANKS; bi = bi + 1) begin
        //     if (dst_we_d && (dst_bank_d == bi)) begin
        //         bank_wen[bi]   = 1'b1;
        //         bank_waddr[bi] = dst_waddr_d;
        //         bank_wdata[bi] = dst_data_i;
        //     end
        // end

    end

    genvar b;
    generate
        for (b = 0; b < NUM_SRAM_BANKS; b = b + 1) begin : GEN_GENERAL_BANKS
            banked_mem_1r1w #(
                .LANES      (LANES),
                .LANE_WIDTH (LANE_WIDTH),
                .ADDR_WIDTH (ADDR_WIDTH)
            ) u_tensor_bank (
                .clk      (clk),
                .rst_n    (rst_n),
                .ren      (bank_ren[b]),
                .raddr    (bank_raddr[b]),
                .rdata    (bank_rdata[b]),
                .wen      (bank_wen[b]),
                .lane_wen (all_lane_wen),
                .waddr    (bank_waddr[b]),
                .wdata    (bank_wdata[b])
            );
        end
    endgenerate

    // SRAM read data is one cycle after ren/raddr, so delay bank select too.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            src0_read_bank_q <= 0;
            src1_read_bank_q <= 0;
        end else begin
            if (src0_ren) src0_read_bank_q <= src0_bank;
            if (src1_ren)     src1_read_bank_q <= src1_bank;
        end
    end

    assign src0_o   = bank_rdata[src0_read_bank_q];
    assign src1_o   = bank_rdata[src1_read_bank_q];

    // Commented out part below was an attempt to pipieline tensor banks, needs further work with other modules to agree on the latency
    // //Pipelining Tensor Banks
    // // ------------------------------------------------------------
    // // BRAM Output Registers (Vivado will absorb these natively)
    // // ------------------------------------------------------------
    // logic [`SRAM_WIDTH_O-1:0] bank_rdata_pipe [0:NUM_SRAM_BANKS-1];

    // always_ff @(posedge clk) begin
    //     for (int i = 0; i < NUM_SRAM_BANKS; i = i + 1) begin
    //         bank_rdata_pipe[i] <= bank_rdata[i];
    //     end
    // end

    // // ------------------------------------------------------------
    // // Delayed Bank Select (Now 2 cycles to match the pipeline)
    // // ------------------------------------------------------------
    // logic [BANK_ID_WIDTH-1:0] src0_read_bank_q1, src0_read_bank_q2;
    // logic [BANK_ID_WIDTH-1:0] src1_read_bank_q1, src1_read_bank_q2;

    // always @(posedge clk or negedge rst_n) begin
    //     if (!rst_n) begin
    //         src0_read_bank_q1 <= '0;
    //         src1_read_bank_q1 <= '0;
    //         src0_read_bank_q2 <= '0;
    //         src1_read_bank_q2 <= '0;
    //     end else begin
    //         // Cycle 1: Capture the requested bank
    //         if (src0_ren) src0_read_bank_q1 <= src0_bank;
    //         if (src1_ren) src1_read_bank_q1 <= src1_bank;

    //         // Cycle 2: Delay it to align with the new BRAM output register
    //         src0_read_bank_q2 <= src0_read_bank_q1;
    //         src1_read_bank_q2 <= src1_read_bank_q1;
    //     end
    // end

    // // Use the pipelined data and the cycle-2 delayed select
    // assign src0_o   = bank_rdata_pipe[src0_read_bank_q2];
    // assign src1_o   = bank_rdata_pipe[src1_read_bank_q2];


`ifndef SYNTHESIS
    always @(posedge clk) begin
        if (rst_n) begin
            if (src0_ren && src1_ren && (src0_bank == src1_bank) && (src0_addr != src1_addr)) begin
                $error("[sram_unit] src0/src1 read bank conflict at %0t bank=%0d src0_addr=%0d src1_addr=%0d",
                       $time, src0_bank, src0_addr, src1_addr);
            end
            if (dst_we && src0_ren && (dst_bank == src0_bank) && (dst_waddr == src0_addr)) begin
                $warning("[sram_unit] src0 read/write same address at %0t bank=%0d addr=%0d", $time, dst_bank, dst_waddr);
            end
            if (dst_we && src1_ren && (dst_bank == src1_bank) && (dst_waddr == src1_addr)) begin
                $warning("[sram_unit] src1 read/write same address at %0t bank=%0d addr=%0d", $time, dst_bank, dst_waddr);
            end
        end
    end
`endif

    // LUT memory, replicated for EXP and reciprocal readers.
    banked_mem_1r1w #(
        .LANES      (LANES),
        .LANE_WIDTH (LANE_WIDTH),
        .ADDR_WIDTH (ADDR_WIDTH)
    ) u_mem_lut_exp (
        .clk      (clk),
        .rst_n    (rst_n),
        .ren      (exp_lut_sram_en && !pre_lut_we),
        .raddr    (exp_lut_data_addr),
        .rdata    (exp_lut_sram_data_o),
        .wen      (pre_lut_we),
        .lane_wen (all_lane_wen),
        .waddr    (pre_lut_addr),
        .wdata    (pre_lut_data)
    );

    banked_mem_1r1w #(
        .LANES      (LANES),
        .LANE_WIDTH (LANE_WIDTH),
        .ADDR_WIDTH (ADDR_WIDTH)
    ) u_mem_lut_reciprocal (
        .clk      (clk),
        .rst_n    (rst_n),
        .ren      (reciprocal_lut_sram_en && !pre_lut_we),
        .raddr    (reciprocal_lut_data_addr),
        .rdata    (reciprocal_lut_sram_data_o),
        .wen      (pre_lut_we),
        .lane_wen (all_lane_wen),
        .waddr    (pre_lut_addr),
        .wdata    (pre_lut_data)
    );

    // Instruction memory. The number of packed 64-bit ISA words scales with SRAM width.
    banked_mem_1r1w #(
        .LANES      (LANES),
        .LANE_WIDTH (LANE_WIDTH),
        .ADDR_WIDTH (ADDR_WIDTH)
    ) u_mem_inst (
        .clk      (clk),
        .rst_n    (rst_n),
        .ren      (inst_sram_en && !pre_inst_we),
        .raddr    (inst_sram_addr),
        .rdata    (inst_sram_data_o),
        .wen      (pre_inst_we),
        .lane_wen (all_lane_wen),
        .waddr    (pre_inst_addr),
        .wdata    (pre_inst_data)
    );

    // Quant descriptor memory. A fixed descriptor packet may span consecutive SRAM words.
    banked_mem_1r1w #(
        .LANES      (LANES),
        .LANE_WIDTH (LANE_WIDTH),
        .ADDR_WIDTH (ADDR_WIDTH)
    ) u_mem_desc (
        .clk      (clk),
        .rst_n    (rst_n),
        .ren      (desc_sram_en && !pre_desc_we),
        .raddr    (desc_sram_addr),
        .rdata    (desc_sram_data_o),
        .wen      (pre_desc_we),
        .lane_wen (all_lane_wen),
        .waddr    (pre_desc_addr),
        .wdata    (pre_desc_data)
    );

endmodule

`default_nettype wire
