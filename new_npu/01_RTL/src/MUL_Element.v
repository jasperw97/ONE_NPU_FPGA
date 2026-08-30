`timescale 1ns / 1ps
`include "params.vh"

module MUL_Element (
    input wire clk,
    input wire rst,
    input wire input_valid,
    input wire signed [`INT8_SIZE-1:0] in1,
    input wire signed [`INT8_SIZE-1:0] in2,
    input wire signed [`INT32_SIZE-1:0] input1_offset,
    input wire signed [`INT32_SIZE-1:0] input2_offset,
    input wire signed [`INT32_SIZE-1:0] output_multiplier,
    input wire signed [`INT32_SIZE-1:0] output_shift,
    input wire signed [`INT32_SIZE-1:0] output_offset,
    input wire signed [`INT32_SIZE-1:0] quantized_activation_min,
    input wire signed [`INT32_SIZE-1:0] quantized_activation_max,
    output wire signed [`INT16_SIZE-1:0] out,
    output wire valid
);

    // =========================================================
    // Stage 1: narrow + add offset
    // =========================================================
    reg signed [9:0] a_s1;
    reg signed [9:0] b_s1;
    reg              valid_s1;

    wire signed [`INT8_SIZE:0] in1_ext;
    wire signed [`INT8_SIZE:0] in2_ext;
    wire signed [`INT8_SIZE:0] off1_narrow;
    wire signed [`INT8_SIZE:0] off2_narrow;
    wire signed [`INT8_SIZE+1:0] a_comb;
    wire signed [`INT8_SIZE+1:0] b_comb;

    assign in1_ext     = in1; // extend input to spec+1 bits
    assign in2_ext     = in2; // extend input to spec+1 bits
    assign off1_narrow = $signed(input1_offset[8:0]); // narrow offset to spec+1 bits
    assign off2_narrow = $signed(input2_offset[8:0]); // narrow offset to spec+1 bits

    assign a_comb = in1_ext + off1_narrow; 
    assign b_comb = in2_ext + off2_narrow;

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            a_s1    <= 10'sd0;
            b_s1    <= 10'sd0;
            valid_s1 <= 1'b0;
        end else begin
            a_s1    <= a_comb;
            b_s1    <= b_comb;
            valid_s1 <= input_valid;
        end
    end

    // =========================================================
    // Stage 2: multiply + clamp to int16
    // =========================================================
    reg signed [19:0] prod_s2;
    reg signed [`INT16_SIZE-1:0] out_s2;
    reg                          valid_s2;

    wire signed [19:0] prod_comb;
    assign prod_comb = a_s1 * b_s1;

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            prod_s2  <= 20'sd0;
            out_s2   <= 16'sd0;
            valid_s2 <= 1'b0;
        end else begin
            prod_s2 <= prod_comb;

            if (prod_comb > 20'sd32767)
                out_s2 <= 16'sd32767;
            else if (prod_comb < -20'sd32768)
                out_s2 <= -16'sd32768;
            else
                out_s2 <= $signed(prod_comb[15:0]);

            valid_s2 <= valid_s1;
        end
    end

    assign out   = out_s2;
    assign valid = valid_s2;

    //===================================================
    // Stage 0: 鎖存所有參數 (每個參數一個 always)
    //===================================================
    // reg signed [`INT32_SIZE-1:0] stage0_output_multiplier;
    // reg signed [`INT32_SIZE-1:0] stage0_output_shift;
    // reg signed [`INT32_SIZE-1:0] stage0_output_offset;
    // reg signed [`INT32_SIZE-1:0] stage0_quantized_activation_min;
    // reg signed [`INT32_SIZE-1:0] stage0_quantized_activation_max;
    

    // always @(posedge clk or negedge rst)
    //   if (!rst) stage0_output_multiplier <= 0;
    //   else stage0_output_multiplier <= output_multiplier;

    // always @(posedge clk or negedge rst)
    //   if (!rst) stage0_output_shift <= 0;
    //   else stage0_output_shift <= output_shift;

    // always @(posedge clk or negedge rst)
    //   if (!rst) stage0_output_offset <= 0;
    //   else stage0_output_offset <= output_offset;
    
    // always @(posedge clk or negedge rst)
    //   if (!rst) stage0_quantized_activation_min <= 0;
    //   else stage0_quantized_activation_min <= quantized_activation_min;

    // always @(posedge clk or negedge rst)
    //   if (!rst) stage0_quantized_activation_max <= 0;
    //   else stage0_quantized_activation_max <= quantized_activation_max;

    //===================================================
    // Stage 1: 計算
    // 1. 將 in1, in2 加上offset後相乘做requant
    //===================================================
    // wire signed [`INT32_SIZE-1:0] requant_input;
    // wire signed [`INT32_SIZE-1:0] requant_output;
    // assign requant_input = (in1 + input1_offset) * (in2 + input2_offset);

    // MultiplyByQuantizedMultiplier MultiplyByQuantizedMultiplier_inst(
    //     .clk(clk),
    //     .rst(rst),
    //     .x(requant_input),
    //     .quantized_multiplier(output_multiplier),
    //     .shift(output_shift),
    //     .input_valid(input_valid),
    //     .output_valid(valid),
    //     .x_mul_by_quantized_multiplier(requant_output)
    // );

    //===================================================
    // Stage 2: requant_output 加上 offset 且做clamped
    //===================================================
    // wire signed [`INT16_SIZE-1:0] clamped_output;
    // assign clamped_output = (requant_output + stage0_output_offset) < stage0_quantized_activation_min ? stage0_quantized_activation_min : 
    //                         (requant_output + stage0_output_offset) > stage0_quantized_activation_max ? stage0_quantized_activation_max : (requant_output + stage0_output_offset);
    // assign out = clamped_output;
    //===================================================
    // DEBUG INFO
    //===================================================
    // always @(posedge clk) begin
    //     if (input_valid) begin
    //         $display("[MUL] in1=%d in2=%d offset1=%d offset2=%d requant_input=%d",
    //                 in1, in2, input1_offset, input2_offset, requant_input);
    //     end
    //     if (valid) begin
    //         $display("[MUL] requant_output=%d clamped_output=%d final_out=%d",
    //                 requant_output, clamped_output, out);
    //     end
    // end
    

endmodule

