`default_nettype wire
`include "params.vh"
//scaled down version to 8x8 to see if vivado will run

module SystolicArray_OS_INT8_REQUANT_SRAM_8x8 #(
    parameter int PE_SIZE = 8,
    parameter int MAX_M   = 4096,
    parameter int MAX_K   = 4096,
    parameter int MAX_N   = 4096
) (
    input  logic                                          clk,
    input  logic                                          rst_n,

    // input control
    input  logic                                          start_i,
    input  logic [$clog2(MAX_M)-1:0]                      M,
    input  logic [$clog2(MAX_K)-1:0]                      K,
    input  logic [$clog2(MAX_N)-1:0]                      N,

    // data buses (int8 vectors)
    input  logic                                          sram_data_valid,
    output logic                                          sram_req_valid,
    input  logic signed [`INT8_SIZE*PE_SIZE-1:0]          input_data,
    input  logic signed [`INT8_SIZE*PE_SIZE-1:0]          weight_data,

    // requant params 
    input  logic signed [`INT32_SIZE-1:0]                 quantized_multiplier,
    input  logic signed [`INT32_SIZE-1:0]                 shift,
    input  logic signed [`INT32_SIZE-1:0]                 output_offset,
    input  logic signed [`INT32_SIZE-1:0]                 act_min,
    input  logic signed [`INT32_SIZE-1:0]                 act_max,

    // output control
    output logic busy,

    // address to "SRAM"
    output logic [`SRAM_ADDR_WIDTH-1:0]                    input_addr_x,
    output logic [`SRAM_ADDR_WIDTH-1:0]                    input_addr_y,
    output logic [`SRAM_ADDR_WIDTH-1:0]                    weight_addr_x,
    output logic [`SRAM_ADDR_WIDTH-1:0]                    weight_addr_y,

    // int32 debug stream
    output logic                                           output_valid_i32,
    output logic [`SRAM_ADDR_WIDTH-1:0]                    output_addr_x_i32,
    output logic [`SRAM_ADDR_WIDTH-1:0]                    output_addr_y_i32,
    output logic signed [`INT32_SIZE*PE_SIZE-1:0]          output_data_i32,

    // requant INT16 stream
    output logic                                           output_valid_i16,
    output logic [`SRAM_ADDR_WIDTH-1:0]                    output_addr_x_i16,
    output logic [`SRAM_ADDR_WIDTH-1:0]                    output_addr_y_i16,
    output logic signed [`INT16_SIZE*PE_SIZE-1:0]          output_data_i16,
    output logic                                           sa_done
);

    // ------------------------
    // Declaration
    // ------------------------

    localparam int ADDR_BITS = $clog2(PE_SIZE);
    localparam int REQ_FIFO_DEPTH = 32;
    localparam int REQ_FIFO_W     = 2 * `SRAM_ADDR_WIDTH;

    genvar g_i, g_j;

    enum logic [2:0] { IDLE, CLEAN_BUBBLE, RUN_AND_LOAD, RUN_WAIT, OUT, OUT_STALL, REQUANT_BUBBLE } state, next_state;

    logic [$clog2(MAX_M)-1:0] M_r;
    logic [$clog2(MAX_K)-1:0] K_r;
    logic [$clog2(MAX_N)-1:0] N_r;
    logic signed [`INT32_SIZE-1:0] quantized_multiplier_r, shift_r;
    logic signed [`INT32_SIZE-1:0] output_offset_r, act_min_r, act_max_r;

    logic [$clog2(MAX_M/PE_SIZE)-1:0] num_tile_M;
    logic [$clog2(MAX_N/PE_SIZE)-1:0] num_tile_N;

    logic [$clog2(PE_SIZE + 9):0] wait_counter;

    logic [$clog2(MAX_K)-1:0]         input_addr_x_r, weight_addr_y_r;
    logic [$clog2(MAX_N/PE_SIZE)-1:0] weight_addr_x_r;
    logic [$clog2(MAX_M)-1:0]         input_addr_y_r;

    assign input_addr_x  = input_addr_x_r;
    assign input_addr_y  = input_addr_y_r;
    assign weight_addr_x = weight_addr_x_r;
    assign weight_addr_y = weight_addr_y_r;

    // requant addr fifo
    logic [REQ_FIFO_W-1:0] req_fifo_push_data;
    logic [REQ_FIFO_W-1:0] req_fifo_pop_data;
    logic                  req_fifo_push, req_fifo_pop;
    logic                  req_fifo_full, req_fifo_empty;
    logic [$clog2(REQ_FIFO_DEPTH):0] req_fifo_count;

    logic requant_done_mqm;
    logic requant_done_d1, requant_done_d2;


    // ------------------------
    // Main FSM
    // ------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else        state <= next_state;
    end

    always_comb begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start_i) next_state = RUN_AND_LOAD;
                else         next_state = IDLE;
            end
            RUN_AND_LOAD: begin
                if (input_addr_x_r == K_r - 1) next_state = RUN_WAIT;
                else                         next_state = RUN_AND_LOAD;
            end
            RUN_WAIT: begin
                if (wait_counter == PE_SIZE + 12) next_state = OUT;
                else                             next_state = RUN_WAIT;
            end
            OUT: begin
                if (output_addr_y_i32[ADDR_BITS-1:0] == PE_SIZE - 1 || output_addr_y_i32 == M_r - 1)
                    next_state = OUT_STALL;
                else
                    next_state = OUT;
            end
            OUT_STALL: begin
                if (output_addr_x_i32 == num_tile_N - 1 && output_addr_y_i32 == M_r) begin
                    next_state = REQUANT_BUBBLE;
                    // $display("SystolicArray_OS_INT8_REQUANT_SRAM: Finished all output tiles.");
                    // $display("state = OUT_STALL");
                    // $display("output_addr_y_i32: %0d", output_addr_y_i32);
                    // $display("output_addr_y_i16: %0d", output_addr_y_i16);
                end
                else
                    next_state = CLEAN_BUBBLE;
            end
            CLEAN_BUBBLE: begin
                next_state = RUN_AND_LOAD;
            end
            REQUANT_BUBBLE: begin
                // if (output_addr_x_i16 == num_tile_N - 1 && output_addr_y_i16 == M_r) begin
                if (req_fifo_empty && !requant_done_d2) begin
                    next_state = IDLE;
                    // $display("state = REQUANT_BUBBLE");
                    // // $display("output_addr_y_i32: %0d", output_addr_y_i32);
                    // $display("output_addr_y_i16: %0d", output_addr_y_i16);
                end
                else
                    next_state = REQUANT_BUBBLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // latch config
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            M_r <= '0; K_r <= '0; N_r <= '0;
            quantized_multiplier_r <= '0;
            shift_r                <= '0;
            output_offset_r        <= '0;
            act_min_r              <= '0;
            act_max_r              <= '0;
        end else if (start_i) begin
            M_r <= M;  K_r <= K;  N_r <= N;
            quantized_multiplier_r <= quantized_multiplier;
            shift_r                <= shift;
            output_offset_r        <= output_offset;
            act_min_r              <= act_min;
            act_max_r              <= act_max;
            // $display("SystolicArray_OS_INT8_REQUANT_SRAM: Received config M=%0d, K=%0d, N=%0d", M, K, N);
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            num_tile_M <= '0;
            num_tile_N <= '0;
        end else begin
            num_tile_M <= (M_r - 1) / PE_SIZE + 1;
            num_tile_N <= (N_r - 1) / PE_SIZE + 1;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)                 wait_counter <= '0;
        else if (state == RUN_WAIT) wait_counter <= wait_counter + 1;
        else                        wait_counter <= '0;
    end

    // ------------------------
    // SRAM data latency control
    // ------------------------
    // logic sram_req_valid;
    // logic sram_data_valid;

    assign sram_req_valid = (state == RUN_AND_LOAD);

    // always_ff @(posedge clk or negedge rst_n) begin
    //     if (!rst_n)
    //         sram_data_valid <= 1'b0;
    //     else
    //         sram_data_valid <= sram_req_valid;
    // end

    // ------------------------
    // Weight address generation
    // ------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            weight_addr_x_r <= '0;
            weight_addr_y_r <= '0;
        end
        else if (state == RUN_AND_LOAD) begin
            if (weight_addr_y_r == K_r - 1) weight_addr_y_r <= weight_addr_y_r;
            else                          weight_addr_y_r <= weight_addr_y_r + 1;
        end
        else if (state == RUN_WAIT && wait_counter == 0) begin
            weight_addr_y_r <= '0;
            if (weight_addr_x_r == num_tile_N - 1) weight_addr_x_r <= '0;
            else                                 weight_addr_x_r <= weight_addr_x_r + 1;
        end
        else if (state == IDLE) begin
            weight_addr_x_r <= '0;
            weight_addr_y_r <= '0;
        end
    end

    // ------------------------
    // Input address generation
    // ------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            input_addr_x_r <= '0;
            input_addr_y_r <= '0;
        end
        else if (state == RUN_AND_LOAD) begin
            if (input_addr_x_r == K_r - 1) input_addr_x_r <= input_addr_x_r;
            else                         input_addr_x_r <= input_addr_x_r + 1;
        end
        else if (state == RUN_WAIT && wait_counter == 0) begin
            input_addr_x_r <= '0;
            if (weight_addr_x_r == num_tile_N - 1) input_addr_y_r <= input_addr_y_r + 1;
            else                                 input_addr_y_r <= input_addr_y_r;
        end
        else if (state == IDLE) begin
            input_addr_x_r <= '0;
            input_addr_y_r <= '0;
        end
    end

    // ------------------------
    // Weight FIFO 
    // ------------------------
    logic signed [`INT8_SIZE-1:0] weight_fifo_out [0:PE_SIZE-1];

    generate
        for (g_i=0; g_i<PE_SIZE; g_i=g_i+1) begin : WEIGHT_FIFO
            logic signed [`INT8_SIZE-1:0] weight_fifo_din;

            always_comb begin
                // if (state == RUN_AND_LOAD)
                    weight_fifo_din = sram_data_valid ? weight_data[((g_i+1)*`INT8_SIZE-1) -: `INT8_SIZE] : '0;
                // else
                //     weight_fifo_din = '0;
            end

            logic signed [`INT8_SIZE-1:0] fifo_mem [0:g_i];

            always_ff @(posedge clk or negedge rst_n) begin
                integer fifo_i;
                if (!rst_n) begin
                    for (fifo_i=0; fifo_i<g_i+1; fifo_i=fifo_i+1) fifo_mem[fifo_i] <= '0;
                end else begin
                    for (fifo_i=0; fifo_i<g_i+1; fifo_i=fifo_i+1) begin
                        if (fifo_i == 0) fifo_mem[0] <= weight_fifo_din;
                        else             fifo_mem[fifo_i] <= fifo_mem[fifo_i-1];
                    end
                end
            end

            assign weight_fifo_out[g_i] = fifo_mem[g_i];
        end
    endgenerate

    // ------------------------
    // Input FIFO 
    // ------------------------
    logic signed [`INT8_SIZE-1:0] input_fifo_out [0:PE_SIZE-1];

    generate
        for (g_j=0; g_j<PE_SIZE; g_j=g_j+1) begin : INPUT_FIFO
            logic signed [`INT8_SIZE-1:0] input_fifo_din;

            always_comb begin
                // if (state == RUN_AND_LOAD)
                    input_fifo_din = sram_data_valid ? input_data[((g_j+1)*`INT8_SIZE-1) -: `INT8_SIZE] : '0;
                // else
                //     input_fifo_din = '0;
            end

            logic signed [`INT8_SIZE-1:0] fifo_mem [0:g_j];

            always_ff @(posedge clk or negedge rst_n) begin
                integer fifo_j;
                if (!rst_n) begin
                    for (fifo_j=0; fifo_j<g_j+1; fifo_j=fifo_j+1) fifo_mem[fifo_j] <= '0;
                end else begin
                    for (fifo_j=0; fifo_j<g_j+1; fifo_j=fifo_j+1) begin
                        if (fifo_j == 0) fifo_mem[0] <= input_fifo_din;
                        else             fifo_mem[fifo_j] <= fifo_mem[fifo_j-1];
                    end
                end
            end

            assign input_fifo_out[g_j] = fifo_mem[g_j];
        end
    endgenerate

    // ------------------------
    // PE array 
    // ------------------------
    logic signed [`INT8_SIZE-1:0]  pe_input_out  [0:PE_SIZE-1][0:PE_SIZE-1];
    logic signed [`INT8_SIZE-1:0]  pe_weight_out [0:PE_SIZE-1][0:PE_SIZE-1];
    logic signed [`INT32_SIZE-1:0] pe_output     [0:PE_SIZE-1][0:PE_SIZE-1];

    generate
        for (g_i=0; g_i<PE_SIZE; g_i=g_i+1) begin : GEN_PE_ROW
            for (g_j=0; g_j<PE_SIZE; g_j=g_j+1) begin : GEN_PE_COL
                logic signed [`INT8_SIZE-1:0] pe_input_in;
                logic signed [`INT8_SIZE-1:0] pe_weight_in;

                if (g_i == 0) assign pe_input_in  = input_fifo_out[g_j];
                else          assign pe_input_in  = pe_input_out[g_i-1][g_j];

                if (g_j == 0) assign pe_weight_in = weight_fifo_out[g_i];
                else          assign pe_weight_in = pe_weight_out[g_i][g_j-1];

                PE_INT8_OS PE_INST (
                    .clk            (clk),
                    .rst_n          (rst_n),
                    // .en             (array_step),
                    .input_data_in  (pe_input_in),
                    .input_data_out (pe_input_out[g_i][g_j]),
                    .weight_data_in (pe_weight_in),
                    .weight_data_out(pe_weight_out[g_i][g_j]),
                    .output_data    (pe_output[g_j][g_i]),
                    .clean          (state == IDLE || state == CLEAN_BUBBLE)
                );
            end
        end
    endgenerate

    // ------------------------
    // Output addr/valid (int32)
    // ------------------------
    assign busy = (state != IDLE);
    // assign sa_done = (state == REQUANT_BUBBLE &&
    //                   output_addr_x_i16 == num_tile_N - 1 &&
    //                   output_addr_y_i16 == M_r);
    assign sa_done = (state == REQUANT_BUBBLE &&
                  output_addr_x_i16 == num_tile_N - 1 &&
                  output_addr_y_i16 == M_r - 1 &&
                  output_valid_i16);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            output_addr_x_i32 <= '0;
            output_addr_y_i32 <= '0;
        end else if (state == OUT) begin
            output_addr_y_i32 <= output_addr_y_i32 + 1;
        end else if (state == OUT_STALL) begin
            output_addr_y_i32 <= input_addr_y_r * PE_SIZE;
            if (output_addr_x_i32 == num_tile_N - 1)
                output_addr_x_i32 <= '0;
            else
                output_addr_x_i32 <= output_addr_x_i32 + 1;
        end else if (state == IDLE) begin
            output_addr_x_i32 <= '0;
            output_addr_y_i32 <= '0;
        end
    end

    assign output_valid_i32 = (state == OUT);

    always_comb begin
        int j;
        for (j=0; j<PE_SIZE; j=j+1) begin
            output_data_i32[((j+1)*`INT32_SIZE-1) -: `INT32_SIZE] =
                pe_output[output_addr_y_i32[ADDR_BITS-1:0]][j];
        end
    end

    // ------------------------
    // Requant stage (int32 -> INT16)
    // ------------------------
    // MultiplyByQuantizedMultiplier uses active-low reset：if (!rst) reset
    // this top-level module: rst_n(active-low)，so rst = rst_n
    logic rst; assign rst = rst_n;

    // per-lane requant
    logic signed [`INT32_SIZE-1:0] requant_32_out     [0:PE_SIZE-1];  
    logic signed [`INT16_SIZE-1:0] requant_16_out     [0:PE_SIZE-1];
    // logic signed [`INT16_SIZE-1:0] requant_16_out_s2  [0:PE_SIZE-1]; 
    logic signed [`INT32_SIZE-1:0] y32                [0:PE_SIZE-1]; 
    logic                          requant_v_out      [0:PE_SIZE-1];
    // logic                          requant_v_p1       [0:PE_SIZE-1];
    // logic                          requant_v_p2       [0:PE_SIZE-1];

    generate
        for (g_i=0; g_i<PE_SIZE; g_i=g_i+1) begin : G_REQUANT
            wire signed [`INT32_SIZE-1:0] x_in;
            assign x_in = output_data_i32[((g_i+1)*`INT32_SIZE-1) -: `INT32_SIZE];

            MultiplyByQuantizedMultiplier u_requant (
                .clk                           (clk),
                .rst                           (rst),
                .x                             (x_in),
                .quantized_multiplier          (quantized_multiplier_r),
                .shift                         (shift_r),
                .input_valid                   (output_valid_i32),
                .output_valid                  (requant_v_out[g_i]),
                .x_mul_by_quantized_multiplier (requant_32_out[g_i])
            );

            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    y32[g_i] <= '0;
                    requant_16_out[g_i] <= '0;
                    // requant_v_p1[g_i] <= 1'b0;
                    // requant_v_p2[g_i] <= 1'b0;
                end else begin
                    y32[g_i] <= requant_32_out[g_i] + output_offset_r;
                    // requant_v_p1[g_i] <= requant_v_out[g_i];
                    
                    requant_16_out[g_i] <= (y32[g_i] > act_max_r) ? act_max_r[`INT16_SIZE-1:0] :
                                              (y32[g_i] < act_min_r) ? act_min_r[`INT16_SIZE-1:0] :
                                                                     y32[g_i][`INT16_SIZE-1:0];
                    // requant_v_p2[g_i] <= requant_v_p1[g_i];
                end
            end

            // assign y32 = requant_32_out[g_i] + output_offset_r;
            // wire signed [`INT32_SIZE-1:0] y32_clamped =
            //     (y32 > act_max_r) ? act_max_r :
            //     (y32 < act_min_r) ? act_min_r :
            //                        y32;
            // assign requant_16_out = y32_clamped[`INT16_SIZE-1:0];
        end
    endgenerate

    // -------------------
    // FIFO output addr
    // -------------------

    assign req_fifo_push_data = {output_addr_x_i32, output_addr_y_i32};

    // MQM output valid: use lane0 as representative
    assign requant_done_mqm = requant_v_out[0];

    // top requant post-processing adds 2 cycles:
    // requant_32_out -> y32 -> requant_16_out
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            requant_done_d1 <= 1'b0;
            requant_done_d2 <= 1'b0;
        end else begin
            requant_done_d1 <= requant_done_mqm;
            requant_done_d2 <= requant_done_d1;
        end
    end

    // FIFO push when int32 output is emitted
    assign req_fifo_push = output_valid_i32;

    // FIFO pop when INT16 result is truly ready
    assign req_fifo_pop  = requant_done_d2;

    fifo #(
        .DATA_WIDTH (REQ_FIFO_W),
        .DEPTH      (REQ_FIFO_DEPTH)
    ) u_req_addr_fifo (
        .clk       (clk),
        .rst_n     (rst_n),
        .push      (req_fifo_push),
        .push_data (req_fifo_push_data),
        .pop       (req_fifo_pop),
        .pop_data  (req_fifo_pop_data),
        .full      (req_fifo_full),
        .empty     (req_fifo_empty),
        .count     (req_fifo_count)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        int j;
        if (!rst_n) begin
            output_valid_i16  <= 1'b0;
            output_addr_x_i16 <= '0;
            output_addr_y_i16 <= '0;
            output_data_i16   <= '0;
        end else begin
            output_valid_i16 <= 1'b0;

            if (requant_done_d2) begin
                // $display("requant_done_d2 asserted at time %0t", $time);
                if (!req_fifo_empty) begin
                    output_valid_i16  <= 1'b1;
                    output_addr_x_i16 <= req_fifo_pop_data[REQ_FIFO_W-1 -: `SRAM_ADDR_WIDTH];
                    output_addr_y_i16 <= req_fifo_pop_data[`SRAM_ADDR_WIDTH-1:0];

                    for (j = 0; j < PE_SIZE; j = j + 1) begin
                        output_data_i16[((j+1)*`INT16_SIZE-1) -: `INT16_SIZE] <= requant_16_out[j];
                    end
                    // $display("output_addr_x_i16 = %0d", req_fifo_pop_data[REQ_FIFO_W-1 -: `SRAM_ADDR_WIDTH]);
                    // $display("output_addr_y_i16 = %0d", req_fifo_pop_data[`SRAM_ADDR_WIDTH-1:0]);
                    // for (j = 0; j < PE_SIZE; j = j + 1) begin
                    //     $display("output_data_i16[%0d] = %0d", j, output_data_i16[((j+1)*`INT16_SIZE-1) -: `INT16_SIZE]);
                    // end
                end else begin
                    // $display("[ERROR] requant_done_d2 asserted but req addr fifo is empty at time %0t", $time);
                end
            end
        end
    end
endmodule
`default_nettype wire