(* shreg_exact = "no" *)
module mult_pipe #(
    parameter A_WIDTH = 64,
    parameter B_WIDTH = 32,
    parameter DEPTH = 7
) (
    input logic clk, rst_n, tc,
    (* max_fanout = 32 *) input logic en,
    input logic [A_WIDTH-1: 0] a,
    input logic [B_WIDTH-1: 0] b,
    output logic [A_WIDTH + B_WIDTH - 1: 0] product
);

    logic signed [A_WIDTH+B_WIDTH-1:0] signed_mult_result;
    logic [A_WIDTH+B_WIDTH-1:0] unsigned_mult_result;
    
    
    logic [A_WIDTH+B_WIDTH-1:0] pipe [0:DEPTH-2];

    assign signed_mult_result = $signed(a) * $signed(b);
    assign unsigned_mult_result = $unsigned(a) * $unsigned(b);

    logic [A_WIDTH+B_WIDTH-1:0] mult_result;

    always_comb begin : multiplication
        mult_result = tc ? signed_mult_result : unsigned_mult_result;
    end

    always_ff @(posedge clk) begin : pipeline_updates
        // if (!rst_n) begin
        //     for (int i = 0; i < DEPTH - 1; i++) begin
        //         pipe[i] <= 0;
        //     end
        // end else 
        if (en) begin
            pipe[0] <= mult_result;

            for (int i = 1; i < DEPTH - 1; i++) begin
                pipe[i] <= pipe[i-1];
            end
        end
    end

    assign product = pipe[DEPTH-2];
    
endmodule
