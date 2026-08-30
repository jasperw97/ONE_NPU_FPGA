`default_nettype wire

module fifo #(
    parameter int DATA_WIDTH = 32,
    parameter int DEPTH      = 32,
    parameter int AW         = $clog2(DEPTH)
) (
    input  logic                  clk,
    input  logic                  rst_n,

    input  logic                  push,
    input  logic [DATA_WIDTH-1:0] push_data,

    input  logic                  pop,
    output logic [DATA_WIDTH-1:0] pop_data,

    output logic                  full,
    output logic                  empty,
    output logic [AW:0]           count
);

    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    logic [AW-1:0] wr_ptr, rd_ptr;

    assign empty    = (count == 0);
    assign full     = (count == DEPTH);
    assign pop_data = mem[rd_ptr];

    integer i;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= '0;
            rd_ptr <= '0;
            count  <= '0;
            for (i = 0; i < DEPTH; i = i + 1) begin
                mem[i] <= '0;
            end
        end else begin
            case ({push && !full, pop && !empty})
                2'b10: begin
                    mem[wr_ptr] <= push_data;
                    wr_ptr <= wr_ptr + 1'b1;
                    count  <= count + 1'b1;
                end
                2'b01: begin
                    rd_ptr <= rd_ptr + 1'b1;
                    count  <= count - 1'b1;
                end
                2'b11: begin
                    mem[wr_ptr] <= push_data;
                    wr_ptr <= wr_ptr + 1'b1;
                    rd_ptr <= rd_ptr + 1'b1;
                    // count unchanged
                end
                default: begin
                    // do nothing
                end
            endcase
        end
    end

endmodule

`default_nettype wire