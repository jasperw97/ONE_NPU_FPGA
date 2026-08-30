`timescale 1ns / 1ps
`include "params.vh"


module MultiplyByQuantizedMultiplierSmallerThanOneExp #(
    parameter integer DEPTH = 7
)
(
    input wire clk,
    input wire rst,
    input wire signed [`INT32_SIZE-1:0] x,
    input wire signed [`INT32_SIZE-1:0] quantized_multiplier,
    input wire signed [`INT32_SIZE-1:0] shift,  // 此處視作 left_shift，後面會取負傳給 RoundingDivideByPOT
    input wire input_valid,
    output reg output_valid,
    output reg signed [`INT32_SIZE-1:0] x_mul_by_quantized_multiplier
);
    // 定義範圍常數
    localparam signed [`INT8_SIZE-1:0] NEG_128 = -128;
    localparam signed [`INT8_SIZE-1:0] POS_127 =  127;

    localparam signed [`INT32_SIZE-1:0] INT32_MIN = 32'sh8000_0000;
    localparam signed [`INT32_SIZE-1:0] INT32_MAX = 32'sh7fff_ffff;
    
    // Pipeline stage valid signals
    reg valid_stage1, valid_stage2 , valid_stage3, valid_stage4;

    // Pipeline registers for input and intermediate values
    reg signed [`INT32_SIZE-1:0] x_reg_s1, quantized_multiplier_reg_s1;
    reg signed [`INT32_SIZE-1:0] shift_reg_s1, neg_shift_s1;  // 保存輸入的 shift 及其負值
    wire signed [`INT64_SIZE+`INT32_SIZE-1:0] ab_64_s2;
    reg signed [`INT64_SIZE-1:0] ab_64_s3;
    reg signed [`INT64_SIZE-1:0] ab_64_s1;
    reg overflow_s1, overflow_s2, overflow_s3;
    reg signed [`INT32_SIZE-1:0] nudge_s3;
    reg signed [`INT32_SIZE-1:0] ab_x2_high32_s3, ab_x2_high32_s4;
    reg signed [`INT32_SIZE-1:0] remainder_s4, threshold_s4;
    
    // 這裡直接將右移參數設定為 -shift
    wire signed [`INT32_SIZE-1:0] neg_shift_wire;
    assign neg_shift_wire = -shift;

    // Stage 1: 輸入登錄
    always @(posedge clk) begin
        if (!rst) valid_stage1 <= 0;
        else valid_stage1 <= input_valid;
    end

    always @(posedge clk) begin
        if (!rst) x_reg_s1 <= 0;
        else x_reg_s1 <= x;
    end

    always @(posedge clk) begin
        if (!rst) quantized_multiplier_reg_s1 <= 0;
        else quantized_multiplier_reg_s1 <= quantized_multiplier;
    end

    // 將 shift 登錄，並計算其負值
    always @(posedge clk) begin
        if (!rst) begin
            shift_reg_s1 <= 0;
            neg_shift_s1 <= 0;
        end else begin
            shift_reg_s1 <= shift;
            neg_shift_s1 <= neg_shift_wire;  // neg_shift = -shift
        end
    end

    // 在 MultiplyByQuantizedMultiplierSmallerThanOneExp 中，不做 x 的額外左移
    always @(posedge clk) begin
        if (!rst) ab_64_s1 <= 0;
        else ab_64_s1 <= {{(`INT64_SIZE-`INT32_SIZE){x[`INT32_SIZE-1]}}, x};
    end

    always @(posedge clk) begin
        if (!rst) overflow_s1 <= 0;
        else overflow_s1 <= (x == quantized_multiplier && x == INT32_MIN);
    end

    // Stage 2: 與 quantized_multiplier 相乘
    always @(posedge clk) begin
        if (!rst) valid_stage2 <= 0;
        else valid_stage2 <= valid_stage1;
    end

    // always @(posedge clk) begin
    //     if (!rst) ab_64_s2 <= 0;
    //     else if (valid_stage1) ab_64_s2 <= ab_64_s1 * quantized_multiplier_reg_s1;
    // end
    // stage2a: 
    reg overflow_s2b[0:DEPTH-1];
    reg signed [`INT32_SIZE-1:0] neg_shift_s2b[0:DEPTH-1];
    reg valid_2b[0:DEPTH-1];
    integer i;

    always @(posedge clk) begin
        if (!rst) begin
            for(i = 0; i<DEPTH; i = i+1) begin
                overflow_s2b[i] <= 0;
                neg_shift_s2b[i] <= 0;
                valid_2b[i] <= 0;
            end
        end else begin
            overflow_s2b[0] <= overflow_s1;
            neg_shift_s2b[0] <= neg_shift_s1;
            valid_2b[0] <= valid_stage1;
            for(i = 0; i<DEPTH-1; i = i+1) begin
                overflow_s2b[i+1] <= overflow_s2b[i];
                neg_shift_s2b[i+1] <= neg_shift_s2b[i];
                valid_2b[i+1] <= valid_2b[i];
            end
        end
    end
    wire DW_mul_en;
    wire any_valid_2b;
    // 先把 unpacked copy 到一個 packed wire
    wire [DEPTH-1:0] valid_2b_vec;
    genvar j;
    generate
    for (j=0; j<DEPTH; j=j+1) begin
        assign valid_2b_vec[j] = valid_2b[j];
    end
    endgenerate
    assign any_valid_2b = |valid_2b_vec;
    assign DW_mul_en = valid_stage1 | any_valid_2b;
    // assign DW_mul_en = 1'b1;
    DW_mult_pipe_64_32 #(
        .DEPTH(DEPTH)
    )DW_mult_pipe_inst_64_32(
        .inst_clk(clk),
        .inst_rst_n(rst),
        .inst_en(DW_mul_en),
        .inst_tc(1'b1),
        .inst_a(ab_64_s1),
        .inst_b(quantized_multiplier_reg_s1),
        .product_inst(ab_64_s2)
    );
    always @(posedge clk) begin
        if (!rst) overflow_s2 <= 0;
        else overflow_s2 <= overflow_s1;
    end

    // Propagate neg_shift
    reg signed [`INT32_SIZE-1:0] neg_shift_s2;
    always @(posedge clk) begin
        if (!rst) neg_shift_s2 <= 0;
        else neg_shift_s2 <= neg_shift_s1;
    end

    // Stage 3: Nudge 計算與提取高32位
    always @(posedge clk) begin
        if (!rst) valid_stage3 <= 0;
        // else valid_stage3 <= valid_stage2;
        else valid_stage3 <= valid_2b[DEPTH-2];
    end

    always @(posedge clk) begin
        if (!rst) nudge_s3 <= 0;
        // else if (valid_stage2) nudge_s3 <= (ab_64_s2 >= 0) ? (1 << 30) : (1 - (1 << 30));
        else nudge_s3 <= (ab_64_s2 >= 0) ? (1 << 30) : (1 - (1 << 30));
    end

    always @(posedge clk) begin
        if (!rst) ab_64_s3 <= 0;
        // else if(valid_stage2) ab_64_s3 <= ab_64_s2;
        else ab_64_s3 <= ab_64_s2;
    end

    always @(posedge clk) begin
        if (!rst) overflow_s3 <= 0;
        // else if (valid_stage2) overflow_s3 <= overflow_s2;
        else overflow_s3 <= overflow_s2b[DEPTH-2];
    end

    // 這裡將 neg_shift 往後傳遞
    reg signed [`INT32_SIZE-1:0] neg_shift_s3;
    always @(posedge clk) begin
        if (!rst) neg_shift_s3 <= 0;
        // else if (valid_stage2) neg_shift_s3 <= neg_shift_s2;
        else neg_shift_s3 <= neg_shift_s2b[DEPTH-2];
    end
 
    // Stage 4: RoundingDivideByPOT 的前段計算：計算 remainder 與 threshold
    // 取高32位並四捨五入 (模擬 SaturatingRoundingDoublingHighMul + RoundingDivideByPOT)
    wire signed [`INT32_SIZE-1:0] ab_x3_high32;
    assign ab_x3_high32 = overflow_s3 ? INT32_MAX :
                      ((ab_64_s3 + nudge_s3) >>> (`INT32_SIZE-1));

    always @(posedge clk) begin
        if (!rst) valid_stage4 <= 0;
        else valid_stage4 <= valid_stage3;
    end

    always @(posedge clk) begin
        if (!rst) remainder_s4 <= 0;
        else remainder_s4 <= ab_x3_high32 & ((1 << neg_shift_s3) - 1);
    end

    always @(posedge clk) begin
        if (!rst) threshold_s4 <= 0;
        else threshold_s4 <= (((1 << neg_shift_s3) - 1) >> 1) + ((ab_x3_high32 < 0) ? 1 : 0);
    end

    always @(posedge clk) begin
        if (!rst) ab_x2_high32_s4 <= 0;
        else ab_x2_high32_s4 <= ab_x3_high32;
    end

    // Stage 5: Final calculation using RoundingDivideByPOT
    // 這裡直接將 ab_x2_high32_s4 以 neg_shift_s3 作為位移參數做 RoundingDivideByPOT
    // 如果 neg_shift_s3 為正，表示右移；若為負，則表示左移
    reg [1:0] right_shift_overflow_s4;
    // 這邊繼承前版檢查溢出邏輯，可依需要修改，此處直接沿用概念
    //（本範例僅示意，實際使用中可根據具體需求進行調整）
    always @(posedge clk) begin
        if(!rst) right_shift_overflow_s4 <= 0;
        else if(valid_stage3) begin
            // 這裡可以加入檢查溢出的邏輯，範例直接設定為 0
            right_shift_overflow_s4 <= 0;
        end
    end
    
    reg signed [`INT32_SIZE-1:0] tmp_result_s5;
    reg signed [`INT32_SIZE-1:0] remainder_s5;
    reg signed [`INT32_SIZE-1:0] threshold_s5;
    reg valid_stage5;

    always @(posedge clk) begin
        if (!rst) begin
            tmp_result_s5 <= 0;
            remainder_s5  <= 0;
            threshold_s5  <= 0;
            valid_stage5  <= 0;
        end else begin
            tmp_result_s5 <= (ab_x2_high32_s4 >>> neg_shift_s3);
            remainder_s5  <= remainder_s4;
            threshold_s5  <= threshold_s4;
            valid_stage5  <= valid_stage4;
        end
    end

    always @(posedge clk) begin
        if (!rst) output_valid <= 0;
        else output_valid <= valid_stage5;
    end

    always @(posedge clk) begin
        if (!rst) begin
            x_mul_by_quantized_multiplier <= 0;
        end else begin
            if (remainder_s5 > threshold_s5)
                x_mul_by_quantized_multiplier <= tmp_result_s5 + 1;
            else
                x_mul_by_quantized_multiplier <= tmp_result_s5;
        end
    end
endmodule


module DW_mult_pipe_64_32 #(
    parameter integer DEPTH = 6
)
(inst_clk, inst_rst_n, inst_en, inst_tc, inst_a,
                         inst_b, product_inst );
  parameter inst_a_width = 64;
  parameter inst_b_width = 32;
  parameter inst_num_stages = DEPTH;
  parameter inst_stall_mode = 1;
  parameter inst_rst_mode = 2;
  parameter inst_op_iso_mode = 0;

  input wire signed [inst_a_width-1 : 0] inst_a;
  input wire signed [inst_b_width-1 : 0] inst_b;
  input wire inst_tc;
  input wire inst_clk;
  input wire inst_en;
  input wire inst_rst_n;
  output wire signed [inst_a_width+inst_b_width-1 : 0] product_inst;

  // Instance of DW_mult_pipe, replaced with custom ip
//   DW_mult_pipe #(
//     inst_a_width, 
//     inst_b_width, 
//     inst_num_stages,
//     inst_stall_mode, 
//     inst_rst_mode, 
//     inst_op_iso_mode
//     ) U1 (
//     .clk(inst_clk),   
//     .rst_n(inst_rst_n),   
//     .en(inst_en),
//     .tc(inst_tc),   
//     .a(inst_a),   
//     .b(inst_b), 
//     .product(product_inst) 
//     );

    mult_pipe #(
          .A_WIDTH (inst_a_width),
          .B_WIDTH (inst_b_width),
          .DEPTH   (inst_num_stages) //is this correct number because in tb we changed from 6 -> 7
      ) U_mult_pipe (
          .clk     (inst_clk),
          .rst_n   (inst_rst_n),
          .en      (inst_en),
          .tc      (inst_tc),
          .a       (inst_a),
          .b       (inst_b),
          .product (product_inst)
      );

endmodule

