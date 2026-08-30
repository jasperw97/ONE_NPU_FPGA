`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/11/2026 07:34:26 PM
// Design Name: 
// Module Name: npu_axi_full
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`include "params.vh"

module npu_axi_full#(
        parameter integer DATA_WIDTH = `SRAM_WIDTH_O,
        parameter integer DRAM_ADDR_WIDTH = 32
    )
    (
        input  wire                         clk,
        input  wire                         rst_n,
        input  wire                         start_i, 
        output wire                         busy_o,
        output wire                         done_o,
        output wire                         start_sig_o,
        output wire [4:0]                   state_o,

        //AXI Full Channels
        //Read Address (AR)
        output wire [DRAM_ADDR_WIDTH-1:0]   m_axi_araddr,
        output wire [7:0]                   m_axi_arlen,
        output wire [2:0]                   m_axi_arsize,
        output wire [1:0]                   m_axi_arburst,
        output wire                         m_axi_arvalid,
        input  wire                         m_axi_arready,

        //Read (R)
        input  wire [DATA_WIDTH-1:0]        m_axi_rdata,
        input  wire                         m_axi_rvalid,
        output wire                         m_axi_rready,
        input  wire                         m_axi_rlast,
        input  wire [1:0]                   m_axi_rresp,

        // Write Address (AW
        output wire [DRAM_ADDR_WIDTH-1:0]   m_axi_awaddr,
        output wire [7:0]                   m_axi_awlen,
        output wire [2:0]                   m_axi_awsize,
        output wire [1:0]                   m_axi_awburst,
        output wire                         m_axi_awvalid,
        input  wire                         m_axi_awready,

        // Write Data (W)
        output wire [DATA_WIDTH-1:0]        m_axi_wdata,
        output wire [(DATA_WIDTH/8)-1:0]    m_axi_wstrb,
        output wire                         m_axi_wlast,
        output wire                         m_axi_wvalid,
        input  wire                         m_axi_wready,

        // Write Response (B)
        input  wire [1:0]                   m_axi_bresp,
        input  wire                         m_axi_bvalid,
        output wire                         m_axi_bready
    );

    //for conversion between word address and byte address

    localparam ADDR_SHIFT = $clog2(DATA_WIDTH / 8); //currently hardcoded for sram width = 512 bits (64 bytes)


    //Connecting to NPU with decoupled signals
    wire                       dram_ar_valid;
    wire                       dram_ar_ready;
    wire [DRAM_ADDR_WIDTH-1:0] dram_ar_addr;
    wire [7:0]                 dram_ar_len;

    wire                       dram_r_valid;
    wire                       dram_r_ready;
    wire [DATA_WIDTH-1:0]      dram_r_data;
    wire                       dram_r_last;

    wire                       dram_aw_valid;
    wire                       dram_aw_ready;
    wire [DRAM_ADDR_WIDTH-1:0] dram_aw_addr;
    wire [7:0]                 dram_aw_len;

    wire                       dram_w_valid;
    wire                       dram_w_ready;
    wire [DATA_WIDTH-1:0]      dram_w_data;
    wire                       dram_w_last;

    wire                       dram_b_valid;
    wire                       dram_b_ready;

    // Static configuration for AXI signals
    assign m_axi_arsize  = 3'b0 + ADDR_SHIFT;   
    assign m_axi_arburst = 2'b01; // INCR burst mode
    assign m_axi_awsize  = 3'b0 + ADDR_SHIFT;   
    assign m_axi_awburst = 2'b01; // INCR burst mode
    assign m_axi_wstrb   = { (DATA_WIDTH/8) {1'b1} };

    // Connecting to NPU signals by channel
    // ---------------------------------------------------------
    // AR Channel
    // ---------------------------------------------------------
    assign m_axi_arvalid = dram_ar_valid;
    assign m_axi_araddr  = dram_ar_addr << ADDR_SHIFT;
    assign m_axi_arlen   = dram_ar_len;
    assign dram_ar_ready = m_axi_arready;

    // ---------------------------------------------------------
    // R Channel
    // ---------------------------------------------------------
    assign dram_r_valid  = m_axi_rvalid;
    assign dram_r_data   = m_axi_rdata;
    assign dram_r_last   = m_axi_rlast;
    assign m_axi_rready  = dram_r_ready; //not always assigning to 1?

    // ---------------------------------------------------------
    // AW Channel
    // ---------------------------------------------------------
    assign m_axi_awvalid = dram_aw_valid;
    assign m_axi_awaddr  = dram_aw_addr << ADDR_SHIFT;
    assign m_axi_awlen   = dram_aw_len;
    assign dram_aw_ready = m_axi_awready;

    // ---------------------------------------------------------
    // W Channel
    // ---------------------------------------------------------
    assign m_axi_wvalid  = dram_w_valid;
    assign m_axi_wdata   = dram_w_data;
    assign m_axi_wlast   = dram_w_last;
    assign dram_w_ready  = m_axi_wready;

    // ---------------------------------------------------------
    // B Channel
    // ---------------------------------------------------------
    assign dram_b_valid  = m_axi_bvalid;
    assign m_axi_bready  = dram_b_ready; //not always 1?


    assign start_sig_o = start_pulse;

    // Pulse logic of start i
    reg start_prev;
    wire start_pulse;
    always @(posedge clk ) begin
        if (!rst_n) begin
            start_prev <= 1'b0;
        end else begin
            start_prev <= start_i;
        end
    end

    assign start_pulse = start_i && (!start_prev);

    npu_int16 npu_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start_i(start_pulse),
        .busy_o(busy_o),
        .done_o(done_o),
        .state_o(state_o),

        // Decoupled AXI Channels for dram interfacing
        .dram_ar_valid(dram_ar_valid),
        .dram_ar_ready(dram_ar_ready),
        .dram_ar_addr(dram_ar_addr),
        .dram_ar_len(dram_ar_len),

        .dram_r_valid(dram_r_valid),
        .dram_r_ready(dram_r_ready),
        .dram_r_data(dram_r_data),
        .dram_r_last(dram_r_last),

        .dram_aw_valid(dram_aw_valid),
        .dram_aw_ready(dram_aw_ready),
        .dram_aw_addr(dram_aw_addr),
        .dram_aw_len(dram_aw_len),

        .dram_w_valid(dram_w_valid),
        .dram_w_ready(dram_w_ready),
        .dram_w_data(dram_w_data),
        .dram_w_last(dram_w_last),

        .dram_b_valid(dram_b_valid),
        .dram_b_ready(dram_b_ready)
    );


endmodule
