`timescale 1ns / 1ps
`include "params.vh"

// ============================================================
// MultiplyByQuantizedMultiplier
// ------------------------------------------------------------
// Implements:
//
//   RoundingDivideByPOT(
//       SaturatingRoundingDoublingHighMul(
//           x * (1 << left_shift),
//           quantized_multiplier
//       ),
//       right_shift
//   )
//
// Compared with MultiplyByQuantizedMultiplierSmallerThanOneExp version:
// - This NORMAL version still keeps the "x <<< left_shift" behavior
// - Only the heavy multiply stage is replaced by DW_mult_pipe
//
// Notes:
// - rst is active-low
// - DEPTH controls only the DW multiplier pipeline depth
// ============================================================

module MultiplyByQuantizedMultiplier #(
    parameter integer DEPTH = 7
)(
    input  wire                               clk,
    input  wire                               rst,   // active-low
    input  wire signed [`INT32_SIZE-1:0]      x,
    input  wire signed [`INT32_SIZE-1:0]      quantized_multiplier,
    input  wire signed [`INT32_SIZE-1:0]      shift,
    input  wire                               input_valid,
    output reg                                output_valid,
    output reg  signed [`INT32_SIZE-1:0]      x_mul_by_quantized_multiplier
);

    // --------------------------------------------------------
    // Constants
    // --------------------------------------------------------
    localparam signed [`INT8_SIZE-1:0] NEG_128 = -128;
    localparam signed [`INT8_SIZE-1:0] POS_127 =  127;

    // --------------------------------------------------------
    // Shift decomposition
    //   shift > 0  => left_shift = shift,  right_shift = 0
    //   shift <= 0 => left_shift = 0,      right_shift = -shift
    // --------------------------------------------------------
    wire shift_positive;
    wire signed [`INT32_SIZE-1:0] neg_shift_full;
    wire signed [`INT8_SIZE-1:0] left_shift_wire;
    wire signed [`INT8_SIZE-1:0] right_shift_wire;

    assign shift_positive = (~shift[`INT32_SIZE-1]) && (shift != 0);
    assign neg_shift_full = -shift;

    assign left_shift_wire  = shift_positive ? $signed(shift[`INT8_SIZE-1:0]) : `INT8_SIZE'd0;
    assign right_shift_wire = shift_positive ? `INT8_SIZE'd0  : $signed(neg_shift_full[`INT8_SIZE-1:0]);

    // --------------------------------------------------------
    // Stage 1: prepare (x << left_shift), register qm/right_shift
    // --------------------------------------------------------
    reg  signed [`INT32_SIZE-1:0] qm_s1;
    reg         [`INT8_SIZE-1:0]  right_shift_s1;
    reg  signed [`INT64_SIZE-1:0] ab_64_s1;   // (x << left_shift)
    reg                           valid_s1;

    always @(posedge clk) begin
        if (!rst) begin
            qm_s1          <= `INT32_SIZE'sd0;
            right_shift_s1 <= `INT8_SIZE'd0;
            ab_64_s1       <= `INT64_SIZE'sd0;
            valid_s1       <= 1'b0;
        end else begin
            qm_s1          <= quantized_multiplier;
            right_shift_s1 <= right_shift_wire;
            ab_64_s1       <= $signed(x) <<< left_shift_wire;
            valid_s1       <= input_valid;
        end
    end

    // --------------------------------------------------------
    // Stage 2: pipelined multiply using DW_mult_pipe
    //   64-bit * 32-bit => 96-bit product
    // --------------------------------------------------------
    wire signed [`INT64_SIZE+`INT32_SIZE-1:0] mult_product_full;

    reg                           valid_mul   [0:DEPTH-1];
    reg  [`INT8_SIZE-1:0]         rshift_mul  [0:DEPTH-1];
    integer i;

    // wire [DEPTH-1:0] valid_mul_vec;
    // genvar gv;
    // generate
    //     for (gv = 0; gv < DEPTH; gv = gv + 1) begin : GEN_VALID_PACK
    //         assign valid_mul_vec[gv] = valid_mul[gv];
    //     end
    // endgenerate

    // wire any_valid_mul;
    // wire dw_mul_en;
    // assign any_valid_mul = |valid_mul_vec;
    // assign dw_mul_en     = valid_s1 | any_valid_mul;

    // Directly instantiate DW_mult_pipe to avoid wrapper name collision
    // DW_mult_pipe #(64, 32, DEPTH, 1, 2, 0) U_DW_mult_pipe_64x32 (
    //     .clk     (clk),
    //     .rst_n   (rst),
    //     .en      (1'b1),
    //     .tc      (1'b1),   // signed multiply
    //     .a       (ab_64_s1),
    //     .b       (qm_s1),
    //     .product (mult_product_full)
    // );

    mult_pipe #(
          .A_WIDTH (64),
          .B_WIDTH (32),
          .DEPTH   (DEPTH)
      ) U_mult_pipe (
          .clk     (clk),
          .rst_n   (rst),
          .en      (1'b1),
          .tc      (1'b1),
          .a       (ab_64_s1),
          .b       (qm_s1),
          .product (mult_product_full)
      );

    always @(posedge clk) begin
        if (!rst) begin
            for (i = 0; i < DEPTH; i = i + 1) begin
                valid_mul[i]  <= 1'b0;
                rshift_mul[i] <= `INT8_SIZE'd0;
            end
        end else begin
            valid_mul[0]  <= valid_s1;
            rshift_mul[0] <= right_shift_s1;
            for (i = 1; i < DEPTH; i = i + 1) begin
                valid_mul[i]  <= valid_mul[i-1];
                rshift_mul[i] <= rshift_mul[i-1];
            end
        end
    end

    // --------------------------------------------------------
    // Stage 3: capture multiplier result + aligned right_shift
    // --------------------------------------------------------
    reg  signed [`INT64_SIZE-1:0] ab_64_s3;
    reg         [`INT8_SIZE-1:0]  right_shift_s3;
    reg                           valid_s3;

    always @(posedge clk) begin
        if (!rst) begin
            ab_64_s3       <= `INT64_SIZE'sd0;
            right_shift_s3 <= `INT8_SIZE'd0;
            valid_s3       <= 1'b0;
        end else begin
            // preserve original behavior: keep low 64 bits
            ab_64_s3       <= $signed(mult_product_full[`INT64_SIZE-1:0]);
            right_shift_s3 <= rshift_mul[DEPTH-2]; 
            valid_s3       <= valid_mul[DEPTH-2]; // using wire to capture dw_mult_pipe output, so use `DEPTH-2` valid, since reg update when posedge clk
        end
    end

    // --------------------------------------------------------
    // Stage 4: Q31 rounding + prepare for RoundingDivideByPOT
    // --------------------------------------------------------
    reg         [`INT8_SIZE-1:0]  right_shift_s4;
    reg  signed [`INT32_SIZE-1:0] ab_x2_high32_s4;
    reg         [`INT32_SIZE-1:0] remainder_s4;
    reg         [`INT32_SIZE-1:0] threshold_s4;
    reg                           valid_s4;

    wire signed [`INT64_SIZE-1:0] nudge64;
    wire signed [`INT32_SIZE-1:0] ab_x3_high32;
    wire        [`INT32_SIZE-1:0] mask_next;
    wire        [`INT32_SIZE-1:0] remainder_next;
    wire        [`INT32_SIZE-1:0] threshold_next;

    assign nudge64 =
        (ab_64_s3 >= 0) ? `INT64_SIZE'sh4000_0000
                        : (`INT64_SIZE'sd1 - `INT64_SIZE'sh4000_0000);   // gemmlowp-style

    assign ab_x3_high32 = (ab_64_s3 + nudge64) >>> (`INT32_SIZE-1);

    assign mask_next      = (right_shift_s3 == 0) ? `INT32_SIZE'd0
                                                  : ((`INT32_SIZE'd1 << right_shift_s3) - 1);
    assign remainder_next = ab_x3_high32 & mask_next;
    assign threshold_next = (mask_next >> 1) + ((ab_x3_high32 < 0) ? `INT32_SIZE'd1 : `INT32_SIZE'd0);

    always @(posedge clk) begin
        if (!rst) begin
            right_shift_s4  <= `INT8_SIZE'd0;
            ab_x2_high32_s4 <= `INT32_SIZE'sd0;
            remainder_s4    <= `INT32_SIZE'd0;
            threshold_s4    <= `INT32_SIZE'd0;
            valid_s4        <= 1'b0;
        end else begin
            right_shift_s4  <= right_shift_s3;
            ab_x2_high32_s4 <= ab_x3_high32;
            remainder_s4    <= remainder_next;
            threshold_s4    <= threshold_next;
            valid_s4        <= valid_s3;
        end
    end

    // --------------------------------------------------------
    // Stage 5: RoundingDivideByPOT final output
    // --------------------------------------------------------
    wire signed [`INT32_SIZE-1:0] tmp_result;
    wire signed [`INT32_SIZE-1:0] result32;

    assign tmp_result = (right_shift_s4 == 0)
                      ? ab_x2_high32_s4
                      : (ab_x2_high32_s4 >>> right_shift_s4);

    assign result32 = tmp_result +
                      ((remainder_s4 > threshold_s4) ? `INT32_SIZE'sd1 : `INT32_SIZE'sd0);

    always @(posedge clk) begin
        if (!rst) begin
            x_mul_by_quantized_multiplier <= `INT32_SIZE'sd0;
            output_valid                  <= 1'b0;
        end else begin
            x_mul_by_quantized_multiplier <= result32;
            output_valid                  <= valid_s4;
        end
    end

endmodule