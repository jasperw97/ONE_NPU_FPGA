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

    // External DRAM interface by axi channel
    output logic                       dram_ar_valid,
    input  logic                       dram_ar_ready,
    output logic [DRAM_ADDR_WIDTH-1:0] dram_ar_addr,
    output logic [7:0]                 dram_ar_len,

    input  logic                       dram_r_valid,
    output logic                       dram_r_ready,
    input  logic [DATA_WIDTH-1:0]      dram_r_data,
    input  logic                       dram_r_last,

    output logic                       dram_aw_valid,
    input  logic                       dram_aw_ready,
    output logic [DRAM_ADDR_WIDTH-1:0] dram_aw_addr,
    output logic [7:0]                 dram_aw_len,

    output logic                       dram_w_valid,
    input  logic                       dram_w_ready,
    output logic [DATA_WIDTH-1:0]      dram_w_data,
    output logic                       dram_w_last,

    input  logic                       dram_b_valid,
    output logic                       dram_b_ready,

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

    localparam int ADDR_SHIFT = $clog2(DATA_WIDTH / 8);
    localparam int WORDS_PER_4K = 4096 >> ADDR_SHIFT;

    //right now just to make it work, some of these states can be overlapped to save more cycles
    typedef enum logic [2:0] {
        S_IDLE,

        S_LOAD_AR,        // issue read addr, wait for ar handshake
        S_LOAD_R,         // streams Rdata into sram until current chunk (max 256 words) is finished

        S_STORE_AW,       // issue write addr, wait for handshake
        S_STORE_W,        // streams Wdata from sram into dram until current chunk is finished
        S_STORE_B,        // waits for B channel handshake to confirm successful write
        S_NEXT_CHUNK,     //evaluates more data, need this? or can we go from store_b straight to idle or done
        S_DONE
    } state_t;

    state_t state_r, state_n;

    // logic                    op_write_r;
    // logic [CMD_BANK_WIDTH-1:0] bank_r;
    // logic [DRAM_ADDR_WIDTH-1:0]   dram_base_r;
    // logic [SRAM_ADDR_WIDTH-1:0]   sram_base_r;
    // logic [SRAM_ADDR_WIDTH-1:0]   len_r;
    // logic [SRAM_ADDR_WIDTH-1:0]   count_r;

    logic [CMD_BANK_WIDTH-1:0]  bank_r;
    logic [DRAM_ADDR_WIDTH-1:0] dram_ptr_r;
    logic [SRAM_ADDR_WIDTH-1:0] sram_ptr_r;
    logic [SRAM_ADDR_WIDTH-1:0] remaining_len_r;

    logic [12:0] dist_to_4k; 
    logic [8:0]  limit_256_or_4k;
    logic [8:0] chunk_len; 
    logic [8:0] chunk_count_r; // Tracks beats within current chunk

    assign dist_to_4k = WORDS_PER_4K - (dram_ptr_r & (WORDS_PER_4K - 1));
    assign limit_256_or_4k = (dist_to_4k > 13'd256) ? 9'd256 : dist_to_4k[8:0];
    assign chunk_len = (remaining_len_r > limit_256_or_4k) ? limit_256_or_4k : remaining_len_r[8:0];
    // assign chunk_len = (remaining_len_r > 256) ? 9'd256 : remaining_len_r[8:0];

    logic bank_is_lut;
    logic bank_is_qdesc;
    logic bank_is_inst;
    logic bank_is_job;
    logic bank_is_tensor;
    logic [DATA_WIDTH-1:0] load_data_r;
    logic [DATA_WIDTH-1:0] store_data_r;
    logic [DRAM_ADDR_WIDTH-1:0] store_addr_r;
    logic store_valid_r; //no longer need this?

    assign bank_is_lut    = (bank_r == LSU_BANK_LUT);
    assign bank_is_qdesc  = (bank_r == LSU_BANK_QDESC);
    assign bank_is_inst   = (bank_r == LSU_BANK_INST);
    assign bank_is_job    = (bank_r == LSU_BANK_JOB);
    assign bank_is_tensor = (bank_r <= LSU_BANK_MAX_TENSOR);

    // Skid buffer for pipelined SRAM -> AXI W channel
    logic skid_valid_r;
    logic [DATA_WIDTH-1:0] skid_data_r;
    logic w_handshake;
    assign w_handshake = dram_w_valid && dram_w_ready;

    //Tracking SRAM read separate from axi write
    logic [8:0] req_count_r; // Tracks SRAM read requests independently of AXI writes
    logic       ren_d1;      // 1-cycle delayed read enable (tells us when data is valid)

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_r     <= S_IDLE;
            bank_r      <= '0;
            dram_ptr_r      <= '0;
            sram_ptr_r      <= '0;
            remaining_len_r <= '0;
            chunk_count_r   <= '0;
            skid_valid_r    <= 1'b0;
            skid_data_r     <= '0;
            req_count_r  <= '0;
            ren_d1       <= 1'b0;
        end else begin
            state_r <= state_n;
            ren_d1  <= store_sram_ren; //delay by 1 clock cycle

            if (state_r == S_IDLE && cmd_valid && cmd_ready) begin
                bank_r      <= cmd_bank;
                dram_ptr_r <= cmd_dram_base;
                sram_ptr_r <= cmd_sram_base;
                remaining_len_r       <= cmd_len;
                chunk_count_r   <= '0;
                skid_valid_r    <= 1'b0;
            end else begin
                case (state_r)
                    S_LOAD_R: begin
                        if (dram_r_valid && dram_r_ready) begin
                            chunk_count_r <= chunk_count_r + 1;
                            // sram_ptr_r    <= sram_ptr_r + 1;
                            if (chunk_count_r == chunk_len - 1) begin
                                // remaining_len_r <= remaining_len_r - chunk_len;
                            end
                        end 
                    end

                    S_STORE_W: begin
                        // SRAM Pipeline logic
                        // if (store_sram_ren) begin
                        //     skid_valid_r <= 1'b1;
                        //     skid_data_r  <= store_sram_rdata;
                        //     req_count_r <= req_count_r + 1;
                        // end else if (w_handshake) begin
                        //     skid_valid_r <= 1'b0; 
                        // end
                        if (store_sram_ren) begin
                            req_count_r <= req_count_r + 1;
                        end

                        if (ren_d1 && !dram_w_ready) begin
                            skid_valid_r <= 1'b1;
                            skid_data_r  <= store_sram_rdata;
                        end else if (w_handshake) begin
                            skid_valid_r <= 1'b0;
                        end

                        if (w_handshake) begin
                            chunk_count_r <= chunk_count_r + 1;
                        end
                    end

                    S_STORE_B: begin
                        if (dram_b_valid && dram_b_ready) begin
                            // remaining_len_r <= remaining_len_r - chunk_len;
                        end
                    end

                    S_NEXT_CHUNK: begin
                        dram_ptr_r      <= dram_ptr_r + chunk_len;
                        sram_ptr_r      <= sram_ptr_r + chunk_len;
                        remaining_len_r <= remaining_len_r - chunk_len; // moved it one cycle early
                        chunk_count_r   <= '0;
                        skid_valid_r    <= 1'b0;
                        req_count_r     <= '0;
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
                        state_n = S_STORE_AW;
                    end else begin
                        state_n = S_LOAD_AR;
                    end
                end
            end

            //issue read address to dram
            S_LOAD_AR: begin
                if (dram_ar_valid && dram_ar_ready) state_n = S_LOAD_R;
            end

            // Streams data in from dram
            S_LOAD_R: begin
                if (dram_r_valid && dram_r_ready && (chunk_count_r == chunk_len - 1)) begin
                    state_n = S_NEXT_CHUNK;
                end
            end

            S_STORE_AW: begin
                if (dram_aw_valid && dram_aw_ready) state_n = S_STORE_W;
            end

            S_STORE_W: begin
                if (w_handshake && dram_w_last) state_n = S_STORE_B;
            end

            S_STORE_B: begin
                if (dram_b_valid && dram_b_ready) state_n = S_NEXT_CHUNK;
            end

            S_NEXT_CHUNK: begin
                if (remaining_len_r <= chunk_len) state_n = S_DONE;
                else if (cmd_write)  state_n = S_STORE_AW; // Assuming WRITE is only for tensors
                else                      state_n = S_LOAD_AR;
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

        // AR Channel
        dram_ar_valid = (state_r == S_LOAD_AR);
        dram_ar_addr  = dram_ptr_r;
        dram_ar_len   = chunk_len - 1; // AXI length is actual_length - 1

        // R Channel
        dram_r_ready  = (state_r == S_LOAD_R);

        // AW Channel
        dram_aw_valid = (state_r == S_STORE_AW);
        dram_aw_addr  = dram_ptr_r;
        dram_aw_len   = chunk_len - 1;

        // W Channel (Driven by Skid Buffer)
        dram_w_valid  = (state_r == S_STORE_W) && (skid_valid_r || ren_d1);
        dram_w_data   = skid_valid_r ? skid_data_r : store_sram_rdata;;
        dram_w_last   = (chunk_count_r == chunk_len - 1);

        // B Channel
        dram_b_ready  = (state_r == S_STORE_B);

        bank_we          = 1'b0;
        bank_wbank       = bank_r[SRAM_BANK_ID_WIDTH-1:0];
        bank_waddr       = sram_ptr_r + chunk_count_r;
        bank_wdata       = dram_r_data;

        lut_we           = 1'b0;
        lut_waddr        = sram_ptr_r + chunk_count_r;
        lut_wdata        = dram_r_data;

        inst_we          = 1'b0;
        inst_waddr       = sram_ptr_r + chunk_count_r;
        inst_wdata       = dram_r_data;

        qdesc_we         = 1'b0;
        qdesc_waddr      = sram_ptr_r + chunk_count_r;
        qdesc_wdata      = dram_r_data;

        job_we           = 1'b0;
        job_wdata        = dram_r_data;

        if (state_r == S_LOAD_R && dram_r_valid) begin
            if (bank_is_lut) lut_we = 1'b1;
            else if (bank_is_qdesc) qdesc_we = 1'b1;
            else if (bank_is_inst) inst_we = 1'b1;
            else if (bank_is_job) job_we = 1'b1;
            else if (bank_is_tensor) bank_we = 1'b1;
        end


        store_sram_bank = bank_r[SRAM_BANK_ID_WIDTH-1:0];
        store_sram_addr = sram_ptr_r + req_count_r;
        // Request from SRAM if in STORE_W, not finished, and skid buffer is empty or emptying
        store_sram_ren  = (state_r == S_STORE_W) && 
                          (req_count_r < chunk_len) && 
                          (!skid_valid_r) &&
                          (!ren_d1 || dram_w_ready); //do we check dram_w_ready or w_handshake
    end

// `ifndef SYNTHESIS
//     always_ff @(posedge clk) begin
//         if (rst_n) begin
//             if (state_r == S_LOAD_WAIT && dram_rd_data_valid &&
//                 !bank_is_lut && !bank_is_tensor && !bank_is_qdesc &&
//                 !bank_is_inst && !bank_is_job) begin
//                 $warning("[LSU] LOAD ignored for unsupported bank id %0d.", bank_r);
//             end
//             if (state_r == S_STORE_REQ && !bank_is_tensor) begin
//                 $warning("[LSU] STORE only supports tensor SRAM banks 0..7, got bank id %0d.", bank_r);
//             end
//         end
//     end
// `endif

endmodule

`default_nettype wire
