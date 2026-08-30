//This is not fully parameterizable because some stuff like the width of index 
//is still hardcoded for our scenario (513 LUT entries)
`include "params.vh"

module lut_lane_mem #(
    parameter OUT_WIDTH = 16,
    parameter NUM_WORDS = 9,
    parameter NUM_BANKS = `LANES,
    parameter BANK_SEL_W  = $clog2(NUM_BANKS),
    parameter BANK_ADDR_W = $clog2(NUM_WORDS)
)(
    input  wire                 clk,

    // Write Port for loading
    input  wire                 we,
    input  wire [BANK_ADDR_W-1:0]           write_addr,
    input  wire [`SRAM_WIDTH_O-1:0]          write_data,

    // Read Port A for stage 2 base value
    input  wire [BANK_ADDR_W+BANK_SEL_W-1:0]           read_idx_base,
    output reg  [OUT_WIDTH-1:0] read_data_base,

    // Read Port B for stage 2 next value
    input  wire [BANK_ADDR_W+BANK_SEL_W-1:0]           read_idx_next,
    output reg  [OUT_WIDTH-1:0] read_data_next
);

   
    reg [OUT_WIDTH-1:0] ram_banks [0:NUM_BANKS-1][0:NUM_WORDS-1];

    // 64 banks, each bank 9 words deep, lower 6 bits [5:0] selects the bank, upper 4 bits [9:6] selects address within that bank



    //Port A Address
    wire [BANK_ADDR_W-1:0] addr_a_base = we ? write_addr : read_idx_base[BANK_ADDR_W+BANK_SEL_W-1:BANK_SEL_W];

    //Port B Address
    wire [BANK_ADDR_W-1:0] addr_b_next = read_idx_next[BANK_ADDR_W+BANK_SEL_W-1:BANK_SEL_W];

    reg [BANK_SEL_W-1:0] base_bank_sel;
    reg [BANK_SEL_W-1:0] next_bank_sel;
    // wire [BANK_SEL_W-1:0] base_bank_sel = read_idx_base[BANK_SEL_W-1:0];
    // wire [BANK_SEL_W-1:0] next_bank_sel = read_idx_next[BANK_SEL_W-1:0];
    reg [OUT_WIDTH-1:0] bank_outputs_a [0:NUM_BANKS-1];
    reg [OUT_WIDTH-1:0] bank_outputs_b [0:NUM_BANKS-1];
    // wire [OUT_WIDTH-1:0] bank_reads_a [0:NUM_BANKS-1];
    // wire [OUT_WIDTH-1:0] bank_reads_b [0:NUM_BANKS-1];

    genvar b;
    generate
        for (b = 0; b < NUM_BANKS; b = b + 1) begin : GEN_BANKS
            //Port A
            always_ff @(posedge clk) begin
                if (we) begin
                    ram_banks[b][addr_a_base] <= write_data[b*OUT_WIDTH +: OUT_WIDTH];
                end
                bank_outputs_a[b] <= ram_banks[b][addr_a_base];
                bank_outputs_b[b] <= ram_banks[b][addr_b_next];
            end
            // assign bank_reads_a[b] = ram_banks[b][addr_a_base];
            // assign bank_reads_b[b] = ram_banks[b][addr_b_next];
            // //Port B
            // always_ff @(posedge clk) begin 
            //     bank_outputs_b[b] <= ram_banks[b][addr_b_next];
            // end

        end
    endgenerate

    // wire [OUT_WIDTH-1:0] comb_base_val = bank_reads_a[base_bank_sel];
    // wire [OUT_WIDTH-1:0] comb_next_val = bank_reads_b[next_bank_sel];

    always_ff @(posedge clk) begin
        base_bank_sel <= read_idx_base[BANK_SEL_W-1:0];
        next_bank_sel <= read_idx_next[BANK_SEL_W-1:0];
    end
    

    always @(posedge clk) begin
        // read_data_base <= comb_base_val;
        // read_data_next <= comb_next_val;

        read_data_base <= bank_outputs_a[base_bank_sel];
        read_data_next <= bank_outputs_b[next_bank_sel];
    end

    // always_comb begin
    //     read_data_base = bank_outputs_a[base_bank_sel];
    //     read_data_next = bank_outputs_b[next_bank_sel];
    // end




endmodule