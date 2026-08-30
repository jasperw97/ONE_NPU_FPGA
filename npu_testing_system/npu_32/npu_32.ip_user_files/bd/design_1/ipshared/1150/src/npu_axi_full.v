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

    //for conversino between word address and byte address
    // localparam int ADDR_SHIFT = 4; //currently hardcoded for sram width = 128 bits (16 bytes)

    localparam int ADDR_SHIFT = 6; //currently hardcoded for sram width = 512 bits (64 bytes)


    //Connecting to NPU 
    wire                        dram_rd_valid;
    wire                        dram_rd_ready;
    wire [DRAM_ADDR_WIDTH-1:0]  dram_rd_addr;
    wire                        dram_rd_data_valid;
    wire [DATA_WIDTH-1:0]       dram_rd_data;

    wire                        dram_wr_valid;
    wire                        dram_wr_ready;
    wire [DRAM_ADDR_WIDTH-1:0]  dram_wr_addr;
    wire [DATA_WIDTH-1:0]       dram_wr_data;

    // Single transaction configuration (current state machine in LSU)
    assign m_axi_arlen   = 8'd0;      
    // assign m_axi_arsize  = 3'b100;    // for 128 bit 8x8 npu
    assign m_axi_arsize  = 3'b110;    // for 128 bit 8x8 npu
    assign m_axi_arburst = 2'b01;     // INCR type (standard default)

    assign m_axi_awlen   = 8'd0;      // 1 word per write address transfer
    assign m_axi_awsize  = 3'b110;    
    assign m_axi_awburst = 2'b01;    
    assign m_axi_wstrb   = { (DATA_WIDTH/8) {1'b1} }; // Enable all byte lanes
    assign m_axi_wlast   = 1'b1;      // Since length is 0, every word is the last word

    // Connecting to NPU signals
    assign m_axi_araddr   = dram_rd_addr << ADDR_SHIFT;
    assign m_axi_arvalid  = dram_rd_valid;
    assign dram_rd_ready  = m_axi_arready;

    assign dram_rd_data       = m_axi_rdata;
    assign dram_rd_data_valid = m_axi_rvalid;
    assign m_axi_rready       = 1'b1; //always ready

    reg aw_cleared_r;
    reg w_cleared_r;

    assign m_axi_awaddr   = dram_wr_addr << ADDR_SHIFT;
    assign m_axi_awvalid  = dram_wr_valid && !aw_cleared_r;
    
    assign m_axi_wdata    = dram_wr_data;
    assign m_axi_wvalid   = dram_wr_valid && !w_cleared_r;

    

    

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            aw_cleared_r <= 1'b0;
            w_cleared_r  <= 1'b0;
        end else begin
            if (dram_wr_valid) begin
                // Lock in the clearance the moment the handshake happens
                if (m_axi_awvalid && m_axi_awready) aw_cleared_r <= 1'b1;
                if (m_axi_wvalid  && m_axi_wready)  w_cleared_r  <= 1'b1;
            end else begin
                // Reset the tracking flags once the whole transaction completes
                aw_cleared_r <= 1'b0;
                w_cleared_r  <= 1'b0;
            end
        end
    end
    assign dram_wr_ready  = (m_axi_awready || aw_cleared_r) && (m_axi_wready || w_cleared_r); 

    assign m_axi_bready   = 1'b1;

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

        // Core to Wrapper Connections
        .dram_rd_valid(dram_rd_valid),
        .dram_rd_ready(dram_rd_ready),
        .dram_rd_addr(dram_rd_addr),
        .dram_rd_data_valid(dram_rd_data_valid),
        .dram_rd_data(dram_rd_data),

        .dram_wr_valid(dram_wr_valid),
        .dram_wr_ready(dram_wr_ready),
        .dram_wr_addr(dram_wr_addr),
        .dram_wr_data(dram_wr_data)
    );


endmodule
