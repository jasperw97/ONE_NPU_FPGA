`timescale 1ns/1ps
`default_nettype wire

module op_decoder (
    input  logic [63:0] inst_i,
    output logic [15:0] op_o,
    output logic [14:0] reserved_o,
    output logic [7:0]  b_cast_o,
    output logic [24:0] dsc_idx_o
);

    assign op_o       = inst_i[63:48];
    assign reserved_o = inst_i[47:33];
    assign b_cast_o   = inst_i[32:25];
    assign dsc_idx_o  = inst_i[24:0];

endmodule

`default_nettype wire
