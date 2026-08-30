`timescale 1ns/1ps
`default_nettype wire

`include "params.vh"

module desc_decoder (
    input  logic [`DESC_PACKET_BITS-1:0] desc_i,

    output logic [31:0] header_o,
    output logic [15:0] reserved_o,
    output logic [7:0]  version_o,
    output logic [3:0]  op_slot_o,
    output logic [3:0]  op_code_o,

    output logic [31:0] m_o,
    output logic [31:0] n_o,
    output logic [31:0] k_o,
    output logic [31:0] data_count_o,
    output logic [31:0] src1_count_o,
    output logic [31:0] total_words_o,
    output logic [31:0] broadcast_count_o,
    output logic [2:0]  src0_bank_o,
    output logic [`SRAM_ADDR_WIDTH-1:0] src0_word_base_o,
    output logic [2:0]  src1_bank_o,
    output logic [`SRAM_ADDR_WIDTH-1:0] src1_word_base_o,
    output logic [2:0]  dst_bank_o,
    output logic [`SRAM_ADDR_WIDTH-1:0] dst_word_base_o,

    output logic [31:0] conv_stride_h_o,
    output logic [31:0] conv_stride_w_o,
    output logic [31:0] conv_padding_o,
    output logic [31:0] conv_batch_o,
    output logic [31:0] conv_img_row_o,
    output logic [31:0] conv_img_col_o,
    output logic [31:0] conv_in_channel_o,
    output logic [31:0] conv_out_channel_o,
    output logic [31:0] conv_ker_row_o,
    output logic [31:0] conv_ker_col_o,
    output logic [31:0] conv_requant_multiplier_o,
    output logic [31:0] conv_requant_shift_o,
    output logic [31:0] conv_requant_output_offset_o,
    output logic [31:0] conv_activation_min_o,
    output logic [31:0] conv_activation_max_o,
    output logic [31:0] conv_input_requant_multiplier_o,
    output logic [31:0] conv_input_requant_shift_o,
    output logic [31:0] conv_input_requant_offset_o,
    output logic [31:0] conv_input_activation_min_o,
    output logic [31:0] conv_input_activation_max_o,
    output logic [31:0] conv_weight_requant_multiplier_o,
    output logic [31:0] conv_weight_requant_shift_o,
    output logic [31:0] conv_weight_requant_offset_o,
    output logic [31:0] conv_weight_activation_min_o,
    output logic [31:0] conv_weight_activation_max_o,

    output logic [31:0] exp_deq_input_range_radius_o,
    output logic [31:0] exp_deq_input_zero_point_o,
    output logic [31:0] exp_deq_input_multiplier_o,
    output logic [31:0] exp_deq_input_left_shift_o,
    output logic [31:0] exp_req_input_quantized_multiplier_o,
    output logic [31:0] exp_req_input_shift_o,
    output logic [31:0] exp_req_input_offset_o,

    output logic [31:0] rcp_deq_input_range_radius_o,
    output logic [31:0] rcp_deq_input_zero_point_o,
    output logic [31:0] rcp_deq_input_multiplier_o,
    output logic [31:0] rcp_deq_input_left_shift_o,
    output logic [31:0] rcp_req_input_quantized_multiplier_o,
    output logic [31:0] rcp_req_input_shift_o,
    output logic [31:0] rcp_req_input_offset_o,

    output logic [31:0] add_input1_offset_o,
    output logic [31:0] add_input2_offset_o,
    output logic [31:0] add_left_shift_o,
    output logic [31:0] add_input1_multiplier_o,
    output logic [31:0] add_input2_multiplier_o,
    output logic [31:0] add_input1_shift_o,
    output logic [31:0] add_input2_shift_o,
    output logic [31:0] add_output_multiplier_o,
    output logic [31:0] add_output_shift_o,
    output logic [31:0] add_output_offset_o,
    output logic [31:0] add_activation_min_o,
    output logic [31:0] add_activation_max_o,

    output logic [31:0] sub_input1_offset_o,
    output logic [31:0] sub_input2_offset_o,
    output logic [31:0] sub_left_shift_o,
    output logic [31:0] sub_input1_multiplier_o,
    output logic [31:0] sub_input2_multiplier_o,
    output logic [31:0] sub_input1_shift_o,
    output logic [31:0] sub_input2_shift_o,
    output logic [31:0] sub_output_multiplier_o,
    output logic [31:0] sub_output_shift_o,
    output logic [31:0] sub_output_offset_o,
    output logic [31:0] sub_activation_min_o,
    output logic [31:0] sub_activation_max_o,

    output logic [31:0] mul_input1_offset_o,
    output logic [31:0] mul_input2_offset_o,
    output logic [31:0] mul_output_multiplier_o,
    output logic [31:0] mul_output_shift_o,
    output logic [31:0] mul_output_offset_o,
    output logic [31:0] mul_activation_min_o,
    output logic [31:0] mul_activation_max_o,
    output logic [31:0] mul_in1_requant_multiplier_o,
    output logic [31:0] mul_in1_requant_shift_o,
    output logic [31:0] mul_in1_requant_offset_o,
    output logic [31:0] mul_in1_activation_min_o,
    output logic [31:0] mul_in1_activation_max_o,
    output logic [31:0] mul_in2_requant_multiplier_o,
    output logic [31:0] mul_in2_requant_shift_o,
    output logic [31:0] mul_in2_requant_offset_o,
    output logic [31:0] mul_in2_activation_min_o,
    output logic [31:0] mul_in2_activation_max_o
);

    localparam int DESC_SLOT_BITS = `DESC_SLOT_BITS;
    localparam int DESC_LOC_BITS = 3 + `SRAM_ADDR_WIDTH;

    logic [16+DESC_SLOT_BITS-1:0] operand_location_pack;

    function automatic logic [31:0] sign_extend_i16(input logic [15:0] value);
        begin
            sign_extend_i16 = {{16{value[15]}}, value};
        end
    endfunction

    assign header_o          = desc_i[0*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign reserved_o        = header_o[31:16];
    assign version_o         = header_o[15:8];
    assign op_slot_o         = header_o[7:4];
    assign op_code_o         = header_o[3:0];

    assign m_o               = desc_i[1*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign n_o               = desc_i[2*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign k_o               = desc_i[3*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign data_count_o      = desc_i[4*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign src1_count_o      = desc_i[5*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign total_words_o     = desc_i[6*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign broadcast_count_o = desc_i[7*DESC_SLOT_BITS +: DESC_SLOT_BITS];

    assign operand_location_pack = {header_o[31:16], desc_i[31*DESC_SLOT_BITS +: DESC_SLOT_BITS]};
    assign src0_bank_o      = operand_location_pack[0*DESC_LOC_BITS +: 3];
    assign src0_word_base_o = operand_location_pack[0*DESC_LOC_BITS + 3 +: `SRAM_ADDR_WIDTH];
    assign src1_bank_o      = operand_location_pack[1*DESC_LOC_BITS +: 3];
    assign src1_word_base_o = operand_location_pack[1*DESC_LOC_BITS + 3 +: `SRAM_ADDR_WIDTH];
    assign dst_bank_o       = operand_location_pack[2*DESC_LOC_BITS +: 3];
    assign dst_word_base_o  = operand_location_pack[2*DESC_LOC_BITS + 3 +: `SRAM_ADDR_WIDTH];

    // CONV descriptor-specific aliases.
    assign conv_stride_h_o = desc_i[8*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign conv_stride_w_o = desc_i[9*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign conv_padding_o = desc_i[10*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign conv_batch_o = desc_i[11*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign conv_img_row_o = desc_i[12*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign conv_img_col_o = desc_i[13*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign conv_in_channel_o = desc_i[14*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign conv_out_channel_o = desc_i[15*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign conv_ker_row_o = desc_i[16*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign conv_ker_col_o = desc_i[17*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign conv_requant_multiplier_o = desc_i[18*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign conv_requant_shift_o = desc_i[19*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign conv_requant_output_offset_o = desc_i[20*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign conv_activation_min_o = desc_i[21*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign conv_activation_max_o = desc_i[22*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign conv_input_requant_multiplier_o = desc_i[23*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign conv_input_requant_shift_o = desc_i[24*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign conv_input_requant_offset_o = desc_i[25*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign conv_input_activation_min_o = sign_extend_i16(desc_i[26*DESC_SLOT_BITS +: 16]);
    assign conv_input_activation_max_o = sign_extend_i16(desc_i[26*DESC_SLOT_BITS + 16 +: 16]);
    assign conv_weight_requant_multiplier_o = desc_i[27*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign conv_weight_requant_shift_o = desc_i[28*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign conv_weight_requant_offset_o = desc_i[29*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign conv_weight_activation_min_o = sign_extend_i16(desc_i[30*DESC_SLOT_BITS +: 16]);
    assign conv_weight_activation_max_o = sign_extend_i16(desc_i[30*DESC_SLOT_BITS + 16 +: 16]);

    // EXP descriptor-specific aliases.
    assign exp_deq_input_range_radius_o = desc_i[8*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign exp_deq_input_zero_point_o = desc_i[9*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign exp_deq_input_multiplier_o = desc_i[10*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign exp_deq_input_left_shift_o = desc_i[11*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign exp_req_input_quantized_multiplier_o = desc_i[12*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign exp_req_input_shift_o = desc_i[13*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign exp_req_input_offset_o = desc_i[14*DESC_SLOT_BITS +: DESC_SLOT_BITS];

    // RCP descriptor-specific aliases.
    assign rcp_deq_input_range_radius_o = desc_i[8*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign rcp_deq_input_zero_point_o = desc_i[9*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign rcp_deq_input_multiplier_o = desc_i[10*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign rcp_deq_input_left_shift_o = desc_i[11*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign rcp_req_input_quantized_multiplier_o = desc_i[12*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign rcp_req_input_shift_o = desc_i[13*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign rcp_req_input_offset_o = desc_i[14*DESC_SLOT_BITS +: DESC_SLOT_BITS];

    // ADD descriptor-specific aliases.
    assign add_input1_offset_o = desc_i[8*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign add_input2_offset_o = desc_i[9*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign add_left_shift_o = desc_i[10*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign add_input1_multiplier_o = desc_i[11*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign add_input2_multiplier_o = desc_i[12*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign add_input1_shift_o = desc_i[13*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign add_input2_shift_o = desc_i[14*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign add_output_multiplier_o = desc_i[15*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign add_output_shift_o = desc_i[16*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign add_output_offset_o = desc_i[17*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign add_activation_min_o = desc_i[18*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign add_activation_max_o = desc_i[19*DESC_SLOT_BITS +: DESC_SLOT_BITS];

    // SUB descriptor-specific aliases.
    assign sub_input1_offset_o = desc_i[8*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign sub_input2_offset_o = desc_i[9*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign sub_left_shift_o = desc_i[10*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign sub_input1_multiplier_o = desc_i[11*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign sub_input2_multiplier_o = desc_i[12*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign sub_input1_shift_o = desc_i[13*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign sub_input2_shift_o = desc_i[14*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign sub_output_multiplier_o = desc_i[15*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign sub_output_shift_o = desc_i[16*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign sub_output_offset_o = desc_i[17*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign sub_activation_min_o = desc_i[18*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign sub_activation_max_o = desc_i[19*DESC_SLOT_BITS +: DESC_SLOT_BITS];

    // MUL descriptor-specific aliases.
    assign mul_input1_offset_o = desc_i[8*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign mul_input2_offset_o = desc_i[9*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign mul_output_multiplier_o = desc_i[10*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign mul_output_shift_o = desc_i[11*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign mul_output_offset_o = desc_i[12*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign mul_activation_min_o = desc_i[13*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign mul_activation_max_o = desc_i[14*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign mul_in1_requant_multiplier_o = desc_i[15*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign mul_in1_requant_shift_o = desc_i[16*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign mul_in1_requant_offset_o = desc_i[17*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign mul_in1_activation_min_o = desc_i[18*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign mul_in1_activation_max_o = desc_i[19*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign mul_in2_requant_multiplier_o = desc_i[20*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign mul_in2_requant_shift_o = desc_i[21*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign mul_in2_requant_offset_o = desc_i[22*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign mul_in2_activation_min_o = desc_i[23*DESC_SLOT_BITS +: DESC_SLOT_BITS];
    assign mul_in2_activation_max_o = desc_i[24*DESC_SLOT_BITS +: DESC_SLOT_BITS];

endmodule

`default_nettype wire
