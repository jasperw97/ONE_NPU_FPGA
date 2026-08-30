`timescale 1ns/1ps
`default_nettype wire
`include "params.vh"

// ============================================================================
// Broadcast Unit
// ============================================================================
// Expands one compact broadcast operand into row words before issue.
//
// Preparation:
//   B_IDLE -- start --> B_COUNT_ROW_WORDS
//                            |
//                            v
//                     B_READ_SOURCE -> B_WAIT_SOURCE -> B_EXPAND_ROW
//                            ^                              |       |
//                            +------ next source word ------+       +-- row done --> B_DONE
//
// Runtime:
//   word_col_idx -> row_buffer -> selected broadcast operand
//
// - The top level selects src1/weight for selector 1 or src0/data for selector 2.
// - Baseline issues one operation at a time, so only one row is prepared.
// - Runtime read latency is one cycle.
// - Runtime logic uses no division or modulo.
// - Single-word: broadcast_count <= LANES, so the compact vector fits in one SRAM word.
// - Multi-word: broadcast_count > LANES, so the compact vector spans multiple SRAM words.
// ============================================================================
module broadcast_unit #(
    parameter int LANES                = `LANES,
    parameter int MAX_BROADCAST_N      = 1024,
    parameter int WORD_COL_IDX_WIDTH   = 6
) (
    input  logic clk,
    input  logic rst_n,

    input  logic clear_i,
    input  logic start_i,

    input  logic [2:0]                  prep_src_bank_i,
    input  logic [`INT32_SIZE-1:0]      prep_n_i,
    input  logic [`INT32_SIZE-1:0]      prep_count_i,

    output logic                        prep_busy_o,
    output logic                        prep_done_o,

    output logic                        prep_read_en_o,
    output logic [2:0]                  prep_read_bank_o,
    output logic [`SRAM_ADDR_WIDTH-1:0] prep_read_addr_o,
    input  logic [`SRAM_WIDTH_O-1:0]    prep_read_data_i,

    input  logic                          runtime_read_en_i,
    input  logic [WORD_COL_IDX_WIDTH-1:0] runtime_word_col_idx_i,
    output logic [`SRAM_WIDTH_O-1:0]      runtime_read_data_o
);

    localparam int LANE_IDX_WIDTH = (LANES <= 1) ? 1 : $clog2(LANES);
    localparam int LANE_COUNT_WIDTH = (LANES <= 1) ? 1 : $clog2(LANES + 1);
    // Compile-time capacity of one expanded row; indices range 0..N-1 words.
    localparam int MAX_ROW_WORDS = (MAX_BROADCAST_N + LANES - 1) / LANES;
    localparam int ROW_WORD_IDX_WIDTH = (MAX_ROW_WORDS <= 1) ? 1 : $clog2(MAX_ROW_WORDS);
    localparam int BROADCAST_LANE_SUM_WIDTH = (LANES <= 1) ? 1 : $clog2(2 * LANES);

    typedef enum logic [2:0] {
        B_IDLE,
        B_COUNT_ROW_WORDS,
        B_READ_SOURCE,
        B_WAIT_SOURCE,
        B_EXPAND_ROW,
        B_DONE
    } broadcast_state_t;

    broadcast_state_t broadcast_state_r;

    logic [`SRAM_WIDTH_O-1:0]      row_buffer_r [0:MAX_ROW_WORDS-1];
    logic                          row_ready_r;

    logic [`INT32_SIZE-1:0]        row_remaining_r;
    logic [ROW_WORD_IDX_WIDTH-1:0] row_last_word_idx_r;
    logic [ROW_WORD_IDX_WIDTH-1:0] dst_word_idx_r;
    logic [LANE_IDX_WIDTH-1:0]     dst_lane_idx_r;
    logic [`SRAM_WIDTH_O-1:0]      dst_word_build_r;

    logic [`INT32_SIZE-1:0]        broadcast_count_r;
    logic [`INT32_SIZE-1:0]        source_element_idx_r;
    logic [LANE_IDX_WIDTH-1:0]     source_lane_idx_r;
    logic [`SRAM_ADDR_WIDTH-1:0]   source_word_addr_r;
    logic [`SRAM_WIDTH_O-1:0]      source_word0_r;
    logic [`SRAM_WIDTH_O-1:0]      source_word_data_r;

    logic                          expand_single_word;
    logic [`INT32_SIZE-1:0]        expand_copy_count;
    logic [`INT32_SIZE-1:0]        expand_dst_remaining;
    logic [`INT32_SIZE-1:0]        expand_source_word_remaining;
    logic [`INT32_SIZE-1:0]        expand_source_period_remaining;
    logic [`SRAM_WIDTH_O-1:0]      expand_word_data;
    logic [LANE_IDX_WIDTH-1:0]     expand_source_lane [0:LANES-1];
    logic [LANE_COUNT_WIDTH-1:0]   single_word_count;
    logic [LANE_IDX_WIDTH-1:0]     single_word_lane_idx_r [0:LANES-1];
    logic [LANE_IDX_WIDTH-1:0]     single_word_lane_idx_calc [0:LANES-1];
    logic [LANE_IDX_WIDTH-1:0]     single_word_lane_base;
    logic [LANE_IDX_WIDTH-1:0]     single_word_next_source_idx;
    logic                          expand_dst_word_complete;
    logic                          expand_last_destination_word;
    logic                          expand_source_period_complete;
    logic                          expand_source_word_complete;

    // Baseline-equivalent bounded remainder used only when the complete compact
    // vector is already present in source word 0. value is always below 2*LANES.
    function automatic logic [LANE_IDX_WIDTH-1:0] broadcast_lane_mod(
        input logic [BROADCAST_LANE_SUM_WIDTH-1:0] value,
        input logic [LANE_COUNT_WIDTH-1:0] count
    );
        logic [LANE_COUNT_WIDTH:0] remainder;
        begin
            remainder = '0;
            if (count <= 1) begin
                broadcast_lane_mod = '0;
            end else begin
                for (int bit_i = BROADCAST_LANE_SUM_WIDTH - 1;
                     bit_i >= 0; bit_i = bit_i - 1) begin
                    remainder = {remainder[LANE_COUNT_WIDTH-1:0], value[bit_i]};
                    if (remainder >= {1'b0, count}) begin
                        remainder = remainder - {1'b0, count};
                    end
                end
                broadcast_lane_mod = remainder[LANE_IDX_WIDTH-1:0];
            end
        end
    endfunction

    assign prep_busy_o = (broadcast_state_r != B_IDLE) &&
                            (broadcast_state_r != B_DONE);
    assign prep_done_o = (broadcast_state_r == B_DONE);

    assign prep_read_en_o = (broadcast_state_r == B_READ_SOURCE);
    assign prep_read_bank_o = prep_src_bank_i;
    assign prep_read_addr_o = source_word_addr_r;

    // -------------------------------------------------------------------------
    // Expansion path selection
    // -------------------------------------------------------------------------
    always_comb begin
        expand_single_word = (broadcast_count_r <= LANES);
        expand_dst_remaining = LANES - dst_lane_idx_r;
        expand_source_word_remaining = LANES - source_lane_idx_r;
        expand_source_period_remaining = broadcast_count_r - source_element_idx_r;
        single_word_count = broadcast_count_r[LANE_COUNT_WIDTH-1:0];

        // ---------------------------------------------------------------------
        // Multi-word copy count
        // ---------------------------------------------------------------------
        // expand_copy_count = min(destination word remaining space,
        //                         source SRAM word remaining data,
        //                         compact period remaining data)
        expand_copy_count = expand_dst_remaining;
        if (expand_source_word_remaining < expand_copy_count) begin
            expand_copy_count = expand_source_word_remaining;
        end
        if (expand_source_period_remaining < expand_copy_count) begin
            expand_copy_count = expand_source_period_remaining;
        end

        expand_word_data = expand_single_word ? '0 : dst_word_build_r;
        single_word_next_source_idx = broadcast_lane_mod(source_element_idx_r + LANES, single_word_count);
        single_word_lane_base = (broadcast_state_r == B_WAIT_SOURCE) ? '0 : single_word_next_source_idx;

        for (int lane_i = 0; lane_i < LANES; lane_i = lane_i + 1) begin
            expand_source_lane[lane_i] = '0;
            single_word_lane_idx_calc[lane_i] = broadcast_lane_mod(single_word_lane_base + lane_i, single_word_count);
        end

        // ---------------------------------------------------------------------
        // Single-word path: broadcast_count <= LANES
        // ---------------------------------------------------------------------
        if (expand_single_word) begin
            for (int lane_i = 0; lane_i < LANES; lane_i = lane_i + 1) begin
                expand_word_data[lane_i*`INT16_SIZE +: `INT16_SIZE] = source_word0_r[single_word_lane_idx_r[lane_i]*`INT16_SIZE +: `INT16_SIZE];
            end
        end else begin
            // -----------------------------------------------------------------
            // Multi-word path: broadcast_count > LANES
            // -----------------------------------------------------------------
            for (int lane_i = 0; lane_i < LANES; lane_i = lane_i + 1) begin
                if ((lane_i >= dst_lane_idx_r) && (lane_i < (dst_lane_idx_r + expand_copy_count))) begin
                    expand_source_lane[lane_i] = source_lane_idx_r + lane_i - dst_lane_idx_r;
                    expand_word_data[lane_i*`INT16_SIZE +: `INT16_SIZE] = source_word_data_r[expand_source_lane[lane_i]*`INT16_SIZE +: `INT16_SIZE];
                end
            end
        end
    end

    assign expand_dst_word_complete = expand_single_word || (expand_copy_count >= expand_dst_remaining);
    assign expand_last_destination_word = expand_dst_word_complete && (dst_word_idx_r == row_last_word_idx_r);
    assign expand_source_period_complete =
        !expand_single_word &&
        (expand_copy_count >= expand_source_period_remaining);
    assign expand_source_word_complete =
        !expand_single_word &&
        (expand_copy_count >= expand_source_word_remaining);

    // Registered lookup matches the one-cycle runtime read latency expected by
    // the element-wise datapath.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            runtime_read_data_o <= '0;
        end else if (runtime_read_en_i) begin
            if (row_ready_r && (runtime_word_col_idx_i < MAX_ROW_WORDS)) begin
                runtime_read_data_o <= row_buffer_r[runtime_word_col_idx_i];
            end else begin
                runtime_read_data_o <= '0;
            end
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            broadcast_state_r <= B_IDLE;
            row_ready_r <= 1'b0;
            row_remaining_r <= '0;
            row_last_word_idx_r <= '0;
            dst_word_idx_r <= '0;
            dst_lane_idx_r <= '0;
            dst_word_build_r <= '0;
            broadcast_count_r <= 1;
            source_element_idx_r <= '0;
            source_lane_idx_r <= '0;
            source_word_addr_r <= '0;
            source_word0_r <= '0;
            source_word_data_r <= '0;
            for (int lane_i = 0; lane_i < LANES; lane_i = lane_i + 1) begin
                single_word_lane_idx_r[lane_i] <= '0;
            end
        end else if (clear_i) begin
            broadcast_state_r <= B_IDLE;
            row_ready_r <= 1'b0;
            row_remaining_r <= '0;
            row_last_word_idx_r <= '0;
            dst_word_idx_r <= '0;
            dst_lane_idx_r <= '0;
            dst_word_build_r <= '0;
            broadcast_count_r <= 1;
            source_element_idx_r <= '0;
            source_lane_idx_r <= '0;
            source_word_addr_r <= '0;
            source_word0_r <= '0;
            source_word_data_r <= '0;
            for (int lane_i = 0; lane_i < LANES; lane_i = lane_i + 1) begin
                single_word_lane_idx_r[lane_i] <= '0;
            end
        end else if (start_i) begin
            row_ready_r <= 1'b0;
            row_remaining_r <= prep_n_i;
            row_last_word_idx_r <= '0;
            broadcast_count_r <= (prep_count_i <= 1) ? 1 : prep_count_i;
            dst_word_build_r <= '0;
            if (prep_n_i == '0) begin
                broadcast_state_r <= B_DONE;
            end else begin
                broadcast_state_r <= B_COUNT_ROW_WORDS;
            end
        end else begin
            unique case (broadcast_state_r)
                B_IDLE: begin
                end

                // Derive ceil(N/LANES)-1 with bounded subtracts before reading
                // source data. This path is outside runtime issue timing.
                B_COUNT_ROW_WORDS: begin
                    if ((row_remaining_r > LANES) &&
                        (row_last_word_idx_r < MAX_ROW_WORDS - 1)) begin
                        row_remaining_r <= row_remaining_r - LANES;
                        row_last_word_idx_r <= row_last_word_idx_r + 1'b1;
                    end else begin
                        dst_word_idx_r <= '0;
                        dst_lane_idx_r <= '0;
                        dst_word_build_r <= '0;
                        source_element_idx_r <= '0;
                        source_lane_idx_r <= '0;
                        source_word_addr_r <= '0;
                        broadcast_state_r <= B_READ_SOURCE;
                    end
                end

                // Tensor SRAM has one-cycle read latency, so request and capture
                // use separate states. B_WAIT_SOURCE also registers compact-vector
                // lane indices, separating remainder logic from the lane mux.
                B_READ_SOURCE: begin
                    broadcast_state_r <= B_WAIT_SOURCE;
                end

                B_WAIT_SOURCE: begin
                    source_word_data_r <= prep_read_data_i;
                    if (source_word_addr_r == '0) begin
                        source_word0_r <= prep_read_data_i;
                    end
                    if (expand_single_word) begin
                        for (int lane_i = 0; lane_i < LANES; lane_i = lane_i + 1) begin
                            single_word_lane_idx_r[lane_i] <= single_word_lane_idx_calc[lane_i];
                        end
                    end
                    broadcast_state_r <= B_EXPAND_ROW;
                end

                B_EXPAND_ROW: begin
                    // -----------------------------------------------------------------
                    // Shared destination path
                    // -----------------------------------------------------------------
                    if (expand_dst_word_complete) begin
                        // destination boundary -> write the next row word
                        row_buffer_r[dst_word_idx_r] <= expand_word_data;
                        dst_word_build_r <= '0;
                        dst_lane_idx_r <= '0;
                    end else begin
                        dst_word_build_r <= expand_word_data;
                        dst_lane_idx_r <= dst_lane_idx_r + expand_copy_count;
                    end

                    if (expand_last_destination_word) begin
                        row_ready_r <= 1'b1;
                        broadcast_state_r <= B_DONE;
                    end else begin
                        if (expand_dst_word_complete) begin
                            dst_word_idx_r <= dst_word_idx_r + 1'b1;
                        end

                        // -------------------------------------------------------------
                        // Single-word path: broadcast_count <= LANES
                        // -------------------------------------------------------------
                        if (expand_single_word) begin
                            source_element_idx_r <= single_word_next_source_idx;
                            for (int lane_i = 0; lane_i < LANES; lane_i = lane_i + 1) begin
                                single_word_lane_idx_r[lane_i] <= single_word_lane_idx_calc[lane_i];
                            end
                        end else begin
                            // ---------------------------------------------------------
                            // Multi-word path: broadcast_count > LANES
                            // ---------------------------------------------------------
                            if (expand_source_period_complete) begin
                                // period boundary -> wrap to compact element 0
                                source_element_idx_r <= '0;
                                source_lane_idx_r <= '0;
                                source_word_addr_r <= '0;
                                source_word_data_r <= source_word0_r;
                            end else if (expand_source_word_complete) begin
                                // source-word boundary -> read the next SRAM word
                                source_element_idx_r <= source_element_idx_r + expand_copy_count;
                                source_lane_idx_r <= '0;
                                source_word_addr_r <= source_word_addr_r + 1'b1;
                                broadcast_state_r <= B_READ_SOURCE;
                            end else begin
                                source_element_idx_r <= source_element_idx_r + expand_copy_count;
                                source_lane_idx_r <= source_lane_idx_r + expand_copy_count;
                            end
                        end
                    end
                end

                B_DONE: begin
                end

                default: begin
                    broadcast_state_r <= B_IDLE;
                end
            endcase
        end
    end

`ifndef SYNTHESIS
    initial begin
        if (MAX_BROADCAST_N <= 0) begin
            $error("[broadcast_unit] MAX_BROADCAST_N must be positive.");
        end
    end

    always_ff @(posedge clk) begin
        if (rst_n && start_i) begin
            if (prep_n_i > MAX_BROADCAST_N) begin
                $error("[broadcast_unit] N=%0d exceeds MAX_BROADCAST_N=%0d",
                       prep_n_i, MAX_BROADCAST_N);
            end
            if (prep_count_i > MAX_BROADCAST_N) begin
                $error("[broadcast_unit] count=%0d exceeds MAX_BROADCAST_N=%0d",
                       prep_count_i, MAX_BROADCAST_N);
            end
        end
    end
`endif

endmodule

`default_nettype wire