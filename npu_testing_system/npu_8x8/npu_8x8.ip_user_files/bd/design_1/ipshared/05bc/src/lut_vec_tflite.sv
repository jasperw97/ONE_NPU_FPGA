`timescale 1ns / 1ps
`default_nettype none
`include "params.vh"

// =============================================================
// lut_vec_tflite.sv (generic LUT loader + vector lookup)
// -------------------------------------------------------------
// Supports two LUT styles:
// 1) int8/uint8 direct lookup (256-entry, no interpolation)
// 2) int16 LUTLookup with interpolation (513-entry, TFLite-style)
//    - index  = 256 + (value >> 7)   (value is signed int16)
//    - offset = value & 7'h7f
//    - out    = base + ((slope * offset + 64) >> 7)
//      where base=lut[index], slope=lut[index+1]-lut[index]
// -------------------------------------------------------------
// SRAM load:
// - Reads LUT content from external SRAM using 64-bit beats.
// - Assumes 1-cycle read latency:
//      posedge: dut drives sram_lut_en + lut_data_addr
//      next posedge: lut_data_in corresponds to previous request
// - The module copies the whole LUT into internal LUT_mem,
//   then does lookup from LUT_mem (no SRAM access at runtime).
// -------------------------------------------------------------
// Notes about "load_done":
// - This output is a LEVEL "lut_ready" flag (stays 1 after load completes),
//   matching your expected "lut_done" semantics.
// =============================================================

module lut_vec_tflite #(
    parameter int LANES = `LANES,
    parameter int ADDR_WIDTH      = `SRAM_ADDR_WIDTH,

    // Per-lane input width (8 for int8/uint8 LUT; 16 for int16 interpolated LUT)
    parameter int IN_WIDTH        = 16,

    // LUT entry width (8 for int8/uint8; 16 for int16 Q0.15 LUT)
    parameter int OUT_WIDTH       = 16,

    // Number of LUT entries:
    // - 256 for int8/uint8 direct lookup
    // - 513 for int16 interpolated lookup (TFLite LUTLookup)
    parameter int LUT_SIZE        = 513,

    // 0: direct lookup, index = data_in (cast to unsigned)
    // 1: TFLite int16 LUTLookup with interpolation (requires IN_WIDTH=16, OUT_WIDTH=16, LUT_SIZE=513)
    parameter bit INTERP          = 1'b1
)(
    input  wire                               clk,
    input  wire                               rst,          // active-low

    // Control
    input  wire                               load_lut,     // pulse to start loading
    output reg                                load_done,    // LEVEL: 1 when LUT is ready (stays high)

    // SRAM interface (1-cycle read latency assumed)
    input  wire [`SRAM_WIDTH_O-1:0]           lut_data_in,
    output wire                               sram_lut_en,
    input  wire [ADDR_WIDTH-1:0]              lut_base_addr,
    output reg  [ADDR_WIDTH-1:0]              lut_data_addr,

    // Lookup I/O
    input  wire                               input_valid,
    output reg                                output_valid,
    input  wire [LANES*IN_WIDTH-1:0]   data_in,
    output reg  [LANES*OUT_WIDTH-1:0]  data_out
);

    // -------------------------
    // Derived constants
    // -------------------------
    localparam int ENTRIES_PER_WORD = (`SRAM_WIDTH_O / OUT_WIDTH); // 64/16=4  isn't it 1024/16=64?
    localparam int NUM_WORDS        = (LUT_SIZE + ENTRIES_PER_WORD - 1) / ENTRIES_PER_WORD;

    // -------------------------
    // LUT storage
    // -------------------------
    // (* ram_style = "block" *) reg signed [OUT_WIDTH-1:0] LUT_mem [0:LANES-1][0:LUT_SIZE-1];
    // trying the separate banked bram module

    // -------------------------
    // Loading control
    // -------------------------
    reg [$clog2(NUM_WORDS+1)-1:0] load_cnt;
    reg loading;
    reg lut_ready;

    assign sram_lut_en = loading;

    // align SRAM 1-cycle latency
    reg sram_lut_en_d;
    always @(posedge clk or negedge rst) begin
        if (!rst) sram_lut_en_d <= 1'b0;
        else      sram_lut_en_d <= sram_lut_en;
    end

    integer i;
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            load_cnt  <= '0;
            loading   <= 1'b0;
            lut_ready <= 1'b0;
            load_done <= 1'b0;
        end else if (load_lut && !loading) begin
            load_cnt  <= '0;
            loading   <= 1'b1;
            lut_ready <= 1'b0;
            load_done <= 1'b0;
        end else if (loading && sram_lut_en_d) begin
            // for (i = 0; i < ENTRIES_PER_WORD; i = i + 1) begin
            //     integer idx;
            //     idx = load_cnt * ENTRIES_PER_WORD + i;
            //     if (idx < LUT_SIZE) begin
            //         LUT_mem[idx] <= $signed(lut_data_in[i*OUT_WIDTH +: OUT_WIDTH]);
            //         // $display("Loaded LUT[%0d] = %0d", idx, lut_data_in[i*OUT_WIDTH +: OUT_WIDTH]);
            //     end
            // end

            // Consume SRAM data (valid one cycle after request)
            // if (loading && sram_lut_en_d) begin
                // for (i = 0; i < ENTRIES_PER_WORD; i = i + 1) begin
                //     integer idx;
                //     idx = load_cnt * ENTRIES_PER_WORD + i;
                //     if (idx < LUT_SIZE) begin
                //         // LUT_mem[idx] <= $signed(lut_data_in[i*OUT_WIDTH +: OUT_WIDTH]);
                //         for (integer l = 0; l < LANES; l = l + 1) begin
                //             LUT_mem[l][idx] <= $signed(lut_data_in[i*OUT_WIDTH +: OUT_WIDTH]);
                //         end
                //         // $display("Loaded LUT[%0d] = %0d", idx, lut_data_in[i*OUT_WIDTH +: OUT_WIDTH]);
                //     end
                // end
                // This loading logic should now be handled inside lut_lane_mem

            // Finish after last word
            if (load_cnt == (NUM_WORDS - 1)) begin
                loading   <= 1'b0;
                lut_ready <= 1'b1;
                load_done <= 1'b1;   // LEVEL ready
            end else begin
                load_cnt <= load_cnt + 1'b1;
            end
            // end
        end
    end

    // SRAM read address generation
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            lut_data_addr <= '0;
        end else begin
            if (load_lut && !loading) begin
                lut_data_addr <= lut_base_addr;
            end else if (loading && sram_lut_en) begin
                lut_data_addr <= lut_data_addr + 1'b1;
            end
        end
    end

    // -------------------------
    // Unpack input lanes
    // -------------------------
    wire signed [IN_WIDTH-1:0] data_in_vec [0:LANES-1];

    genvar gi;
    generate
        for (gi = 0; gi < LANES; gi = gi + 1) begin : GEN_UNPACK
            assign data_in_vec[gi] = $signed(data_in[gi*IN_WIDTH +: IN_WIDTH]);
        end
    endgenerate

    // =========================================================
    // Stage 1:
    //   - compute idx / offset
    //   - register idx / offset
    // =========================================================
    wire lookup_fire = input_valid && lut_ready;

    reg                        valid_s1;
    reg [6:0]                  offset_s1 [0:LANES-1];
    reg [9:0]                  idx_s1    [0:LANES-1];

    wire [6:0]                 offset_w      [0:LANES-1];
    wire [9:0]                 idx_clamped_w [0:LANES-1];

    genvar g1;
    generate
        for (g1 = 0; g1 < LANES; g1 = g1 + 1) begin : GEN_STAGE1_COMB
            if (!INTERP) begin : GEN_DIRECT_S1
                wire [IN_WIDTH-1:0] idx_u;
                assign idx_u             = data_in_vec[g1][IN_WIDTH-1:0];
                assign offset_w[g1]      = 7'd0;
                assign idx_clamped_w[g1] = idx_u[9:0];
            end else begin : GEN_INTERP_S1
                wire signed [`INT16_SIZE-1:0] v;
                wire signed [`INT16_SIZE-1:0] v_sh;
                wire signed [`INT16_SIZE-1:0] idx_raw;

                assign v            = $signed(data_in_vec[g1][`INT16_SIZE-1:0]);
                assign offset_w[g1] = $signed(v[6:0]);

                // index = 256 + (v >> 7), v is signed
                assign v_sh    = (v >>> 7);
                assign idx_raw = 16'sd256 + v_sh;

                // clamp index to [0..511] to avoid OOB when accessing idx+1
                assign idx_clamped_w[g1] =
                    (idx_raw[`INT16_SIZE-1] == 1'b1) ? 10'd0   :
                    (idx_raw > 16'sd511)            ? 10'd511 :
                                                       idx_raw[9:0];
            end
        end
    endgenerate

    integer s1i;
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            valid_s1 <= 1'b0;
            for (s1i = 0; s1i < LANES; s1i = s1i + 1) begin
                offset_s1[s1i] <= '0;
                idx_s1[s1i]    <= '0;
            end
        end else begin
            valid_s1 <= lookup_fire;
            for (s1i = 0; s1i < LANES; s1i = s1i + 1) begin
                offset_s1[s1i] <= offset_w[s1i];
                idx_s1[s1i]    <= idx_clamped_w[s1i];
            end
        end
    end

    // =========================================================
    // Stage 2:
    //   - read LUT
    //   - register base / nextv / offset
    // =========================================================
    reg                               valid_s2;
    reg [6:0]                         offset_r [0:LANES-1];
    reg signed [OUT_WIDTH-1:0]        base_r   [0:LANES-1];
    reg signed [OUT_WIDTH-1:0]        nextv_r  [0:LANES-1];
    reg                               valid_s2_delayed;
    reg [6:0]                         offset_r_delayed [0:LANES-1];

    // wire signed [OUT_WIDTH-1:0]       base_w   [0:LANES-1];
    // wire signed [OUT_WIDTH-1:0]       nextv_w   [0:LANES-1];

    genvar g_mem;
    generate
        for (g_mem = 0; g_mem < LANES; g_mem = g_mem + 1) begin : GEN_LANE_MEM
            lut_lane_mem #(
                .OUT_WIDTH(OUT_WIDTH),
                .NUM_WORDS(NUM_WORDS)
            ) lane_mem_inst (
                .clk(clk),
                .we(loading && sram_lut_en_d),
                .write_addr(load_cnt),
                .write_data(lut_data_in),
                .read_idx_base(idx_s1[g_mem]),
                .read_data_base(base_r[g_mem]),
                .read_idx_next(INTERP ? (idx_s1[g_mem] + 10'd1) : idx_s1[g_mem]),
                .read_data_next(nextv_r[g_mem])
            );
        end
    endgenerate

    integer s2i;
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            valid_s2 <= 1'b0; //this already handles the reset?
            for (s2i = 0; s2i < LANES; s2i = s2i + 1) begin
                offset_r[s2i] <= '0;
                offset_r_delayed[s2i] <= '0;
                //Not sure if we should still keep this reset
                // base_r[s2i]   <= '0;
                // nextv_r[s2i]  <= '0;
            end
        end else begin
            valid_s2_delayed <= valid_s1;
            valid_s2 <= valid_s2_delayed;
            if (valid_s1) begin
                for (s2i = 0; s2i < LANES; s2i = s2i + 1) begin
                offset_r_delayed[s2i] <= offset_s1[s2i];
                offset_r[s2i] <= offset_r_delayed[s2i];
                // base_r[s2i] <= base_w[s2i];
                // nextv_r[s2i] <= nextv_w[s2i];
                //This should be handled inside lane memory
                // base_r[s2i]   <= LUT_mem[s2i][idx_s1[s2i]];
                // if (!INTERP)
                //     nextv_r[s2i] <= LUT_mem[s2i][idx_s1[s2i]];
                // else
                //     nextv_r[s2i] <= LUT_mem[s2i][idx_s1[s2i] + 10'd1];
                end
            end
            
        end
    end

    // =========================================================
    // Stage 3:
    //   - slope / multiply / delta / sum / saturate
    //   - register final output
    // =========================================================
    wire signed [OUT_WIDTH-1:0] data_out_vec_s3 [0:LANES-1];

    genvar g3;
    generate
        for (g3 = 0; g3 < LANES; g3 = g3 + 1) begin : GEN_STAGE3_COMB
            if (!INTERP) begin : GEN_DIRECT_S3
                assign data_out_vec_s3[g3] = base_r[g3];
            end else begin : GEN_INTERP_S3
                wire signed [`INT16_SIZE-1:0] slope;
                wire signed [`INT32_SIZE-1:0] prod;
                wire signed [`INT32_SIZE-1:0] delta;
                wire signed [`INT32_SIZE-1:0] sum;
                wire signed [`INT16_SIZE-1:0] sat;

                assign slope = nextv_r[g3] - base_r[g3];

                // delta = (slope * offset + 64) >> 7
                assign prod  = $signed(slope) * $signed({1'b0, offset_r[g3]});
                assign delta = (prod + 32'sd64) >>> 7;

                assign sum   = $signed(base_r[g3]) + delta;

                // saturate to int16
                assign sat =
                    (sum > 32'sd32767)    ? 16'sd32767  :
                    (sum < -32'sd32768)   ? -16'sd32768 :
                                            $signed(sum[`INT16_SIZE-1:0]);

                assign data_out_vec_s3[g3] = $signed(sat[OUT_WIDTH-1:0]);
            end
        end
    endgenerate

    // -------------------------
    // Output register
    // -------------------------
    integer k;
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            output_valid <= 1'b0;
            data_out     <= '0;
        end else begin
            if (valid_s2) begin
                for (k = 0; k < LANES; k = k + 1) begin
                    data_out[k*OUT_WIDTH +: OUT_WIDTH] <= data_out_vec_s3[k];
                end
            end
            output_valid <= valid_s2;
        end
    end

endmodule

`default_nettype wire