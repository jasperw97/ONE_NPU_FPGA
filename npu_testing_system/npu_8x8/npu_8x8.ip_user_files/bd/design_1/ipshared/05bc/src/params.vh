`ifndef PARAMS_VH
`define PARAMS_VH

`define LANES           64
`define INT8_SIZE       8
`define INT16_SIZE      16
`define INT32_SIZE      32
`define INT64_SIZE      64
`define SRAM_ADDR_WIDTH  12
`define DRAM_ADDR_WIDTH  23
`define MATRIX_ADDR_WIDTH 22
`define SRAM_WIDTH_O    `LANES*`INT16_SIZE
`define MUL_DEPTH       2

`define OP_IDLE         4'b0000
`define OP_CONV         4'b0001
`define OP_FC           4'b0010
`define OP_EXP          4'b0011
`define OP_RCP          4'b0100
`define OP_ADD          4'b0101
`define OP_SUB          4'b0110
`define OP_MUL          4'b0111


`endif