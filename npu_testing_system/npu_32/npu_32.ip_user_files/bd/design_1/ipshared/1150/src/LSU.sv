`timescale 1ns/1ps
`default_nettype wire
`include "params.vh"

// ============================================================
// LSU: Load Store Unit
//
// Functional description: TB DRAM <-> LSU <-> NPU SRAM
//
// Bank command encoding:
//   0..7 : tensor SRAM bank id
//   8    : LUT SRAM preload target
//   9    : quant descriptor SRAM target
//   10   : instruction SRAM preload target
//   11   : pseudo target for top-level control-word capture, not a real SRAM bank
//
// State:
//   LOAD  bank 0..7 : DRAM -> tensor SRAM bank0..7
//   LOAD  bank 8    : DRAM -> LUT SRAM
//   LOAD  bank 9    : DRAM -> quant descriptor SRAM
//   LOAD  bank 10   : DRAM -> instruction SRAM
//   LOAD  bank 11   : DRAM -> top-level control-word register
//   
//   STORE bank 0..7    : tensor SRAM bank0..7 -> DRAM
//   STORE bank 8/9/10  : unsupported
// ============================================================

module LSU #(
    parameter int DRAM_ADDR_WIDTH = `DRAM_ADDR_WIDTH,
    parameter int SRAM_ADDR_WIDTH = `SRAM_ADDR_WIDTH,
    parameter int DATA_WIDTH = `SRAM_WIDTH_O,
    parameter int NUM_SRAM_BANKS = 8,
    parameter int SRAM_BANK_ID_WIDTH = 3,
    parameter int CMD_BANK_WIDTH = 4
)(
    input  logic clk,
    input  logic rst_n,

    input  logic                    cmd_valid,
    output logic                    cmd_ready,

    input  logic                    cmd_write, // 0: LOAD ; 1: STORE
    input  logic [CMD_BANK_WIDTH-1:0] cmd_bank,

    input  logic [DRAM_ADDR_WIDTH-1:0]   cmd_dram_base,
    input  logic [SRAM_ADDR_WIDTH-1:0]   cmd_sram_base,
    input  logic [SRAM_ADDR_WIDTH-1:0]   cmd_len,

    output logic                         busy,
    output logic                         done,

    // DRAM read channel: LSU <- TB DRAM model
    output logic                       dram_rd_valid, //this is like ar_valid
    input  logic                       dram_rd_ready, //this is like ar_ready
    output logic [DRAM_ADDR_WIDTH-1:0] dram_rd_addr, // ar_addr
    input  logic                       dram_rd_data_valid, //r_valid
    input  logic [DATA_WIDTH-1:0]      dram_rd_data, //r_data

    // LSU -> TB DRAM model
    output logic                       dram_wr_valid,
    input  logic                       dram_wr_ready,
    output logic [DRAM_ADDR_WIDTH-1:0] dram_wr_addr,
    output logic [DATA_WIDTH-1:0]      dram_wr_data,

    // LSU -> generic SRAM
    output logic                       bank_we,
    output logic [SRAM_BANK_ID_WIDTH-1:0] bank_wbank,
    output logic [SRAM_ADDR_WIDTH-1:0] bank_waddr,
    output logic [DATA_WIDTH-1:0]      bank_wdata,

    // LSU -> LUT SRAM
    output logic                       lut_we,
    output logic [SRAM_ADDR_WIDTH-1:0] lut_waddr,
    output logic [DATA_WIDTH-1:0]      lut_wdata,

    // LSU -> instruction SRAM
    output logic                       inst_we,
    output logic [SRAM_ADDR_WIDTH-1:0] inst_waddr,
    output logic [DATA_WIDTH-1:0]      inst_wdata,

    // LSU -> quant descriptor SRAM
    output logic                       qdesc_we,
    output logic [SRAM_ADDR_WIDTH-1:0] qdesc_waddr,
    output logic [DATA_WIDTH-1:0]      qdesc_wdata,

    // LSU -> top-level control-word capture path. This is a pseudo target,
    // so bank id 11 never writes the tensor SRAM bank array.
    output logic                       job_we,
    output logic [DATA_WIDTH-1:0]      job_wdata,

    // LSU <- SRAM
    output logic                       store_sram_ren,
    output logic [SRAM_BANK_ID_WIDTH-1:0] store_sram_bank,
    output logic [SRAM_ADDR_WIDTH-1:0] store_sram_addr,
    input  logic [DATA_WIDTH-1:0]      store_sram_rdata
);

    localparam logic [CMD_BANK_WIDTH-1:0] LSU_BANK_LUT   = 4'd8;
    localparam logic [CMD_BANK_WIDTH-1:0] LSU_BANK_QDESC = 4'd9;
    localparam logic [CMD_BANK_WIDTH-1:0] LSU_BANK_INST  = 4'd10;
    localparam logic [CMD_BANK_WIDTH-1:0] LSU_BANK_JOB   = 4'd11;
    localparam logic [CMD_BANK_WIDTH-1:0] LSU_BANK_MAX_TENSOR = 4'd7;

    typedef enum logic [2:0] {
        S_IDLE,

        S_LOAD_REQ,        // issue DRAM read
        S_LOAD_WAIT,       // wait/latch DRAM read data
        S_LOAD_WRITE,      // write staged data into SRAM

        S_STORE_REQ,       // issue SRAM read
        S_STORE_LATCH,     // latch SRAM read data
        S_STORE_SEND,      // send staged data to DRAM

        S_DONE
    } state_t;

    state_t state_r, state_n;

    logic                    op_write_r;
    logic [CMD_BANK_WIDTH-1:0] bank_r;
    logic [DRAM_ADDR_WIDTH-1:0]   dram_base_r;
    logic [SRAM_ADDR_WIDTH-1:0]   sram_base_r;
    logic [SRAM_ADDR_WIDTH-1:0]   len_r;
    logic [SRAM_ADDR_WIDTH-1:0]   count_r;

    logic bank_is_lut;
    logic bank_is_qdesc;
    logic bank_is_inst;
    logic bank_is_job;
    logic bank_is_tensor;
    logic [DATA_WIDTH-1:0] load_data_r;
    logic [DATA_WIDTH-1:0] store_data_r;
    logic [DRAM_ADDR_WIDTH-1:0] store_addr_r;
    logic store_valid_r;

    assign bank_is_lut    = (bank_r == LSU_BANK_LUT);
    assign bank_is_qdesc  = (bank_r == LSU_BANK_QDESC);
    assign bank_is_inst   = (bank_r == LSU_BANK_INST);
    assign bank_is_job    = (bank_r == LSU_BANK_JOB);
    assign bank_is_tensor = (bank_r <= LSU_BANK_MAX_TENSOR);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_r     <= S_IDLE;
            op_write_r  <= 1'b0;
            bank_r      <= '0;
            dram_base_r <= '0;
            sram_base_r <= '0;
            len_r       <= '0;
            count_r     <= '0;
            load_data_r <= '0;
            store_data_r <= '0;
            store_addr_r <= '0;
            store_valid_r <= 1'b0;
        end else begin
            state_r <= state_n;

            if (state_r == S_IDLE && cmd_valid && cmd_ready) begin
                op_write_r  <= cmd_write;
                bank_r      <= cmd_bank;
                dram_base_r <= cmd_dram_base;
                sram_base_r <= cmd_sram_base;
                len_r       <= cmd_len;
                count_r     <= '0;
                store_valid_r <= 1'b0;
            end else begin
                case (state_r)
                    S_LOAD_WAIT: begin
                        if (dram_rd_data_valid) begin
                            load_data_r <= dram_rd_data;
                        end
                    end

                    S_LOAD_WRITE: begin
                        count_r <= count_r + {{(SRAM_ADDR_WIDTH-1){1'b0}}, 1'b1};
                    end

                    S_STORE_LATCH: begin
                        store_data_r <= store_sram_rdata;
                        store_addr_r <= dram_base_r + count_r;
                        store_valid_r <= bank_is_tensor;
                    end

                    S_STORE_SEND: begin
                        if (store_valid_r && dram_wr_ready) begin
                            count_r <= count_r + {{(SRAM_ADDR_WIDTH-1){1'b0}}, 1'b1};
                            store_valid_r <= 1'b0;
                        end
                    end

                    default: begin
                        count_r <= count_r;
                    end
                endcase
            end
        end
    end

    always_comb begin
        state_n = state_r;

        unique case (state_r)
            S_IDLE: begin
                if (cmd_valid && cmd_ready) begin
                    if (cmd_len == '0) begin
                        state_n = S_DONE;
                    end else if (cmd_write) begin
                        state_n = S_STORE_REQ;
                    end else begin
                        state_n = S_LOAD_REQ;
                    end
                end
            end

            // LOAD: issue DRAM read request
            S_LOAD_REQ: begin
                if (dram_rd_valid && dram_rd_ready) state_n = S_LOAD_WAIT;
            end

            // LOAD: wait DRAM data, then stage it before writing SRAM.
            S_LOAD_WAIT: begin
                if (dram_rd_data_valid) begin
                    state_n = S_LOAD_WRITE;
                end
            end

            S_LOAD_WRITE: begin
                if (count_r == (len_r - {{(SRAM_ADDR_WIDTH-1){1'b0}}, 1'b1})) begin
                    state_n = S_DONE;
                end else begin
                    state_n = S_LOAD_REQ;
                end
            end

            // STORE: request one result word from SRAM result stream
            S_STORE_REQ: begin
                state_n = S_STORE_LATCH;
            end

            // STORE: capture SRAM readback before driving the top-level DRAM port.
            S_STORE_LATCH: begin
                state_n = S_STORE_SEND;
            end

            S_STORE_SEND: begin
                if (store_valid_r && dram_wr_ready) begin
                    if (count_r == (len_r - {{(SRAM_ADDR_WIDTH-1){1'b0}}, 1'b1})) begin
                        state_n = S_DONE;
                    end else begin
                        state_n = S_STORE_REQ;
                    end
                end
            end

            S_DONE: begin
                state_n = S_IDLE;
            end

            default: begin
                state_n = S_IDLE;
            end
        endcase
    end

    always_comb begin
        cmd_ready        = (state_r == S_IDLE);
        busy             = (state_r != S_IDLE);
        done             = (state_r == S_DONE);

        dram_rd_valid    = 1'b0;
        dram_rd_addr     = dram_base_r + count_r;

        dram_wr_valid    = (state_r == S_STORE_SEND) && store_valid_r;
        dram_wr_addr     = store_addr_r;
        dram_wr_data     = store_data_r;

        bank_we          = 1'b0;
        bank_wbank       = bank_r[SRAM_BANK_ID_WIDTH-1:0];
        bank_waddr       = sram_base_r + count_r;
        bank_wdata       = load_data_r;

        lut_we           = 1'b0;
        lut_waddr        = sram_base_r + count_r;
        lut_wdata        = load_data_r;

        inst_we          = 1'b0;
        inst_waddr       = sram_base_r + count_r;
        inst_wdata       = load_data_r;

        qdesc_we         = 1'b0;
        qdesc_waddr      = sram_base_r + count_r;
        qdesc_wdata      = load_data_r;

        job_we           = 1'b0;
        job_wdata        = load_data_r;

        store_sram_ren  = 1'b0;
        store_sram_bank = bank_r[SRAM_BANK_ID_WIDTH-1:0];
        store_sram_addr = sram_base_r + count_r;

        unique case (state_r)
            S_LOAD_REQ: begin
                dram_rd_valid = 1'b1;
                dram_rd_addr  = dram_base_r + count_r;
            end

            S_LOAD_WRITE: begin
                if (bank_is_lut) begin
                    lut_we = 1'b1;
                end else if (bank_is_qdesc) begin
                    qdesc_we = 1'b1;
                end else if (bank_is_inst) begin
                    inst_we = 1'b1;
                end else if (bank_is_job) begin
                    job_we = 1'b1;
                end else if (bank_is_tensor) begin
                    bank_we = 1'b1;
                end
            end

            S_STORE_REQ: begin
                if (bank_is_tensor) begin
                    store_sram_ren = 1'b1;
                end
            end

            S_STORE_SEND: begin
                dram_wr_valid = store_valid_r;
            end

            default: begin
            end
        endcase
    end

`ifndef SYNTHESIS
    always_ff @(posedge clk) begin
        if (rst_n) begin
            if (state_r == S_LOAD_WAIT && dram_rd_data_valid &&
                !bank_is_lut && !bank_is_tensor && !bank_is_qdesc &&
                !bank_is_inst && !bank_is_job) begin
                $warning("[LSU] LOAD ignored for unsupported bank id %0d.", bank_r);
            end
            if (state_r == S_STORE_REQ && !bank_is_tensor) begin
                $warning("[LSU] STORE only supports tensor SRAM banks 0..7, got bank id %0d.", bank_r);
            end
        end
    end
`endif

endmodule

`default_nettype wire
