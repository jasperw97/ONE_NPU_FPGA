`timescale 1ns/1ps
`default_nettype wire
`include "params.vh"

module controller #(
    parameter int MN_WIDTH   = 16,           // M、N、K bit width
    parameter int LANES = 64
) (
    input  logic                        clk,
    input  logic                        rst_n,
     
    // control
    input  logic                        op_valid_i,
    input  logic [3:0]                  op_code_i,
    input  logic [MN_WIDTH-1:0]         M,
    input  logic [MN_WIDTH-1:0]         N,
    input  logic [MN_WIDTH-1:0]         K,
    input  logic [2*MN_WIDTH:0]         total_words_i,
    output logic                        done,

    // input SRAM read interface
    output logic                        in_sram_en,
    output logic [`SRAM_ADDR_WIDTH-1:0]       in_sram_addr,
    input  logic [`SRAM_WIDTH_O-1:0]    in_sram_rdata,

    // from SA
    input  logic [`SRAM_ADDR_WIDTH-1:0]       input_addr_x,
    input  logic [`SRAM_ADDR_WIDTH-1:0]       input_addr_y,
    input  logic [`SRAM_ADDR_WIDTH-1:0]       weight_addr_x,
    input  logic [`SRAM_ADDR_WIDTH-1:0]       weight_addr_y,
    output logic [`SRAM_ADDR_WIDTH-1:0]       data_addr,
    output logic [`SRAM_ADDR_WIDTH-1:0]       weight_addr,

    // to elementwise unit
    output logic                        sub_en,     // data_valid to elementwise
    output logic [`SRAM_WIDTH_O-1:0]    sub_data,
    output logic                        add_en,     // data_valid to elementwise
    output logic [`SRAM_WIDTH_O-1:0]    add_data,
    output logic                        mul_en,     // data_valid to elementwise
    output logic [`SRAM_WIDTH_O-1:0]    mul_data,
    output logic                        exp_en,     // data_valid to elementwise
    output logic [`SRAM_WIDTH_O-1:0]    exp_data,
    output logic                        rcp_en,     // data_valid to elementwise
    output logic [`SRAM_WIDTH_O-1:0]    rcp_data,

    // from elementwise unit
    input  logic                        sub_valid,  // result_valid from elementwise
    input  logic [`SRAM_WIDTH_O-1:0]    sub_output,
    input  logic                        add_valid,
    input  logic [`SRAM_WIDTH_O-1:0]    add_output,
    input  logic                        mul_valid,
    input  logic [`SRAM_WIDTH_O-1:0]    mul_output,
    input  logic                        exp_valid,
    input  logic [`SRAM_WIDTH_O-1:0]    exp_output,
    input  logic                        rcp_valid,
    input  logic [`SRAM_WIDTH_O-1:0]    rcp_output,

    // output SRAM write interface
    output logic                        out_sram_we,
    output logic [`SRAM_ADDR_WIDTH-1:0]  out_sram_addr,
    output logic [`SRAM_WIDTH_O-1:0]    out_sram_wdata
);

    // ============================================================
    // State
    // ============================================================
    typedef enum logic [1:0] {IDLE, RUN, FINISH} state_t;
    state_t state, next_state;

    // ============================================================
    // Datapath regs
    // ============================================================
    logic [MN_WIDTH-1:0]    M_r, N_r, K_r;
    logic [MN_WIDTH:0]      words_per_row;     
    logic [2*MN_WIDTH:0]    total_words;       // M * words_per_row
    logic [2*MN_WIDTH-1:0]  rd_count;          // send # of read request
    logic [2*MN_WIDTH-1:0]  wr_count;          // write back # of output

    // SRAM: 1-cycle latency
    logic                   rd_req_fire;       // this cycle: send read request
    logic                   rd_valid_d1;       // next cycle: rdata -> valid

    logic                   go_run;
    logic                   go_idle_from_finish;
    logic                   start_i;
    logic                   output_valid;


    logic [3:0]             active_op_r;

    // address mapping helper
    logic [MN_WIDTH-1:0]    K_cfg;
    logic [MN_WIDTH:0]      n_tiles_cfg;
    logic [`SRAM_ADDR_WIDTH-1:0]  data_addr_calc;
    logic [`SRAM_ADDR_WIDTH-1:0]  weight_addr_calc;

    assign go_run               = (state == IDLE)   && (next_state == RUN);
    assign go_idle_from_finish  = (state == FINISH) && (next_state == IDLE);
    // SA and reserved opcodes share the issue bus but are ignored here.
    assign start_i              = op_valid_i &&
                                  ((op_code_i == `OP_ADD) ||
                                   (op_code_i == `OP_SUB) ||
                                   (op_code_i == `OP_MUL) ||
                                   (op_code_i == `OP_EXP) ||
                                   (op_code_i == `OP_RCP));


    always_comb begin
        unique case (active_op_r)
            `OP_SUB: output_valid = sub_valid;
            `OP_ADD: output_valid = add_valid;
            `OP_MUL: output_valid = mul_valid;
            `OP_EXP: output_valid = exp_valid;
            `OP_RCP: output_valid = rcp_valid;
            default:   output_valid = 1'b0;
        endcase
    end

    // ============================================================
    // Address mapping
    // TB preload 的 SRAM address mapping
    //
    // data bank:
    //   addr = tile_m * K + k_col
    //        = input_addr_y * K + input_addr_x
    //
    // weight bank:
    //   addr = k_row * ceil(N/8) + tile_n
    //        = weight_addr_y * words_per_row + weight_addr_x
    // ============================================================
    always_comb begin
        if (state == RUN || state == FINISH) begin
            K_cfg       = K_r;
            n_tiles_cfg = words_per_row;
        end else begin
            K_cfg       = K;
            n_tiles_cfg = (N + (LANES-1)) / LANES;
        end

        data_addr_calc   = input_addr_y * K_cfg + input_addr_x;
        weight_addr_calc = weight_addr_y * n_tiles_cfg + weight_addr_x;
    end

    assign data_addr   = data_addr_calc;
    assign weight_addr = weight_addr_calc;

    // ============================================================
    // 1) Next-state logic 
    // ============================================================
    always_comb begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start_i) next_state = RUN;
            end

            RUN: begin
                if ((total_words != 0) && (wr_count == total_words)) next_state = FINISH;
            end

            FINISH: begin
                if (!start_i) next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // ============================================================
    // 2) Output logic (combinational outputs + rd_req_fire)
    // ============================================================
    always_comb begin
        // defaults
        in_sram_en     = 1'b0;
        in_sram_addr   = '0;

        sub_en         = 1'b0;
        sub_data       = '0;
        add_en         = 1'b0;
        add_data       = '0;
        mul_en         = 1'b0;
        mul_data       = '0;
        exp_en         = 1'b0;
        exp_data       = '0;
        rcp_en         = 1'b0;
        rcp_data       = '0;

        out_sram_we    = 1'b0;
        out_sram_addr  = '0;
        out_sram_wdata = '0;

        done           = 1'b0;

        rd_req_fire    = 1'b0;

        case (state)
            IDLE: begin
                // wait start_i
            end

            RUN: begin
                // 1) send SRAM read request（until rd_count == total_words）
                if (rd_count < total_words) begin
                    in_sram_en   = 1'b1;
                    in_sram_addr = rd_count[`SRAM_ADDR_WIDTH-1:0];
                    rd_req_fire  = 1'b1;
                end

                // 2) send last cycle data to the op latched by the start pulse.
                if (rd_valid_d1) begin
                    sub_en   = (active_op_r == `OP_SUB);
                    sub_data = in_sram_rdata;
                    add_en   = (active_op_r == `OP_ADD);
                    add_data = in_sram_rdata;
                    mul_en   = (active_op_r == `OP_MUL);
                    mul_data = in_sram_rdata;
                    exp_en   = (active_op_r == `OP_EXP);
                    exp_data = in_sram_rdata;
                    rcp_en   = (active_op_r == `OP_RCP);
                    rcp_data = in_sram_rdata;
                end

                // 3) get elementwise output from the active op then write back SRAM
                out_sram_we    = output_valid;
                out_sram_addr  = wr_count[`SRAM_ADDR_WIDTH-1:0];
                unique case (active_op_r)
                    `OP_SUB: out_sram_wdata = sub_output;
                    `OP_ADD: out_sram_wdata = add_output;
                    `OP_MUL: out_sram_wdata = mul_output;
                    `OP_EXP: out_sram_wdata = exp_output;
                    `OP_RCP: out_sram_wdata = rcp_output;
                    default: out_sram_wdata = '0;
                endcase
            end

            FINISH: begin
                done = 1'b1;
            end

            default: begin
            end
        endcase
    end

    // ============================================================
    // 3) State register
    // ============================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // ==============
    // DEBUG INFO
    // ==============
    // always_ff @(posedge clk) begin
    //     if (state == RUN && rd_valid_d1) begin
    //         $display("[LOAD] in_sram_addr=%0d rdata=0x%016h", in_sram_addr-1, in_sram_rdata);
    //     end
    // end
    //
    // always_ff @(posedge clk) begin
    //     if (state == RUN) begin
    //         $display("[LOAD_MAP] input_addr=(%0d,%0d) -> data_addr=%0d | weight_addr=(%0d,%0d) -> weight_addr=%0d",
    //                  input_addr_x, input_addr_y, data_addr,
    //                  weight_addr_x, weight_addr_y, weight_addr);
    //     end
    // end

    // ============================================================
    // 4) Datapath registers
    // ============================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            M_r           <= '0;
            N_r           <= '0;
            K_r           <= '0;
            total_words   <= '0;
            words_per_row <= '0;
            rd_count      <= '0;
            wr_count      <= '0;
            rd_valid_d1   <= 1'b0;
            active_op_r   <= `OP_IDLE;
        end else begin
            if (state != RUN) begin
                rd_valid_d1 <= 1'b0;
            end

            // IDLE -> RUN
            if (go_run) begin
                M_r           <= M;
                N_r           <= N;
                K_r           <= K;
                words_per_row <= (N + (LANES-1)) / LANES;
                // Prefer descriptor/metadata word count for EW-only jobs; keep
                // M*ceil(N/LANES) as the legacy fallback when it is not supplied.
                total_words   <= (total_words_i != '0) ?
                                 total_words_i :
                                 (M * ((N + (LANES-1)) / LANES));
                rd_count      <= '0;
                wr_count      <= '0;
                rd_valid_d1   <= 1'b0;
                active_op_r   <= op_code_i;
            end

            // RUN 
            if (state == RUN) begin
                // 1-cycle latency
                rd_valid_d1 <= rd_req_fire;

                if (rd_req_fire) begin
                    rd_count <= rd_count + 1;
                end

                if (output_valid) begin
                    wr_count <= wr_count + 1;
                end
            end

            // FINISH -> IDLE
            if (go_idle_from_finish) begin
                rd_count    <= '0;
                wr_count    <= '0;
                rd_valid_d1 <= 1'b0;
                active_op_r <= `OP_IDLE;
            end
        end
    end

endmodule
`default_nettype wire