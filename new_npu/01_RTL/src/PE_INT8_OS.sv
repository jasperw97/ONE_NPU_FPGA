module PE_INT8_OS #(
    parameter int IN_BITS  = 8,
    parameter int W_BITS   = 8,
    parameter int OUT_BITS = 32
) (
    input  logic                           clk,
    input  logic                           rst_n,
    input  logic signed [IN_BITS-1:0]      input_data_in,
    output logic signed [IN_BITS-1:0]      input_data_out,
    input  logic signed [W_BITS-1:0]       weight_data_in,
    output logic signed [W_BITS-1:0]       weight_data_out,
    output logic signed [OUT_BITS-1:0]     output_data,
    input  logic                           clean
);

    logic signed [OUT_BITS-1:0] psum;
    logic signed [15:0]         mult16_reg;
    logic signed [IN_BITS-1:0]  input_data_in_r;
    logic signed [W_BITS-1:0]   weight_data_in_r;

    // pass-through registers
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) input_data_in_r   <= '0;
        else        input_data_in_r <= input_data_in;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) weight_data_in_r   <= '0;
        else        weight_data_in_r <= weight_data_in;
    end

    // Stage 1: multiply
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mult16_reg <= '0;
        end else if (clean) begin
            mult16_reg <= '0;
        end else begin
            mult16_reg <= input_data_in_r * weight_data_in_r;
        end
    end

    // Stage 2: accumulate
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            psum <= '0;
        end else if (clean) begin
            psum <= '0;
        end else begin
            psum <= psum + {{(OUT_BITS-16){mult16_reg[15]}}, mult16_reg};
        end
    end

    assign output_data = psum;
    assign input_data_out = input_data_in_r;
    assign weight_data_out = weight_data_in_r;

endmodule