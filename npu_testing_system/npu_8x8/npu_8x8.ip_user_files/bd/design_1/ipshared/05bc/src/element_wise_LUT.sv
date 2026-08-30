`timescale 1ns / 1ps
`include "params.vh"
// `include "function.vh"

module element_wise_LUT #
(
    parameter DEQUANT_WIDTH = 32,
    parameter ADDR_WIDTH = 13,
    parameter LANES = 64
)
(
    input logic                                       clk,
    input logic                                       rst,
    input logic                                       init,
    input logic        [`INT32_SIZE-1:0]              groups, // change this for vectorize

    // -------------------------------------
    // params
    // -------------------------------------
    // EXP
    input logic        [`INT32_SIZE-1:0]              exp_deq_input_range_radius,
    input logic        [`INT32_SIZE-1:0]              exp_deq_input_zero_point,
    input logic signed [`INT32_SIZE-1:0]              exp_deq_input_left_shift,
    input logic        [`INT32_SIZE-1:0]              exp_deq_input_multiplier,
    input logic        [`INT32_SIZE-1:0]              exp_req_input_quantized_multiplier,
    input logic signed [`INT32_SIZE-1:0]              exp_req_input_shift,
    input logic signed [`INT32_SIZE-1:0]              exp_req_input_offset,
  
    // RCP     
    input logic signed [`INT32_SIZE-1:0]              reciprocal_deq_input_zero_point,
    input logic signed [`INT32_SIZE-1:0]              reciprocal_deq_input_range_radius,
    input logic signed [`INT32_SIZE-1:0]              reciprocal_deq_input_left_shift,
    input logic        [`INT32_SIZE-1:0]              reciprocal_deq_input_multiplier,
    input logic        [`INT32_SIZE-1:0]              reciprocal_req_input_quantized_multiplier,
    input logic signed [`INT32_SIZE-1:0]              reciprocal_req_input_shift,
    input logic signed [`INT32_SIZE-1:0]              reciprocal_req_input_offset,

    // ADD  
    input logic signed [`INT32_SIZE-1:0]              add_input1_offset,
    input logic signed [`INT32_SIZE-1:0]              add_input2_offset,
    input logic signed [`INT32_SIZE-1:0]              add_left_shift,
    input logic        [`INT32_SIZE-1:0]              add_input1_multiplier,
    input logic        [`INT32_SIZE-1:0]              add_input2_multiplier,
    input logic signed [`INT32_SIZE-1:0]              add_input1_shift,
    input logic signed [`INT32_SIZE-1:0]              add_input2_shift,
    input logic        [`INT32_SIZE-1:0]              add_output_multiplier,
    input logic signed [`INT32_SIZE-1:0]              add_output_shift,
    input logic signed [`INT32_SIZE-1:0]              add_output_offset,
    input logic signed [`INT32_SIZE-1:0]              add_quantized_activation_min,
    input logic signed [`INT32_SIZE-1:0]              add_quantized_activation_max,
  
    // SUB  
    input logic signed [`INT32_SIZE-1:0]              sub_input1_offset,
    input logic signed [`INT32_SIZE-1:0]              sub_input2_offset,
    input logic signed [`INT32_SIZE-1:0]              sub_left_shift,
    input logic        [`INT32_SIZE-1:0]              sub_input1_multiplier,
    input logic        [`INT32_SIZE-1:0]              sub_input2_multiplier,
    input logic signed [`INT32_SIZE-1:0]              sub_input1_shift,
    input logic signed [`INT32_SIZE-1:0]              sub_input2_shift,
    input logic        [`INT32_SIZE-1:0]              sub_output_multiplier,
    input logic signed [`INT32_SIZE-1:0]              sub_output_shift,
    input logic signed [`INT32_SIZE-1:0]              sub_output_offset,
    input logic signed [`INT32_SIZE-1:0]              sub_quantized_activation_min,
    input logic signed [`INT32_SIZE-1:0]              sub_quantized_activation_max,
    
    // MUL 
    input logic signed [`INT32_SIZE-1:0]              mul_input1_offset,
    input logic signed [`INT32_SIZE-1:0]              mul_input2_offset,
    input logic        [`INT32_SIZE-1:0]              mul_output_multiplier,
    input logic signed [`INT32_SIZE-1:0]              mul_output_shift,
    input logic signed [`INT32_SIZE-1:0]              mul_output_offset,
    input logic signed [`INT32_SIZE-1:0]              mul_quantized_activation_min,
    input logic signed [`INT32_SIZE-1:0]              mul_quantized_activation_max,
    
    // -------------------------------------
    // data
    // -------------------------------------
    // EXP
    input  logic                                     exp_en,
    output logic                                     exp_valid_out,
    input  logic [LANES*`INT16_SIZE-1:0]             exp_data_in,
    output logic [LANES*`INT16_SIZE-1:0]             exp_data_out,
    input  logic                                     exp_load,  // added
    output logic                                     exp_lut_ready, // added: indicates exp LUT is loaded and ready
    input  logic [`SRAM_WIDTH_O-1:0]                 exp_lut_sram_data_in,
    output logic                                     exp_lut_sram_en,
    output logic [`SRAM_ADDR_WIDTH-1:0]              exp_lut_data_addr,
    
    // RCP
    input  logic                                    reciprocal_en,
    output logic                                    reciprocal_valid_out,
    input  logic [LANES*`INT16_SIZE-1:0]            reciprocal_data_in,
    output logic [LANES*`INT16_SIZE-1:0]            reciprocal_data_out,
    input  logic                                    reciprocal_load,  // added
    output logic                                    rcp_lut_ready, // added: indicates reciprocal LUT is loaded and ready
    input  logic [`SRAM_WIDTH_O-1:0]                reciprocal_lut_sram_data_in,
    output logic                                    reciprocal_lut_sram_en,
    output logic [`SRAM_ADDR_WIDTH-1:0]             reciprocal_lut_data_addr,
    
    // ADD
    input  logic                                    add_en,
    output logic                                    add_valid_out,
    input  logic [LANES*`INT16_SIZE-1:0]            add_data_in,
    output logic [LANES*`INT16_SIZE-1:0]            add_data_out,
    input  logic [LANES*`INT16_SIZE-1:0]            add_weight_data_in,
    // SUB
    input  logic                                    sub_en,
    output logic                                    sub_valid_out,
    input  logic [LANES*`INT16_SIZE-1:0]            sub_data_in,
    output logic [LANES*`INT16_SIZE-1:0]            sub_data_out,
    input  logic [LANES*`INT16_SIZE-1:0]            sub_weight_data_in,
    // MUL
    input  logic                                    mul_en,
    output logic                                    mul_valid_out,
    input  logic [LANES*`INT8_SIZE-1:0]             mul_data_in,
    input  logic [LANES*`INT8_SIZE-1:0]             mul_weight_data_in,
    output logic [LANES*`INT16_SIZE-1:0]            mul_data_out
);
    localparam [`SRAM_ADDR_WIDTH-1:0] EXP_LUT_BASE_ADDR  = `SRAM_ADDR_WIDTH'd0;
    localparam [`SRAM_ADDR_WIDTH-1:0] RCP_LUT_BASE_ADDR  = `SRAM_ADDR_WIDTH'd256;

    // ---------- helper: saturate to int16 ----------
    function [`INT16_SIZE-1:0] sat_s16;
      input signed [`INT32_SIZE-1:0] x;
      begin
        if (x > 32767)       sat_s16 = 16'sd32767;
        else if (x < -32768) sat_s16 = 16'h8000;
        else                 sat_s16 = x[`INT16_SIZE-1:0];
      end
    endfunction

    // ---------- helper: saturate to int8 ----------
    // function [`INT8_SIZE-1:0] sat_s8;
    //   input signed [`INT32_SIZE-1:0] x;
    //   begin
    //     if (x > 127)        sat_s8 = 8'sd127;
    //     else if (x < -128)  sat_s8 = 8'h80;
    //     else                sat_s8 = x[`INT8_SIZE-1:0];
    //   end
    // endfunction

    // -------------------------------------
    // input staging
    // -------------------------------------
    // add input
    logic signed [`INT32_SIZE-1:0]              add_input1_offset_r;
    logic signed [`INT32_SIZE-1:0]              add_input2_offset_r;
    logic signed [`INT32_SIZE-1:0]              add_left_shift_r;
    logic        [`INT32_SIZE-1:0]              add_input1_multiplier_r;
    logic        [`INT32_SIZE-1:0]              add_input2_multiplier_r;
    logic signed [`INT32_SIZE-1:0]              add_input1_shift_r;
    logic signed [`INT32_SIZE-1:0]              add_input2_shift_r;
    logic        [`INT32_SIZE-1:0]              add_output_multiplier_r;
    logic signed [`INT32_SIZE-1:0]              add_output_shift_r;
    logic signed [`INT32_SIZE-1:0]              add_output_offset_r;
    logic signed [`INT32_SIZE-1:0]              add_quantized_activation_min_r;
    logic signed [`INT32_SIZE-1:0]              add_quantized_activation_max_r;
    logic                                       add_en_r;
    logic [LANES*`INT16_SIZE-1:0]               add_data_in_r;
    logic [LANES*`INT16_SIZE-1:0]               add_weight_data_in_r;

    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            add_input1_offset_r <= '0;
            add_input2_offset_r <= '0;
            add_left_shift_r <= '0;
            add_input1_multiplier_r <= '0;
            add_input2_multiplier_r <= '0;
            add_input1_shift_r <= '0;
            add_input2_shift_r <= '0;
            add_output_multiplier_r <= '0;
            add_output_shift_r <= '0;
            add_output_offset_r <= '0;
            add_quantized_activation_min_r <= '0;
            add_quantized_activation_max_r <= '0;
            add_en_r <= 1'b0;
            add_data_in_r <= '0;
            add_weight_data_in_r <= '0;
        end else begin
            add_input1_offset_r <= add_input1_offset;
            add_input2_offset_r <= add_input2_offset;
            add_left_shift_r <= add_left_shift;
            add_input1_multiplier_r <= add_input1_multiplier;
            add_input2_multiplier_r <= add_input2_multiplier;
            add_input1_shift_r <= add_input1_shift;
            add_input2_shift_r <= add_input2_shift;
            add_output_multiplier_r <= add_output_multiplier;
            add_output_shift_r <= add_output_shift;
            add_output_offset_r <= add_output_offset;
            add_quantized_activation_min_r <= add_quantized_activation_min;
            add_quantized_activation_max_r <= add_quantized_activation_max;
            add_en_r <= add_en;
            add_data_in_r <= add_data_in;
            add_weight_data_in_r <= add_weight_data_in;
        end
    end

    // sub input
    logic signed [`INT32_SIZE-1:0]              sub_input1_offset_r;
    logic signed [`INT32_SIZE-1:0]              sub_input2_offset_r;
    logic signed [`INT32_SIZE-1:0]              sub_left_shift_r;
    logic        [`INT32_SIZE-1:0]              sub_input1_multiplier_r;
    logic        [`INT32_SIZE-1:0]              sub_input2_multiplier_r;
    logic signed [`INT32_SIZE-1:0]              sub_input1_shift_r;
    logic signed [`INT32_SIZE-1:0]              sub_input2_shift_r;
    logic        [`INT32_SIZE-1:0]              sub_output_multiplier_r;
    logic signed [`INT32_SIZE-1:0]              sub_output_shift_r;
    logic signed [`INT32_SIZE-1:0]              sub_output_offset_r;
    logic signed [`INT32_SIZE-1:0]              sub_quantized_activation_min_r;
    logic signed [`INT32_SIZE-1:0]              sub_quantized_activation_max_r;
    logic                                       sub_en_r;
    logic [LANES*`INT16_SIZE-1:0]               sub_data_in_r;
    logic [LANES*`INT16_SIZE-1:0]               sub_weight_data_in_r;

    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            sub_input1_offset_r <= '0;
            sub_input2_offset_r <= '0;
            sub_left_shift_r <= '0;
            sub_input1_multiplier_r <= '0;
            sub_input2_multiplier_r <= '0;
            sub_input1_shift_r <= '0;
            sub_input2_shift_r <= '0;
            sub_output_multiplier_r <= '0;
            sub_output_shift_r <= '0;
            sub_output_offset_r <= '0;
            sub_quantized_activation_min_r <= '0;
            sub_quantized_activation_max_r <= '0;
            sub_en_r <= 1'b0;
            sub_data_in_r <= '0;
            sub_weight_data_in_r <= '0;
        end else begin
            sub_input1_offset_r <= sub_input1_offset;
            sub_input2_offset_r <= sub_input2_offset;
            sub_left_shift_r <= sub_left_shift;
            sub_input1_multiplier_r <= sub_input1_multiplier;
            sub_input2_multiplier_r <= sub_input2_multiplier;
            sub_input1_shift_r <= sub_input1_shift;
            sub_input2_shift_r <= sub_input2_shift;
            sub_output_multiplier_r <= sub_output_multiplier;
            sub_output_shift_r <= sub_output_shift;
            sub_output_offset_r <= sub_output_offset;
            sub_quantized_activation_min_r <= sub_quantized_activation_min;
            sub_quantized_activation_max_r <= sub_quantized_activation_max;
            sub_en_r <= sub_en;
            sub_data_in_r <= sub_data_in;
            sub_weight_data_in_r <= sub_weight_data_in;
        end
    end

    // mul input
    logic signed [`INT32_SIZE-1:0]              mul_input1_offset_r;
    logic signed [`INT32_SIZE-1:0]              mul_input2_offset_r;
    logic signed [`INT32_SIZE-1:0]              mul_output_multiplier_r;
    logic signed [`INT32_SIZE-1:0]              mul_output_shift_r;
    logic signed [`INT32_SIZE-1:0]              mul_output_offset_r;
    logic signed [`INT32_SIZE-1:0]              mul_quantized_activation_min_r;
    logic signed [`INT32_SIZE-1:0]              mul_quantized_activation_max_r;
    logic                                       mul_en_r;
    logic [LANES*`INT8_SIZE-1:0]               mul_data_in_r;
    logic [LANES*`INT8_SIZE-1:0]               mul_weight_data_in_r;

    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            mul_input1_offset_r <= '0;
            mul_input2_offset_r <= '0;
            mul_output_multiplier_r <= '0;
            mul_output_shift_r <= '0;
            mul_output_offset_r <= '0;
            mul_quantized_activation_min_r <= '0;
            mul_quantized_activation_max_r <= '0;
            mul_en_r <= 1'b0;
            mul_data_in_r <= '0;
            mul_weight_data_in_r <= '0;
        end else begin
            mul_input1_offset_r <= mul_input1_offset;
            mul_input2_offset_r <= mul_input2_offset;
            mul_output_multiplier_r <= mul_output_multiplier;
            mul_output_shift_r <= mul_output_shift;
            mul_output_offset_r <= mul_output_offset;
            mul_quantized_activation_min_r <= mul_quantized_activation_min;
            mul_quantized_activation_max_r <= mul_quantized_activation_max;
            mul_en_r <= mul_en;
            mul_data_in_r <= mul_data_in;
            mul_weight_data_in_r <= mul_weight_data_in;
        end
    end

    // exp input
    logic        [`INT32_SIZE-1:0]              exp_deq_input_zero_point_r;
    logic signed [`INT32_SIZE-1:0]              exp_deq_input_left_shift_r;
    logic        [`INT32_SIZE-1:0]              exp_deq_input_multiplier_r;
    logic                                       exp_en_r;
    logic [LANES*`INT16_SIZE-1:0]               exp_data_in_r;

    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            exp_deq_input_zero_point_r <= '0;
            exp_deq_input_left_shift_r <= '0;
            exp_deq_input_multiplier_r <= '0;
            exp_en_r <= 1'b0;
            exp_data_in_r <= '0;
        end else begin
            exp_deq_input_zero_point_r <= exp_deq_input_zero_point;
            exp_deq_input_left_shift_r <= exp_deq_input_left_shift;
            exp_deq_input_multiplier_r <= exp_deq_input_multiplier;
            exp_en_r <= exp_en;
            exp_data_in_r <= exp_data_in;
        end
    end

    // rcp input
    logic signed [`INT32_SIZE-1:0]              reciprocal_deq_input_zero_point_r;
    logic signed [`INT32_SIZE-1:0]              reciprocal_deq_input_left_shift_r;
    logic        [`INT32_SIZE-1:0]              reciprocal_deq_input_multiplier_r;
    logic signed [`INT32_SIZE-1:0]              reciprocal_req_input_quantized_multiplier_r;
    logic signed [`INT32_SIZE-1:0]              reciprocal_req_input_shift_r;
    logic signed [`INT32_SIZE-1:0]              reciprocal_req_input_offset_r;
    logic                                       reciprocal_en_r;
    logic [LANES*`INT16_SIZE-1:0]               reciprocal_data_in_r;

    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            reciprocal_deq_input_zero_point_r <= '0;
            reciprocal_deq_input_left_shift_r <= '0;
            reciprocal_deq_input_multiplier_r <= '0;
            reciprocal_req_input_quantized_multiplier_r <= '0;
            reciprocal_req_input_shift_r <= '0;
            reciprocal_req_input_offset_r <= '0;
            reciprocal_en_r <= 1'b0;
            reciprocal_data_in_r <= '0;
        end else begin
            reciprocal_deq_input_zero_point_r <= reciprocal_deq_input_zero_point;
            reciprocal_deq_input_left_shift_r <= reciprocal_deq_input_left_shift;
            reciprocal_deq_input_multiplier_r <= reciprocal_deq_input_multiplier;
            reciprocal_req_input_quantized_multiplier_r <= reciprocal_req_input_quantized_multiplier;
            reciprocal_req_input_shift_r <= reciprocal_req_input_shift;
            reciprocal_req_input_offset_r <= reciprocal_req_input_offset;
            reciprocal_en_r <= reciprocal_en;
            reciprocal_data_in_r <= reciprocal_data_in;
        end
    end
    // -------------------------------------
    // exp LUT input vector (int16 "v")
    // -------------------------------------
    wire [LANES*`INT16_SIZE-1:0] exp_lut_in_v16;
    wire [LANES-1:0]             exp_deq_valid_vec;

    genvar gi_exp;
    generate
      for (gi_exp = 0; gi_exp < LANES; gi_exp = gi_exp + 1) begin : GEN_EXP_V
        wire signed [`INT16_SIZE-1:0] in16;
        wire signed [`INT32_SIZE-1:0] diff;
        wire signed [`INT32_SIZE-1:0] v_off;
        wire signed [`INT32_SIZE-1:0] v32;

        assign in16  = $signed(exp_data_in_r[gi_exp*`INT16_SIZE +: `INT16_SIZE]);
        assign diff  = $signed({{16{in16[`INT16_SIZE-1]}}, in16}) - $signed(exp_deq_input_zero_point_r);

        MultiplyByQuantizedMultiplier exp_deq_requant_inst (
            .clk(clk),
            .rst(rst),
            .x(diff),
            .quantized_multiplier($signed(exp_deq_input_multiplier_r)),
            .shift($signed(exp_deq_input_left_shift_r)),
            .input_valid(exp_en_r),
            .output_valid(exp_deq_valid_vec[gi_exp]),
            .x_mul_by_quantized_multiplier(v_off)
        );

        // TFLite int16 exp LUT domain: recenter to signed int16 domain
        assign v32 = 32'sd32767 + v_off;
        assign exp_lut_in_v16[gi_exp*`INT16_SIZE +: `INT16_SIZE] = sat_s16(v32);
      end
    endgenerate

    wire exp_lut_input_valid;
    assign exp_lut_input_valid = &exp_deq_valid_vec;

    // -------------------------------------
    // reciprocal LUT input vector (int16 "sym") 
    // -------------------------------------
    wire [LANES*`INT16_SIZE-1:0] rcp_lut_in_s16;
    wire [LANES-1:0]             rcp_deq_valid_vec;

    genvar gi_rcp;
    generate
      for (gi_rcp = 0; gi_rcp < LANES; gi_rcp = gi_rcp + 1) begin : GEN_RCP_S
        wire signed [`INT16_SIZE-1:0] in16;
        wire signed [`INT32_SIZE-1:0] x;
        wire signed [`INT32_SIZE-1:0] sym;

        assign in16 = $signed(reciprocal_data_in_r[gi_rcp*`INT16_SIZE +: `INT16_SIZE]);
        assign x    = $signed({{16{in16[`INT16_SIZE-1]}}, in16}) - $signed(reciprocal_deq_input_zero_point_r);

        MultiplyByQuantizedMultiplier rcp_deq_requant_inst (
            .clk(clk),
            .rst(rst),
            .x(x),
            .quantized_multiplier($signed(reciprocal_deq_input_multiplier_r)),
            .shift($signed(reciprocal_deq_input_left_shift_r)),
            .input_valid(reciprocal_en_r),
            .output_valid(rcp_deq_valid_vec[gi_rcp]),
            .x_mul_by_quantized_multiplier(sym)
        );

        assign rcp_lut_in_s16[gi_rcp*`INT16_SIZE +: `INT16_SIZE] = sat_s16(sym);
      end
    endgenerate

    wire rcp_lut_input_valid;
    assign rcp_lut_input_valid = &rcp_deq_valid_vec;

    // ========================================================
    // reciprocal (LUTLookup int16)
    // ========================================================

    lut_vec_tflite #(
        .LANES(LANES),
        .ADDR_WIDTH(`SRAM_ADDR_WIDTH),
        .IN_WIDTH(`INT16_SIZE),
        .OUT_WIDTH(`INT16_SIZE),
        .LUT_SIZE(513),
        .INTERP(1'b1)
    ) reciprocal_lut_inst (
        .clk(clk),
        .rst(rst),

        .load_lut(reciprocal_load),
        .load_done(rcp_lut_ready),

        .lut_data_in(reciprocal_lut_sram_data_in),
        .sram_lut_en(reciprocal_lut_sram_en),
        .lut_base_addr(RCP_LUT_BASE_ADDR),
        .lut_data_addr(reciprocal_lut_data_addr),

        .input_valid(rcp_lut_input_valid),
        .output_valid(reciprocal_valid_out),
        .data_in(rcp_lut_in_s16),
        .data_out(reciprocal_data_out)
    );

    // ========================================================
    // exp (LUTLookup int16)
    // ========================================================

    lut_vec_tflite #(
        .LANES(LANES),
        .ADDR_WIDTH(`SRAM_ADDR_WIDTH),
        .IN_WIDTH(`INT16_SIZE),
        .OUT_WIDTH(`INT16_SIZE),
        .LUT_SIZE(513),
        .INTERP(1'b1)
    ) exp_lut_inst (
        .clk(clk),
        .rst(rst),

        .load_lut(exp_load),
        .load_done(exp_lut_ready),

        .lut_data_in(exp_lut_sram_data_in),
        .sram_lut_en(exp_lut_sram_en),
        .lut_base_addr(EXP_LUT_BASE_ADDR),
        .lut_data_addr(exp_lut_data_addr),

        .input_valid(exp_lut_input_valid),
        .output_valid(exp_valid_out),
        .data_in(exp_lut_in_v16),
        .data_out(exp_data_out)
    );

    ADD #(.LANES(LANES)) add_inst
    (
        .clk(clk),
        .rst(rst),
        .valid_in(add_en_r),
        .input1(add_data_in_r),
        .input2(add_weight_data_in_r),
        .input1_offset(add_input1_offset_r),
        .input2_offset(add_input2_offset_r),
        .left_shift(add_left_shift_r),
        .input1_multiplier(add_input1_multiplier_r),
        .input2_multiplier(add_input2_multiplier_r),
        .input1_shift(add_input1_shift_r),
        .input2_shift(add_input2_shift_r),
        .output_multiplier(add_output_multiplier_r),
        .output_shift(add_output_shift_r),
        .output_offset(add_output_offset_r),
        .quantized_activation_min(add_quantized_activation_min_r),
        .quantized_activation_max(add_quantized_activation_max_r),
        .data_o(add_data_out),
        .valid_o(add_valid_out)
    );

    SUB #(.LANES(LANES)) sub_inst
    (
        .clk(clk),
        .rst(rst),
        .valid_in(sub_en_r),
        .input1(sub_data_in_r),
        .input2(sub_weight_data_in_r),
        .input1_offset(sub_input1_offset_r),
        .input2_offset(sub_input2_offset_r),
        .left_shift(sub_left_shift_r),
        .input1_multiplier(sub_input1_multiplier_r),
        .input2_multiplier(sub_input2_multiplier_r),
        .input1_shift(sub_input1_shift_r),
        .input2_shift(sub_input2_shift_r),
        .output_multiplier(sub_output_multiplier_r),
        .output_shift(sub_output_shift_r),
        .output_offset(sub_output_offset_r),
        .quantized_activation_min(sub_quantized_activation_min_r),
        .quantized_activation_max(sub_quantized_activation_max_r),
        .data_o(sub_data_out),
        .valid_o(sub_valid_out)
    );

    MUL #(.LANES(LANES)) mul_inst
    (
        .clk(clk),
        .rst(rst),
        .valid_in(mul_en_r),
        .input1(mul_data_in_r),
        .input2(mul_weight_data_in_r),
        .input1_offset(mul_input1_offset_r),
        .input2_offset(mul_input2_offset_r),
        .output_multiplier(mul_output_multiplier_r),
        .output_shift(mul_output_shift_r),
        .output_offset(mul_output_offset_r),
        .quantized_activation_min(mul_quantized_activation_min_r),
        .quantized_activation_max(mul_quantized_activation_max_r),
        .data_o(mul_data_out),
        .valid_o(mul_valid_out)
    );
endmodule 